extends SceneTree
## v534: keep 68deg/s chassis yaw and no normal gait during rise,
## but replant both diagonal pairs after the full DOWN hold and BEFORE
## BODY moves upward. Check live authored Wait footprint targets.
const AI = preload("res://scripts/bittaran_ai.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ONE_LEG: Array[String] = ["leg_fl"]
const STEP_TIME: float = 0.52
const TURN_SPEED: float = deg_to_rad(AI.STATIONARY_TURN_DEG_PER_SEC)

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V367_BITTARAN_FOOT_CATCHUP_FAIL: " + message)
    quit(1)

func _run_case(battle: Node3D, ids: Array[String],
        requested: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    boss.rotation.y = 0.0
    # Approach must still have nonzero yaw error: in v366 it would use
    # 44deg/s, but the chassis now aims at 68deg/s while rising.
    player.global_position = boss.global_position + (
        Vector3(27.0, 0, 0) if requested == "Turn"
        else Vector3(15.0, 0, 26.0))
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != requested:
        _fail("wrong initial motion: " + requested)
        return false
    for id in ids:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 800.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("leg failed to break: " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var rise_frames: int = 0
    var hold_frames: int = 0
    var upright_first_pair: int = -1
    var second_pair_seen: bool = false
    var live_target_updates: int = 0
    var last_swing_targets: Dictionary = {}
    var upright_frame: int = -1
    var had_fallen: bool = false
    for frame in range(1100):
        var before_break: bool = bool(ik.call("down_pose_active"))
        var rising_this_tick: bool = bool(ik.call("standup_turn_enabled", DT))
        var previous_yaw: float = boss.rotation.y
        var before_position: Vector3 = boss.position
        # Avoid closing the original aim error during the rise and then
        # incorrectly diagnosing a final tiny saturation step as 22deg/s.
        player.global_position = (boss.global_position
            + (boss.global_basis.x.normalized() * 27.0
                if requested == "Turn" else
                (boss.global_basis.z.normalized() * 26.0
                 + boss.global_basis.x.normalized() * 15.0)))
        battle.call("_advance_target_motion", DT)
        var chosen: String = str(battle.get("bittaran_motion"))
        var yaw_step: float = absf(wrapf(
            boss.rotation.y - previous_yaw, -PI, PI))
        if before_break and rising_this_tick:
            if chosen != requested or str(rig.get("current_clip")) != requested:
                _fail("rise clip not playing " + requested)
                return false
            if yaw_step > TURN_SPEED * DT + 0.00006:
                _fail("chassis exceeded normal turning rate")
                return false
            if requested == "Approach" and yaw_step > 0.00003:
                # At nonzero target yaw error, Approach must turn exactly at
                # 68 deg/s (not the normal moving 44 deg/s).
                if absf(yaw_step - TURN_SPEED * DT) > 0.00008:
                    _fail("Approach rise used foot/moving-turn speed")
                    return false
            rise_frames += 1
        elif before_break and not rising_this_tick:
            hold_frames += 1
            if chosen != "Idle" or yaw_step > 0.000003:
                _fail("chassis turned before rising")
                return false
        battle.call("_finalize_target_pose", DT)
        var still_down: bool = bool(ik.call("down_pose_active"))
        var pair: int = int(ik.get("source_ik_step_pair"))
        var all_legs: Array = ik.get("legs")
        var down_step_pair: int = int(
            ik.get("authored_down_replant_pair"))
        if still_down:
            had_fallen = true
            if pair != -1:
                _fail("normal gait stepped during authored down")
                return false
            # The new approved sequence replants BOTH diagonal pairs
            # after the full hold, while BODY remains at t=1.75.
            if down_step_pair >= 0:
                if float(ik.call("standup_pose_fraction")) > 0.000001:
                    _fail("foot replant started after BODY lift")
                    return false
                if upright_first_pair < 0:
                    upright_first_pair = down_step_pair
                elif upright_first_pair != down_step_pair:
                    second_pair_seen = true
                for leg in all_legs:
                    var foot: Dictionary = leg
                    if not bool(foot["stepping"]):
                        continue
                    if float(foot["swing_elapsed"]) > (
                            IK.DOWN_REPLANT_SECONDS * 0.5
                            + DT + 0.00001):
                        _fail("down foot replant exceeded original step clock")
                        return false
                    var expected: Vector3 = ik.call(
                        "_source_ik_home", foot)
                    var actual: Vector3 = foot["swing_to"]
                    if actual.distance_to(expected) > 0.00005:
                        _fail("replant target not at live Wait footprint")
                        return false
                    live_target_updates += 1
            elif float(ik.call("standup_pose_fraction")) > 0.001:
                if not second_pair_seen:
                    _fail("BODY rose before both foot pairs moved")
                    return false
                for leg in all_legs:
                    if bool((leg as Dictionary)["stepping"]):
                        _fail("foot lifted while raising the chassis")
                        return false
        elif had_fallen and upright_frame < 0:
            upright_frame = frame
            if upright_first_pair < 0 or not second_pair_seen:
                _fail("recovery ended without both grounded replant steps")
                return false
        if upright_frame >= 0 and frame > upright_frame + 115:
            break
    if rise_frames < 12 or hold_frames < 80 or upright_frame < 0 \
            or upright_first_pair < 0 or not second_pair_seen \
            or live_target_updates < 5:
        _fail("insufficient body-turn/foot-landing coverage: "
            + str([requested, ids.size(), rise_frames, hold_frames,
                upright_frame, upright_first_pair, second_pair_seen,
                live_target_updates]))
        return false
    print("V367_BODY_FOOT_CASE_PASS: " + requested + " legs="
        + str(ids.size()) + " rising=" + str(rise_frames)
        + " frames, first upright frame=" + str(upright_frame)
        + ", verified replant contacts=" + str(live_target_updates)
        + ", both diagonal pairs stepped BEFORE BODY lift")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    for broken in [ONE_LEG, LEG_IDS]:
        for motion in ["Turn", "Approach"]:
            if not _run_case(battle, broken, motion):
                return
    print("GODOT_V367_BITTARAN_FOOT_CATCHUP_PASS: chassis turns at "
        + "68deg/s while rising, both diagonal pairs replant before torso "
        + "lift with grounded, authored Wait targets")
    quit(0)

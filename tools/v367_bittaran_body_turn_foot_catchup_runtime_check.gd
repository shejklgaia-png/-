extends SceneTree
## v367: while standing up the chassis looks toward SERA at 34deg/s,
## world-locked IK soles do not begin gait. On the first upright frame
## the most displaced diagonal steps, its landing target continuously
## follows the latest body stance without changing STEP_DURATION_SECONDS.
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ONE_LEG: Array[String] = ["leg_fl"]
const STEP_TIME: float = 0.58
const TURN_SPEED: float = deg_to_rad(34.0)

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
    # 22deg/s, but v367 must aim the chassis at 34deg/s while rising.
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
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
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
    for frame in range(550):
        var before_break: bool = bool(ik.call("down_pose_active"))
        var rising_this_tick: bool = bool(ik.call("standup_turn_enabled", DT))
        var previous_yaw: float = boss.rotation.y
        var before_position: Vector3 = boss.position
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
                # 34 deg/s (not the normal moving 22 deg/s).
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
        var pair: int = int(ik.get("stepping_pair"))
        var all_legs: Array = ik.get("legs")
        if still_down:
            had_fallen = true
            if pair != -1:
                _fail("feet lifted during chassis stand-up")
                return false
            for leg in all_legs:
                if bool((leg as Dictionary)["stepping"]):
                    _fail("planted foot began moving before upright")
                    return false
        elif had_fallen and upright_frame < 0:
            upright_frame = frame
            if pair < 0:
                _fail("first upright tick failed to initiate foot catch-up")
                return false
            upright_first_pair = pair
            # The oldest displaced foot pair starts first. Capture its
            # swing duration and never shorten it to solve alignment.
            for leg in all_legs:
                var foot: Dictionary = leg
                if bool(foot["stepping"]):
                    if float(foot["swing_elapsed"]) > DT + 0.00001:
                        _fail("stepping began before the body stood up")
                        return false
        elif upright_frame >= 0:
            if pair >= 0 and pair != upright_first_pair:
                second_pair_seen = true
            for leg in all_legs:
                var foot: Dictionary = leg
                if not bool(foot["stepping"]):
                    continue
                if float(foot["swing_elapsed"]) > STEP_TIME + 0.00001:
                    _fail("gait speed changed while catching up")
                    return false
                var expected: Vector3 = ik.call("_home",
                    foot, chosen == "Approach")
                var actual: Vector3 = foot["swing_to"]
                if actual.distance_to(expected) > 0.00005:
                    _fail("landing target did not follow live body stance: "
                        + str(actual) + " expected " + str(expected))
                    return false
                var foot_name: String = str(foot["upper"].name)
                if last_swing_targets.has(foot_name):
                    var before: Vector3 = last_swing_targets[foot_name]
                    if before.distance_to(actual) > 0.00002:
                        live_target_updates += 1
                last_swing_targets[foot_name] = actual
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
        + ", dynamic landing updates=" + str(live_target_updates)
        + ", both diagonal pairs caught up without speeding step")
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
        + "34deg/s while rising, planted feet follow only after upright "
        + "via live landing positions at original 0.58s step duration")
    quit(0)

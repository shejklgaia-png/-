extends SceneTree
## v362: the boss must finish the IK collapse, complete its visible
## stand-up, and settle in neutral Idle before AI may emit Turn/Approach.
## Exercise BOTH short (2.5s) and four-leg (6s) knockdowns with the
## actual scene, boss AI, rig clips, collision IK, and release timer.
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const SINGLE_LEG_IDS: Array[String] = ["leg_fl"]
const IDLE_SETTLE_SECONDS: float = 0.24

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V362_BITTARAN_STANDUP_FAIL: " + message)
    quit(1)

func _check_case(battle: Node3D, expected_motion: String,
        broken_leg_ids: Array[String]) -> bool:
    # An active AI request must be possible BEFORE breaking the legs,
    # otherwise a forced Idle is a false-positive regression test.
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or ik == null or target == null or player == null:
        _fail("missing active Bittaran AI/rig/IK scene")
        return false
    target.rotation.y = 0.0
    var far_player: Vector3 = (
        Vector3(26.0, 0.0, 0.0) if expected_motion == "Turn"
        else Vector3(0.0, 0.0, 26.0))
    player.global_position = Vector3(
        target.global_position.x + far_player.x,
        0.0, target.global_position.z + far_player.z)
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != expected_motion             or str(rig.get("current_clip")) != expected_motion:
        _fail("pre-down AI cannot start " + expected_motion
            + ", actual=" + str(battle.get("bittaran_motion")))
        return false

    for id in broken_leg_ids:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("unable to initiate down via " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    if not bool(ik.call("break_reaction_active")) or bool(
            ik.call("locomotion_ready")):
        _fail("leg break did not immediately block motion")
        return false

    var down_finished_at: int = -1
    var locomotion_released_at: int = -1
    var post_down_idle_frames: int = 0
    var actual_down_seconds: float = (
        6.0 if broken_leg_ids.size() == 4 else 2.5)
    for frame in range(470):
        var was_ready: bool = bool(ik.call("locomotion_ready"))
        var original_position: Vector3 = target.position
        var original_yaw: float = target.rotation.y
        battle.call("_advance_target_motion", DT)
        var chosen: String = str(battle.get("bittaran_motion"))
        var played: String = str(rig.get("current_clip"))
        if not was_ready:
            if chosen != "Idle" or played != "Idle":
                _fail(expected_motion + " played during recovery: "
                    + chosen + "/" + played + " frame=" + str(frame))
                return false
            if absf(target.rotation.y - original_yaw) > 0.00001                     or Vector2(target.position.x - original_position.x,
                        target.position.z - original_position.z).length() > 0.00001:
                _fail("AI rotated/approached while the boss was down "
                    + "or still standing up: " + str(frame))
                return false
        battle.call("_finalize_target_pose", DT)
        if down_finished_at < 0 and not bool(ik.call(
                "break_reaction_active")):
            down_finished_at = frame
            if bool(ik.call("locomotion_ready")):
                _fail("Turn/Approach unlocked in the first upright frame")
                return false
            if float(ik.get("post_down_idle_remaining")) <= 0.0:
                _fail("no visible Idle settling after physical recovery")
                return false
        if down_finished_at >= 0 and not was_ready:
            post_down_idle_frames += 1
        if bool(ik.call("locomotion_ready")) and locomotion_released_at < 0:
            locomotion_released_at = frame
            if bool(ik.call("down_pose_active")) or bool(ik.call("windup_active")):
                _fail("AI resumed while falling/standing up")
                return false
            if int(ik.get("head_support_leg_index")) >= 0                     or str(ik.get("head_support_leg_id")) != "":
                _fail("AI resumed before supporting limb released")
                return false
            # The visual body must be back at its neutral model height,
            # allowing only the established persistent IK floor correction.
            var visual: Node3D = battle.get("bittaran_rig")
            var expected_height: float = float(
                ik.get("rest_actor_local_y")) + float(
                ik.get("ground_correction_world")) * 0.5
            if absf(visual.position.y - expected_height) > 0.035:
                _fail("AI resumed before the visual chassis was upright")
                return false
        if was_ready and locomotion_released_at >= 0:
            if chosen != expected_motion or played != expected_motion:
                _fail(expected_motion + " never resumed after neutral stand-up "
                    + "actual=" + chosen + "/" + played)
                return false
            if target.rotation.y == original_yaw                     and target.position.distance_to(original_position) < 0.000001:
                _fail("AI root movement did not resume with " + expected_motion)
                return false
            if (down_finished_at < 0 or locomotion_released_at - down_finished_at
                    < int(ceil(IDLE_SETTLE_SECONDS / DT)) - 2):
                _fail("Idle did not hold the complete stand-up/settle phase")
                return false
            if post_down_idle_frames < 12:
                _fail("too few Idle frames after normal standing pose")
                return false
            print("V362_CASE_PASS: " + expected_motion
                + " after " + str(actual_down_seconds)
                + "s down; " + str(post_down_idle_frames)
                + " Idle recovery frames, at " + str(locomotion_released_at))
            return true
    _fail(expected_motion + " locomotion never released after full stand-up")
    return false

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("missing boss scene")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    if not _check_case(battle, "Turn", SINGLE_LEG_IDS):
        return
    if not _check_case(battle, "Approach", LEG_IDS):
        return
    print("GODOT_V362_BITTARAN_STANDUP_PASS: no Turn/Approach clip "
        + "or root motion until all 2.5/6s down poses and "
        + "0.24s upright Idle settle finish")
    quit(0)

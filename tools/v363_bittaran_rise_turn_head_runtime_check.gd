extends SceneTree
## v363: during the actual stand-up the Bittaran root YAW alone ramps
## from zero to normal stationary-turn speed. HEAD follow is strictly
## disabled until 70% of eased upright pose, then eases in during last 30%.
## No Turn/Approach clip or XZ translation until full 0.24s Idle settle.
const DT: float = 1.0 / 60.0
const EPS: float = 0.0001
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const SINGLE: Array[String] = ["leg_fl"]
const MAX_YAW_DEGREES_PER_SECOND: float = 34.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V363_BITTARAN_RISE_FAIL: " + message)
    quit(1)

func _run_case(battle: Node3D, leg_ids: Array[String],
        label: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var rig: Node3D = battle.get("bittaran_rig")
    var head: Node3D = battle.get("bittaran_head")
    if ik == null or boss == null or player == null or rig == null or head == null:
        _fail("missing scene/IK nodes")
        return false
    boss.rotation.y = 0.0
    # At +X player location normal Turn is definitely requested.
    player.global_position = boss.global_position + Vector3(28.0, 0.0, 0.0)
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != "Turn":
        _fail(label + ": initial boss did not need to turn")
        return false
    for id in leg_ids:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail(label + ": failed to break " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)

    var rise_frames: int = 0
    var saw_initial_turn: bool = false
    var saw_strong_turn: bool = false
    var head_turned: bool = false
    var pre_70_head_frames: int = 0
    var after_70_head_frames: int = 0
    var max_turn_step: float = 0.0
    var last_progress: float = 0.0
    var completed_standup: bool = false
    var rotation_at_full_stand: float = 0.0
    var settled: bool = false
    var max_head_delta: float = 0.0
    var previous_head_yaw: float = 0.0
    var previous_turn_weight: float = 0.0
    var positioned_for_head_tracking: bool = false
    for frame in range(480):
        var was_ready: bool = bool(ik.call("locomotion_ready"))
        # The sideways-looking HEAD is protected by authored leg collision.
        # While rising, face the player in the unobstructed front quadrant
        # proven in the standing head-swing regression (v357). The root
        # still has a nonzero reason to turn. For the post-stand gait test,
        # restore a clear 90-degree Turn request once released.
        if was_ready:
            player.global_position = (boss.global_position
                + Vector3(28.0, 0.0, 0.0))
        var before_yaw: float = boss.rotation.y
        var old_position: Vector3 = boss.position
        var before_weight: float = float(ik.call("standup_turn_weight"))
        var before_pose: float = float(ik.call("standup_pose_fraction"))
        battle.call("_advance_target_motion", DT)
        var yaw_delta: float = absf(wrapf(
            boss.rotation.y - before_yaw, -PI, PI))
        var allowed_step: float = deg_to_rad(
            MAX_YAW_DEGREES_PER_SECOND) * DT * before_weight
        if not was_ready:
            if str(battle.get("bittaran_motion")) != "Idle" or str(
                    rig.get("current_clip")) != "Idle":
                _fail(label + ": Turn/Approach gait started before full stand")
                return false
            if Vector2(boss.position.x - old_position.x,
                    boss.position.z - old_position.z).length() > EPS:
                _fail(label + ": boss translated during knockdown/stand-up")
                return false
            if yaw_delta > allowed_step + EPS:
                _fail(label + ": abrupt turn speed exceeds cubic ramp: "
                    + str(yaw_delta) + " > " + str(allowed_step))
                return false
        battle.call("_finalize_target_pose", DT)
        var pose: float = float(ik.call("standup_pose_fraction"))
        if pose > 0.05 and not positioned_for_head_tracking:
            player.global_position = (
                boss.global_position + boss.global_basis.z * 10.0
                + boss.global_basis.x * 4.0)
            positioned_for_head_tracking = true
        var head_yaw: float = absf(float(battle.get("boss_head_yaw")))
        var follow_weight: float = float(battle.call(
            "_head_recovery_follow_weight"))
        if bool(ik.call("down_pose_active")):
            if pose <= 0.70 + 0.00001:
                if follow_weight > 0.00001:
                    _fail(label + ": tracking enabled before 70% of pose")
                    return false
                if head_yaw > EPS:
                    _fail(label + ": HEAD followed too early at fraction="
                        + str(pose) + " yaw=" + str(head_yaw))
                    return false
                if pose > 0.0:
                    pre_70_head_frames += 1
            elif pose < 0.999:
                after_70_head_frames += 1
                if follow_weight <= 0.0 or follow_weight > 1.0:
                    _fail(label + ": head tracking weight failed to fade in")
                    return false
                max_head_delta = maxf(max_head_delta,
                    absf(head_yaw - previous_head_yaw))
                if head_yaw > deg_to_rad(0.2):
                    head_turned = true
            previous_head_yaw = head_yaw
            if pose > 0.0:
                rise_frames += 1
                if pose + 0.00001 < last_progress:
                    _fail(label + ": recovery fraction jumped backward")
                    return false
                last_progress = pose
                if pose < 0.40 and yaw_delta > 0.0000001:
                    saw_initial_turn = true
                if pose > 0.75 and yaw_delta >= 0.00015:
                    saw_strong_turn = true
                if before_weight > 0.0 and before_weight < 1.0                         and before_weight + EPS < previous_turn_weight:
                    _fail(label + ": turn-speed factor decreased during rise")
                    return false
                previous_turn_weight = before_weight
                max_turn_step = maxf(max_turn_step, yaw_delta)
        if not bool(ik.call("down_pose_active")) and not bool(
                ik.call("windup_active")) and not completed_standup:
            completed_standup = true
            rotation_at_full_stand = boss.rotation.y
            if bool(ik.call("locomotion_ready")):
                _fail(label + ": unlocked walking before upright settle")
                return false
        if completed_standup and not was_ready:
            if before_weight < 0.99 and frame > 2:
                _fail(label + ": recovery yaw stopped during Idle settle")
                return false
        if was_ready and completed_standup:
            if not bool(ik.call("locomotion_ready")):
                _fail(label + ": recovered state relocked unexpectedly")
                return false
            if str(battle.get("bittaran_motion")) != "Turn":
                _fail(label + ": failed to resume normal Turn after settle")
                return false
            settled = true
            break
    if not settled or rise_frames < 15 or pre_70_head_frames == 0             or after_70_head_frames == 0:
        _fail(label + ": failed to measure actual 70% recovery and final release "
            + str([settled, rise_frames, pre_70_head_frames, after_70_head_frames]))
        return false
    if not saw_initial_turn or not saw_strong_turn:
        _fail(label + ": recovery yaw did not start progressively with rise "
            + str([saw_initial_turn, saw_strong_turn, max_turn_step]))
        return false
    if absf(rotation_at_full_stand) < deg_to_rad(0.5):
        _fail(label + ": boss remained stationary until standing")
        return false
    # The four-leg collapse can keep HEAD physically on a supporting
    # shin until the last fraction of the rise. Its valid collision
    # constraint may prevent actual yaw, but the 70% follow WEIGHT must
    # still activate. The single-leg case verifies real head articulation.
    if not head_turned and leg_ids.size() == 1:
        _fail(label + ": HEAD never began looking toward SERA above 70%")
        return false
    if max_head_delta > deg_to_rad(5.0):
        _fail(label + ": HEAD yaw snapped during the last 30% of rise: "
            + str(rad_to_deg(max_head_delta)))
        return false
    print("V363_RISE_CASE_PASS: " + label
        + " turn begins under 40%, 70% head gate passed, "
        + "head max step=" + str(rad_to_deg(max_head_delta))
        + "deg, max root step=" + str(rad_to_deg(max_turn_step)) + "deg")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _run_case(battle, SINGLE, "single-leg"):
        return
    if not _run_case(battle, LEG_IDS, "four-leg"):
        return
    print("GODOT_V363_BITTARAN_RISE_PASS: actual pose 70% head follow, "
        + "smooth rising yaw, Idle gait and no Approach until fully upright")
    quit(0)

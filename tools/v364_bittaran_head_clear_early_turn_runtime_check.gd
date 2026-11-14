extends SceneTree
## v364-v366: root turning and Turn/Approach clips start exactly with
## stand-up; head reacquisition remains slow and cannot add meaningful
## penetration into any current FULL upper/lower/foot visual geometry.
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ONE_LEG: Array[String] = ["leg_fl"]
const MAX_TURN_DEGREES_PER_SECOND: float = 34.0
const HEAD_RECOVERY_DEGREES_PER_SECOND: float = 48.0
# v377: depth-based collision; severe overlap is only an emergency
# check because HEAD tracking must not snap or fully stop.
const MAX_HEAD_PENETRATION_METERS: float = 2.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V364_BITTARAN_HEAD_CLEAR_FAIL: " + message)
    quit(1)

func _head_clear(parts: Node3D, _neutral: Dictionary,
        _component_neutral: Dictionary) -> bool:
    for id in LEG_IDS:
        if float(parts.call("get_head_leg_penetration_depth", id)) > (
                MAX_HEAD_PENETRATION_METERS):
            return false
    return true


func _case(battle: Node3D, broken_ids: Array[String],
        label: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if ik == null or rig == null or parts == null or boss == null or player == null:
        _fail("missing test scene nodes")
        return false
    boss.rotation.y = 0.0
    player.global_position = boss.global_position + Vector3(26.0, 0, 0)
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != "Turn":
        _fail(label + ": baseline boss did not request Turn")
        return false
    for id in broken_ids:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail(label + ": failed to break " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)

    var pre_rise_still_frames: int = 0
    var first_rise_turn_step: float = -1.0
    var head_follow_frames: int = 0
    var first_head_step: float = -1.0
    var max_forward_head_step: float = 0.0
    var maximum_depth: float = 0.0
    var unlocked: bool = false
    var switched_to_front: bool = false
    var previous_head_yaw: float = 0.0
    for frame in range(470):
        var locked: bool = not bool(ik.call("locomotion_ready"))
        var down_active: bool = bool(ik.call("down_pose_active"))
        var elapsed: float = float(ik.get("break_elapsed"))
        var rise_starts: float = float(ik.get("break_recover_start"))
        var turn_enabled: bool = bool(ik.call("standup_turn_enabled", DT))
        var prev_root_yaw: float = boss.rotation.y
        var old_pos: Vector3 = boss.position
        # After documenting early turning toward a 90-degree target, give
        # head tracking a collision-safe, oblique front-side target.
        if down_active and elapsed >= rise_starts and not switched_to_front:
            player.global_position = (boss.global_position
                + boss.global_basis.z * 10.0
                + boss.global_basis.x * 4.0)
            switched_to_front = true
        battle.call("_advance_target_motion", DT)
        if locked:
            var chosen: String = str(battle.get("bittaran_motion"))
            var played: String = str(rig.get("current_clip"))
            if not turn_enabled and (chosen != "Idle" or played != "Idle"):
                _fail(label + ": locomotion played before stand-up")
                return false
            if turn_enabled and (not (chosen in ["Turn", "Approach"])
                    or played != chosen):
                _fail(label + ": locomotion clip missing after rise started")
                return false
            if not turn_enabled and Vector2(
                    boss.position.x - old_pos.x,
                    boss.position.z - old_pos.z).length() > 0.0001:
                _fail(label + ": advanced across arena before stand-up")
                return false
            var yaw_step: float = absf(wrapf(
                boss.rotation.y - prev_root_yaw, -PI, PI))
            var full_yaw_limit: float = (
                deg_to_rad(MAX_TURN_DEGREES_PER_SECOND) * DT
                if turn_enabled else 0.0)
            if yaw_step > full_yaw_limit + 0.0001:
                _fail(label + ": yaw turned before rise or exceeded normal rate")
                return false
            if down_active and elapsed + DT < rise_starts - 0.00001:
                pre_rise_still_frames += 1
                if turn_enabled or yaw_step > 0.00001:
                    _fail(label + ": root yaw began before physical stand-up")
                    return false
            elif down_active and turn_enabled and first_rise_turn_step < 0.0:
                first_rise_turn_step = yaw_step
        battle.call("_finalize_target_pose", DT)
        if down_active and bool(ik.call("down_pose_active")):
            var pose: float = float(ik.call("standup_pose_fraction"))
            var actual_head_yaw: float = float(battle.get("boss_head_yaw"))
            var follow: float = float(battle.call(
                "_head_recovery_follow_weight"))
            if pose <= 0.70:
                if absf(actual_head_yaw) > 0.00015 or follow > 0.000001:
                    _fail(label + ": head followed before 70% recovery")
                    return false
            else:
                head_follow_frames += 1
                var changed: float = absf(actual_head_yaw - previous_head_yaw)
                if first_head_step < 0.0:
                    first_head_step = changed
                if absf(actual_head_yaw) > absf(previous_head_yaw):
                    max_forward_head_step = maxf(
                        max_forward_head_step, changed)
                    if changed > deg_to_rad(
                            HEAD_RECOVERY_DEGREES_PER_SECOND) * DT * follow + 0.001:
                        _fail(label + ": head accelerated too quickly "
                            + str(rad_to_deg(changed)))
                        return false
                var baseline: Dictionary = battle.get(
                    "head_neutral_overlap")
                var component_baseline: Dictionary = battle.get(
                    "head_neutral_component_overlap")
                if not _head_clear(parts, baseline, component_baseline):
                    _fail(label + ": rotating head entered actual upper/lower "
                        + "arm meshes above neutral at frame=" + str(frame))
                    return false
                for id in LEG_IDS:
                    maximum_depth = maxf(maximum_depth, float(
                        parts.call("get_head_leg_penetration_depth", id)))
            previous_head_yaw = actual_head_yaw
        if not locked:
            unlocked = true
            break
    if pre_rise_still_frames < 8 or first_rise_turn_step < (
            deg_to_rad(30.0) * DT):
        _fail(label + ": yaw must stay off before rise and start "
            + "immediately at normal speed: "
            + str(pre_rise_still_frames) + " stationary frames, "
            + str(rad_to_deg(first_rise_turn_step)) + " deg first step")
        return false
    if not unlocked or head_follow_frames < 3:
        _fail(label + ": incomplete rise / head 70-percent test "
            + str([unlocked, head_follow_frames]))
        return false
    if first_head_step > deg_to_rad(0.15):
        _fail(label + ": first head rotation was not gentle: "
            + str(rad_to_deg(first_head_step)))
        return false
    print("V364_CASE_PASS: " + label + " pre-rise still="
        + str(pre_rise_still_frames) + " frames, full-speed first yaw="
        + str(rad_to_deg(first_rise_turn_step)) + "deg, first head step="
        + str(rad_to_deg(first_head_step)) + "deg, maximum head/leg "
        + "depth=" + str(maximum_depth) + "m")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    if not _case(battle, ONE_LEG, "single-leg"):
        return
    if not _case(battle, LEG_IDS, "four-leg"):
        return
    print("GODOT_V364_BITTARAN_HEAD_CLEAR_PASS: normal gait begins with rise, "
        + "slow 70% head entry, no increased arm penetration")
    quit(0)

extends SceneTree
## v361: a foot under HEAD during a turn must topple to its side. The
## authored HEAD/SHIN collider bounds then prevent HEAD penetration.
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("V361_BITTARAN_SUPPORT_FAIL: " + detail)
    quit(1)

func _step(rig: Node3D, ik: RefCounted, parts: Node3D) -> void:
    rig.call("set_motion", "Turn", DT)
    ik.call("advance_ik", DT, "Turn")
    parts.call("sync_bittaran_parts")

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    battle.set("target_move_enabled", false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var boss: Node3D = battle.get("target")
    if ik == null or rig == null or parts == null or boss == null:
        _fail("missing Bittaran IK/rig/physical parts")
        return

    # Real IK rotation: the fixed world feet briefly pass near the HEAD
    # while the body's authored turning clip is applied.
    for frame in range(32):
        boss.rotation.y += 0.0075
        _step(rig, ik, parts)

    battle.set("locked_target_part_id", "leg_fl")
    var hit: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(hit.get("broken", false)):
        _fail("could not start leg break down")
        return

    for i in range(35):
        _step(rig, ik, parts)
    if not bool(ik.call("windup_active")):
        _fail("0.60s windup ended early")
        return

    # Force a deterministic under-head foot in the FINAL turning pose.
    # The gameplay selector must use the actual transformed sole X/Z,
    # not its height or the original non-turning bind anchor. This
    # fixture reproduces the exact geometric overlap after a sharp turn.
    var nose: AABB = parts.call("get_head_swing_aabb")
    var foot_legs: Array = ik.get("legs")
    var foot_leg: Dictionary = foot_legs[2]  # leg_fl
    var foot: Node3D = foot_leg["foot"]
    var old_sole: Vector3 = foot.to_global(foot_leg["sole_local"])
    var adjusted: Vector3 = Vector3(nose.get_center().x + 0.10,
        0.0, nose.get_center().z + 0.10)
    foot.global_position += Vector3(
        adjusted.x - old_sole.x, 0.0, adjusted.z - old_sole.z)
    foot_leg["anchor"] = adjusted
    var original_front: Dictionary = ik.get("front_anchor_rest")
    original_front[2] = adjusted
    ik.set("front_anchor_rest", original_front)

    _step(rig, ik, parts)
    if not bool(ik.call("down_pose_active")):
        _fail("fall did not follow separate windup")
        return
    var supported: String = str(ik.get("head_support_leg_id"))
    if supported != "leg_fl" or str(parts.get("head_support_leg_id")) != supported:
        _fail("XZ under-head support selection incorrect: "
            + supported + " head=" + str(nose.get_center())
            + " foot=" + str(adjusted))
        return
    if not bool(parts.call("can_lock_boss_part", supported))             or not bool(parts.call("can_lock_boss_part", "head")):
        _fail("support leg/head lost manually targetable status")
        return

    parts.call("set_down_lock_enabled", true)
    var candidate: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments",
        boss.global_position + Vector3(0.0, 0.0, 5.0),
        boss.global_position)
    # Test priority without reaching into super-method internals.
    parts.call("set_head_support_leg", "")
    var original: float = parts.call("_parallel_lock_part_distance",
        candidate, "leg_fl")
    parts.call("set_head_support_leg", supported)
    var reduced: float = parts.call("_parallel_lock_part_distance",
        candidate, "leg_fl")
    if original < INF and reduced < original + 4.9:
        _fail("under-head leg did not lose AUTO lock priority: "
            + str(original) + " vs " + str(reduced))
        return

    var max_roll: float = 0.0
    var contact_frames: int = 0
    var physical_overlap_frames: int = 0
    for frame in range(95):
        _step(rig, ik, parts)
        battle.call("_aim_bittaran_head", DT)
        var down: bool = bool(ik.call("down_pose_active"))
        if not down:
            _fail("fall ended before the full recovery window")
            return
        if frame > 20 and frame < 75:
            var sole_rotation: Quaternion = (
                foot as Node3D).global_basis.get_rotation_quaternion()
            max_roll = maxf(max_roll, rad_to_deg(sole_rotation.angle_to(
                foot_leg["anchor_rotation"])))
            var head_box: AABB = parts.call("get_part_aabb", "head")
            var leg_box: AABB = parts.call("get_part_aabb", supported)
            var intersects_xz: bool = (
                head_box.position.x < leg_box.end.x
                and leg_box.position.x < head_box.end.x
                and head_box.position.z < leg_box.end.z
                and leg_box.position.z < head_box.end.z)
            if intersects_xz:
                physical_overlap_frames += 1
                if head_box.position.y < leg_box.end.y - 0.075:
                    var leg_joints: Array = ik.get("legs")
                    var supporting: Dictionary = leg_joints[2]
                    _fail("HEAD penetrated the toppled leg physical collider: "
                        + str(head_box.position.y) + " vs "
                        + str(leg_box.end.y) + " at " + str(frame)
                        + " head=" + str(head_box) + " shin=" + str(leg_box)
                        + " shoulder=" + str((supporting["upper"] as Node3D).global_position)
                        + " knee=" + str((supporting["lower"] as Node3D).global_position)
                        + " foot=" + str((supporting["foot"] as Node3D).global_position)
                        + " soles=" + str(supporting["anchor"])
                        + " pitch=" + str(ik.get("break_chassis_pitch_radians")))
                    return
            if bool(ik.get("head_support_contact")):
                contact_frames += 1
    if max_roll < 30.0:
        _fail("under-head foot failed to topple laterally: max rotation "
            + str(max_roll))
        return
    if physical_overlap_frames > 0 and contact_frames == 0:
        _fail("HEAD/leg collision boxes overlap horizontally but never settle")
        return

    # Recovery returns the old support foot and ordinary lock priority.
    for frame in range(125):
        _step(rig, ik, parts)
    if bool(ik.call("break_reaction_active")):
        _fail("single-shin down failed to recover normally")
        return
    if not str(ik.get("head_support_leg_id")).is_empty()             or not str(parts.get("head_support_leg_id")).is_empty():
        _fail("support priority did not reset on recovery")
        return
    print("GODOT_V361_BITTARAN_SUPPORT_PASS: XZ head-foot threshold, "
        + "lateral topple " + str(max_roll) + "deg, "
        + str(contact_frames) + " supported contact frames, "
        + "HEAD collision and AUTO lock priority safely restored")
    quit(0)

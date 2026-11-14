extends SceneTree
## v361: a forward limb crossing under the falling head MUST support the
## real neutral HEAD above it. The supporting shin loses lock priority only
## while they overlap. No model-authored animation is edited.
const DT: float = 1.0 / 60.0
const SUPPORT = preload("res://scripts/bittaran_head_support.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V361_BITTARAN_HEAD_REST_FAIL: " + message)
    quit(1)

func _planted_floor_ok(ik: RefCounted) -> bool:
    var lowest: float = INF
    for leg in ik.get("legs"):
        if bool(leg["stepping"]):
            continue
        var sole: Vector3 = (leg["foot"] as Node3D).to_global(
            leg["sole_local"])
        lowest = minf(lowest, sole.y)
    return lowest != INF and absf(lowest) < 0.16

func _run() -> void:
    # Isolated regression: real support vs. unrelated distant, floor-height
    # and higher-than-head surfaces. Do not use entire leg union AABB.
    var nose := AABB(Vector3(-0.45, 1.0, -0.4),
        Vector3(0.9, 0.70, 0.8))
    var forearm := AABB(Vector3(-0.28, 0.76, -0.22),
        Vector3(0.55, 0.54, 0.45))
    var surfaces: Dictionary = {
        "leg_fl": [forearm],
        "leg_fr": [AABB(Vector3(3.0, 0.5, 0.0), Vector3.ONE)],
        "leg_rl": [AABB(Vector3(-0.2, -0.05, -0.2),
            Vector3(0.5, 0.16, 0.5))],
        "leg_rr": [AABB(Vector3(-0.3, 1.1, -0.3),
            Vector3(0.6, 2.0, 0.6))]
    }
    var contact: Dictionary = SUPPORT.find_contact(nose, surfaces)
    if str(contact["leg_id"]) != "leg_fl" \
            or absf(float(contact["penetration"]) - 0.325) > 0.001:
        _fail("mesh support should collide only with forearm top: "
            + str(contact))
        return
    if str(SUPPORT.find_contact(
            AABB(nose.position + Vector3.UP * 1.0, nose.size), surfaces)["leg_id"]) != "":
        _fail("airborne HEAD incorrectly rests on distant limb")
        return

    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("target_move_enabled", false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var model: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var boss: Node3D = battle.get("target")
    var head: Node3D = battle.get("bittaran_head")
    var initial_head_rotation: Quaternion = battle.get(
        "boss_head_default_rotation")
    if ik == null or model == null or parts == null or boss == null \
            or head == null:
        _fail("boss scene missing articulated IK or lock parts")
        return

    # Simulate a partial turning pose before the breaking blow: the hips
    # and their world-planted soles do not rotate as a rigid single mesh.
    boss.rotation.y = 0.48
    for i in range(32):
        model.call("set_motion", "Turn", DT)
        ik.call("advance_ik", DT, "Turn")
    battle.set("locked_target_part_id", "leg_fr")
    var damage: Dictionary = battle.call("_apply_target_part_damage",
        "melee", 1, 240.0, 0.0, 0.0)
    if not bool(damage.get("broken", false)) \
            or not bool(ik.call("windup_active")):
        _fail("failed to enter the established 0.6s windup")
        return
    for i in range(39):
        model.call("set_motion", "Idle", DT)
        battle.call("_finalize_target_pose", DT)
    if not bool(ik.call("down_pose_active")):
        _fail("down did not begin after windup")
        return
    var before: AABB = parts.call("get_head_swing_aabb")
    if not before.has_volume():
        _fail("HEAD front contact volume unavailable")
        return

    # Fixture is parented to a REAL articulated foreleg joint. This
    # emulates the swept upper arm moving under the nose during a turn,
    # without altering the source rig/model or collision-only lock Areas.
    # Anchor the test's translated forearm contact piece at the planted
    # front foot joint. A box attached high on a free rotating shin would
    # artificially chase the rising torso by metres after IK corrections;
    # the real supported foreleg has a ground-contact constraint instead.
    var foot_joint: Node3D = model.find_child(
        "FrontFoot_L", true, false) as Node3D
    if foot_joint == null:
        _fail("missing planted front foot joint for forearm fixture")
        return
    var fixture := MeshInstance3D.new()
    fixture.name = "TurnedForearmContactFixture"
    var box := BoxMesh.new()
    box.size = Vector3(0.75, 0.28, 0.75)
    fixture.mesh = box
    foot_joint.add_child(fixture)
    var center: Vector3 = before.get_center()
    center.y = before.position.y + 0.03
    fixture.global_transform = Transform3D(Basis.IDENTITY, center)

    # The descending head should be stopped at the TOP of the foreleg,
    # while keeping the neutral downed head and planted sole constraints.
    var max_support: float = 0.0
    var contacted: bool = false
    for frame in range(10):
        model.call("set_motion", "Idle", DT)
        battle.call("_finalize_target_pose", DT)
        var owner: String = str(battle.get("boss_head_supported_leg"))
        var lifted: float = float(ik.get("head_support_lift_world"))
        if owner == "leg_fl" and lifted > 0.0001:
            contacted = true
            max_support = maxf(max_support, lifted)
        if head.quaternion.angle_to(initial_head_rotation) > 0.003:
            _fail("resting on leg changed original HEAD down quaternion")
            return
        if not _planted_floor_ok(ik):
            _fail("supporting head made planted toes float")
            return
        if owner == "leg_fl":
            var current: AABB = parts.call("get_head_swing_aabb")
            var support_boxes: Array = parts.call(
                "get_leg_support_mesh_boxes", "leg_fl")
            var fixture_box: AABB = AABB()
            for support_box in support_boxes:
                if (support_box as AABB).has_point(fixture.global_position):
                    fixture_box = support_box
                    break
            if fixture_box.has_volume() \
                    and current.position.y < fixture_box.end.y - 0.09:
                _fail("HEAD still sinks through supporting foreleg frame="
                    + str(frame) + " nose.bottom=" + str(current.position.y)
                    + " fixture.top=" + str(fixture_box.end.y)
                    + " support.lift=" + str(lifted)
                    + " support.id=" + owner)
                return
            if int(parts.call("get_boss_lock_priority", "head")) <= int(
                    parts.call("get_boss_lock_priority", "leg_fl")):
                _fail("head lock did not outrank its underlying shin")
                return
            if int(parts.call("get_boss_lock_priority", "leg_fr")) != 0:
                _fail("unrelated leg lock priority changed")
                return
        battle.set("auto_lock_enabled", true)
        battle.call("_acquire_stable_camera_part", DT, false)
        if str(battle.get("locked_target_part_id")) != "head":
            _fail("down AUTO lock did not allow HEAD above supporting leg")
            return
    if not contacted:
        _fail("intersecting forearm never supported falling HEAD")
        return

    # Reset removes both support offset and special lock ranking.
    battle.call("_reset_target_after_respawn")
    if float(ik.get("head_support_lift_world")) != 0.0 \
            or str(parts.get("head_supported_by_leg")) != "" \
            or int(parts.call("get_boss_lock_priority", "leg_fl")) != 0:
        _fail("leg contact or priority remained after recovery/reset")
        return
    print("GODOT_V361_BITTARAN_HEAD_REST_PASS: turning foreleg supports "
        + "neutral HEAD via actual mesh contact, IK keeps ground soles, "
        + "support shin deprioritized under HEAD, AUTO and reset retained. "
        + "peak lift=" + str(max_support))
    quit(0)

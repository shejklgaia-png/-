extends SceneTree
## v353: front->rear / rear->front AUTO switching is exactly reciprocal.
## The ray still targets the BODY mesh center at SERA height. The selection
## half-plane is halfway between the ACTUAL four shin lock boxes.
const EPS: float = 0.003
const SAMPLE_DEGREES: Array[float] = [
    -60.0, -50.0, -40.0, -30.0, -20.0, -10.0, -5.0,
    -2.0, -1.0, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V353_BITTARAN_SYMMETRIC_LOCK_FAIL: " + message)
    quit(1)

func _front(id: String) -> bool:
    return id == "leg_fl" or id == "leg_fr"

func _rear(id: String) -> bool:
    return id == "leg_rl" or id == "leg_rr"

func _sample_actor(model: Node3D, midpoint: Vector3, longitudinal: Vector2,
        direction: int, signed_angle_degrees: float) -> Vector3:
    var axis: Vector2 = longitudinal.normalized()
    var side: Vector2 = Vector2(-axis.y, axis.x) * float(direction)
    var degrees: float = deg_to_rad(signed_angle_degrees)
    var horizontal: Vector2 = (
        side * cos(degrees) + axis * sin(degrees)) * 13.0
    return model.to_global(midpoint
        + Vector3(horizontal.x, 0.0, horizontal.y))

func _assert_sweep(parts: Node3D, model: Node3D, direction: int) -> bool:
    # v354: compare with actual post-IK shin Areas, independently of the
    # selector. The old rig-local stance hid the chassis/feet yaw mismatch.
    var areas: Dictionary = parts.get("camera_areas")
    var front_local: Vector3 = model.to_local((
        areas["leg_fl"].global_position + areas["leg_fr"].global_position) * 0.5)
    var rear_local: Vector3 = model.to_local((
        areas["leg_rl"].global_position + areas["leg_rr"].global_position) * 0.5)
    var midpoint: Vector3 = (front_local + rear_local) * 0.5
    var axis: Vector2 = Vector2(
        front_local.x - rear_local.x,
        front_local.z - rear_local.z)
    if axis.length() < 0.05:
        _fail("degenerate front/rear axis")
        return false
    var root: Node3D = model.get_parent() as Node3D
    var front_actor: Vector3 = _sample_actor(model, midpoint, axis,
        direction, 2.0)
    var rear_actor: Vector3 = _sample_actor(model, midpoint, axis,
        direction, -2.0)
    var front_id: String = parts.call("select_actor_parallel_lines_part",
        front_actor, root.global_position)
    var rear_id: String = parts.call("select_actor_parallel_lines_part",
        rear_actor, root.global_position)
    if not _front(front_id) or not _rear(rear_id):
        _fail("forward and rearward positions do not straddle middle")
        return false
    # At equal 1-degree offsets from either side of the halfway plane,
    # choose exactly the expected front/rear part. This is a reciprocal
    # switching threshold, not a distance-to-first-intersection bias.
    var snapshots: Array[String] = []
    for degrees in SAMPLE_DEGREES:
        var actor: Vector3 = _sample_actor(model, midpoint, axis,
            direction, degrees)
        var selected: String = parts.call("select_actor_parallel_lines_part",
            actor, root.global_position)
        var expected_front: bool = degrees > 0.0
        if expected_front and not _front(selected):
            _fail("rear->front threshold late at angle "
                + str(degrees) + ": " + selected)
            return false
        if not expected_front and not _rear(selected):
            _fail("front->rear threshold late at angle "
                + str(degrees) + ": " + selected)
            return false
        snapshots.append(selected)
    var count_forward: int = 0
    var count_reverse: int = 0
    var idx_forward: int = -1
    var idx_reverse: int = -1
    for idx in range(1, snapshots.size()):
        if _front(snapshots[idx]) != _front(snapshots[idx - 1]):
            count_forward += 1
            idx_forward = idx
    for idx in range(snapshots.size() - 2, -1, -1):
        if _front(snapshots[idx]) != _front(snapshots[idx + 1]):
            count_reverse += 1
            idx_reverse = idx + 1
    if count_forward != 1 or count_reverse != 1 or idx_forward != idx_reverse:
        _fail("opposite traversal speeds/switch indices disagree: "
            + str(idx_forward) + " / " + str(idx_reverse))
        return false
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("boss scene unavailable")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var model: Node3D = battle.get("bittaran_rig")
    var target: Node3D = battle.get("target")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if parts == null or model == null or target == null or ik == null:
        _fail("boss rig or lock manager missing")
        return
    if not bool(parts.get("lock_halfway_initialized")):
        _fail("four shin centers not calibrated")
        return
    var front: Vector3 = parts.get("lock_front_mid_local")
    var rear: Vector3 = parts.get("lock_rear_mid_local")
    var center: Vector3 = (
        parts.call("get_front_rear_lock_midpoint_world") as Vector3)
    var world_front: Vector3 = model.to_global(front)
    var world_rear: Vector3 = model.to_global(rear)
    if absf(center.distance_to(world_front)
            - center.distance_to(world_rear)) > EPS:
        _fail("front/rear lock changeover not at equal distance")
        return
    var actual_body_center: Vector3 = (
        parts.call("get_body_hit_aabb") as AABB).get_center()
    var samples: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments",
        model.to_global((front + rear) * 0.5 + Vector3(9, 0, 1)),
        target.global_position)
    var endpoint: Vector3 = (samples[1] + samples[3]) * 0.5
    if Vector2(endpoint.x - actual_body_center.x,
            endpoint.z - actual_body_center.z).length() > EPS:
        _fail("horizontal two-ray destination no longer BODY mesh center")
        return
    if not _assert_sweep(parts, model, 1) or not _assert_sweep(
            parts, model, -1):
        return

    # Walking, pitch and 2x rig scale preserve reciprocity; the halfway
    # plane is sampled from the current visible shins. Evaluate both sides.
    for frame in range(90):
        var dt: float = 1.0 / 60.0
        target.position += Vector3(0.009, 0.0, 0.013)
        target.rotation.y += deg_to_rad(11.0) * dt
        model.call("set_motion", "Approach", dt)
        ik.call("advance_ik", dt, "Approach")
        parts.call("sync_bittaran_parts")
        if frame % 15 == 0:
            if not _assert_sweep(parts, model, 1) or not _assert_sweep(
                    parts, model, -1):
                _fail("switching skewed during gait at frame " + str(frame))
                return
    # Lock boxes themselves remain 2x and frozen in Y. They continue to
    # govern the actual two-beam contact within the selected front/rear pair.
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var selection: AABB = parts.call("get_shin_selection_box", id)
        var area: Area3D = parts.get("camera_areas")[id]
        if area.global_position.distance_to(selection.get_center()) > EPS:
            _fail("2x shin lock-only selection volume moved")
            return
    print("GODOT_V353_BITTARAN_SYMMETRIC_LOCK_PASS: reciprocal front/rear "
        + "switch at exact standing shin midpoint, both sides, both travel "
        + "directions, 90 moving frames, BODY ray unchanged")
    quit(0)

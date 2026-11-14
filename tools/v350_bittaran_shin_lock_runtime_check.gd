extends SceneTree
## v350: four shin selection-only boxes are exactly 2x their own MESH.
## Their world Y is fixed while the rig runs, bobs, turns and steps.
const SHIN_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const EPSILON: float = 0.002

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V350_BITTARAN_SHIN_LOCK_FAIL: " + reason)
    quit(1)

func _close(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) < EPSILON

func _check_volume(parts: Node3D, id: String, expected_size: Vector3,
        fixed_height: float) -> bool:
    var area: Area3D = parts.get("camera_areas")[id]
    var collision: CollisionShape3D = area.get_node("CameraOnlyBox")
    var box: BoxShape3D = collision.shape
    var raw_shin: AABB = parts.call("_shin_mesh_bounds", id)
    var lock_box: AABB = parts.call("get_shin_selection_box", id)
    var center: Vector3 = lock_box.get_center()
    if not _close(box.size, expected_size) or not _close(
            lock_box.size, expected_size):
        _fail("lock box is not exactly 2x original mesh: " + id
            + " got " + str(box.size) + " expected " + str(expected_size))
        return false
    if absf(center.y - fixed_height) > EPSILON or absf(
            area.global_position.y - fixed_height) > EPSILON:
        _fail("selection box oscillated vertically: " + id)
        return false
    if Vector2(area.global_position.x - raw_shin.get_center().x,
            area.global_position.z - raw_shin.get_center().z).length() > EPSILON:
        _fail("selection box stopped following moving shin horizontally: " + id)
        return false
    if area.collision_layer != 0 or area.collision_mask != 0             or area.monitoring or area.monitorable:
        _fail("lock-only selection Area3D participates in physics: " + id)
        return false
    # Both horizontal lock rays use this world-space Area3D, not melee AABB.
    var from: Vector3 = center + Vector3(0.0, 0.0, 14.0)
    var through: Vector3 = center - Vector3(0.0, 0.0, 14.0)
    var dist: float = float(parts.call(
        "_camera_lock_part_volume_distance", from, through, id))
    if dist >= INF:
        _fail("camera/auto ray misses enlarged selection volume: " + id)
        return false
    var real_hit: AABB = parts.call("get_part_aabb", id)
    var solid: CollisionShape3D = parts.get("combat_shapes")[id]
    if not _close((solid.shape as BoxShape3D).size, real_hit.size):
        _fail("attack/movement collider was enlarged with lock volume: " + id)
        return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene failed to load")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var target: Node3D = battle.get("target")
    if parts == null or rig == null or ik == null or target == null:
        _fail("boss combat rig, parts, or IK missing")
        return
    var size_at_rest: Dictionary = {}
    var height_at_rest: Dictionary = {}
    for id in SHIN_IDS:
        var model_bounds: AABB = parts.call("_shin_mesh_bounds", id)
        size_at_rest[id] = model_bounds.size * 2.0
        height_at_rest[id] = model_bounds.get_center().y
        if not _check_volume(parts, id, size_at_rest[id], height_at_rest[id]):
            return
    # Move and rotate the ACTUAL boss while playing its authored walk and
    # planted-foot IK.  Every leg should translate in XZ yet never change
    # its lock-only shape dimensions or elevation.
    var moved_xz: bool = false
    var actual_y_moved: bool = false
    var initial_center: AABB = parts.call("_shin_mesh_bounds", "leg_fl")
    for frame in range(185):
        var dt: float = 1.0 / 60.0
        target.position += Vector3(0.010, 0.0, 0.013)
        target.rotation.y += deg_to_rad(12.0) * dt
        var motion: String = "Approach" if frame < 125 else "Turn"
        rig.call("set_motion", motion, dt)
        ik.call("advance_ik", dt, motion)
        parts.call("sync_bittaran_parts")
        for id in SHIN_IDS:
            if not _check_volume(parts, id, size_at_rest[id], height_at_rest[id]):
                _fail("during walking frame " + str(frame))
                return
        var actual_now: AABB = parts.call("_shin_mesh_bounds", "leg_fl")
        moved_xz = moved_xz or Vector2(
            actual_now.get_center().x - initial_center.get_center().x,
            actual_now.get_center().z - initial_center.get_center().z).length() > 0.15
        actual_y_moved = actual_y_moved or absf(
            actual_now.get_center().y - height_at_rest["leg_fl"]) > 0.005
    if not moved_xz:
        _fail("walking pose never moved the selected shin horizontally")
        return
    # An exaggerated bob directly applied to the model proves the lock
    # height is independent of real shin world-Y even when IK can't cancel it.
    rig.position.y += 0.26
    parts.call("sync_bittaran_parts")
    for id in SHIN_IDS:
        if not _check_volume(parts, id, size_at_rest[id], height_at_rest[id]):
            return
    var shifted: AABB = parts.call("_shin_mesh_bounds", "leg_fr")
    if absf(shifted.get_center().y - height_at_rest["leg_fr"]) < 0.02:
        _fail("bob fixture did not actually lift the rendered shin")
        return
    # HEAD and BODY are still 1.15x and unaffected by the lock-only 2x.
    for id in ["", "head"]:
        var actual: AABB = parts.call("get_part_aabb", id)
        var area: Area3D = parts.get("camera_areas")[id]
        var shape: BoxShape3D = (
            (area.get_node("CameraOnlyBox") as CollisionShape3D).shape as BoxShape3D)
        if not _close(shape.size, actual.size * 1.15):
            _fail("BODY or HEAD selection volume inadvertently changed")
            return
    print("GODOT_V350_BITTARAN_SHIN_LOCK_PASS: 4 raw-shin 2x lock areas, "
        + "horizontal tracking, standing-height Y, zero physical impact, "
        + "BODY/HEAD original selection size")
    quit(0)

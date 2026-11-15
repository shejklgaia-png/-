extends SceneTree
## v395: the physical, sword, lock and head/leg query region is a
## single HEAD-local box enclosing only the FRONT 70% of the authored
## rectangular mesh. The rearmost 30% must never register HEAD hits.
const DT: float = 1.0 / 60.0
const EPS: float = 0.003

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V376_BITTARAN_HEAD_MESH_FAIL: " + reason)
    quit(1)


func _check_head_box(parts: Node3D) -> bool:
    var entries: Array = parts.get("head_mesh_solids")
    if entries.size() != 1:
        _fail("HEAD must have exactly one front-70% physical box")
        return false
    var record: Dictionary = entries[0]
    var head: Node3D = record["head"]
    var solid: CollisionShape3D = record["solid"]
    var body: Node3D = parts.get("collision_body")
    var region: AABB = parts.call("get_head_front_local_box")
    if head == null or solid == null or solid.get_parent() != body             or not solid.shape is BoxShape3D:
        _fail("front 70% solid must be a BoxShape3D on physical boss")
        return false
    if (solid.shape as BoxShape3D).size.distance_to(region.size) > EPS:
        _fail("HEAD box collider size does not match front 70%")
        return false
    var meshes: Array[MeshInstance3D] = []
    parts.call("_collect_head_meshes", head, meshes)
    var z_min: float = INF
    var z_max: float = -INF
    var low: Vector3 = Vector3(INF, INF, INF)
    var high: Vector3 = Vector3(-INF, -INF, -INF)
    for mesh in meshes:
        var bounds: AABB = mesh.mesh.get_aabb()
        for corner in range(8):
            var local: Vector3 = head.to_local(
                mesh.to_global(bounds.get_endpoint(corner)))
            z_min = minf(z_min, local.z)
            z_max = maxf(z_max, local.z)
            low = low.min(local)
            high = high.max(local)
    if absf(region.position.z - z_min) > EPS or (
            absf(region.size.z - (z_max-z_min)*0.70) > EPS):
        _fail("HEAD does not cover exactly frontmost 70% in -Z")
        return false
    if absf(region.size.x - (high.x-low.x)) > EPS or (
            absf(region.size.y - (high.y-low.y)) > EPS):
        _fail("HEAD rectangular width/height changed")
        return false
    var expected: Transform3D = head.global_transform * (
        record["local_offset"] as Transform3D)
    if solid.global_position.distance_to(expected.origin) > EPS:
        _fail("HEAD front-70% solid detached from actual head")
        return false

    # The sword MUST hit the included front box but never its rear 30%.
    var front: Vector3 = region.get_center()
    var front_hit: Variant = parts.call("get_head_mesh_blade_contact",
        head.to_global(Vector3(front.x, front.y,
            region.position.z - 0.4)),
        head.to_global(Vector3(front.x, front.y,
            region.end.z - region.size.z * 0.2)), 0.0)
    if front_hit == null:
        _fail("blade through front 70% did not hit")
        return false
    var rear_z: float = region.end.z + (z_max-region.end.z)*0.55
    var rear_hit: Variant = parts.call("get_head_mesh_blade_contact",
        head.to_global(Vector3(front.x - 0.15, front.y, rear_z)),
        head.to_global(Vector3(front.x + 0.15, front.y, rear_z)), 0.0)
    if rear_hit != null:
        _fail("blade hit the excluded back 30% of HEAD")
        return false
    return true


func _run() -> void:
    var boss_constants: Dictionary = (load(
        "res://scripts/bittaran_battle.gd") as GDScript
        ).get_script_constant_map()
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if not _check_head_box(parts):
        return
    var head: Node3D = parts.get("bone_nodes")["head"]
    var original: Quaternion = head.quaternion
    var original_box: AABB = parts.call("get_head_swing_aabb")
    head.quaternion = (original * Quaternion(
        Vector3.UP, deg_to_rad(35.0))).normalized()
    parts.call("sync_bittaran_parts")
    # Physical bodies are updated with set_deferred, at the frame end.
    await process_frame
    if not _check_head_box(parts):
        return
    var rotated_box: AABB = parts.call("get_head_swing_aabb")
    if rotated_box.get_center().distance_to(
            original_box.get_center()) < 0.001:
        _fail("HEAD front-70% box did not follow yaw rotation")
        return
    head.quaternion = original
    parts.call("sync_bittaran_parts")
    if absf(float(
            boss_constants["HEAD_TRACK_STANDUP_START_FRACTION"])
            - 0.70) > 0.00001:
        _fail("70% head-follow stand-up threshold changed")
        return
    if absf(float(ik.get("break_duration")) - float(
            ik.get("break_recover_start")) - 1.0) > 0.001:
        _fail("boss stand-up timing changed")
        return
    print("GODOT_V376_BITTARAN_HEAD_MESH_PASS: front 70% rectangular "
        + "head physical/sword/lock region, rear 30% excluded, "
        + "follows yaw and preserves stand-up timing")
    quit(0)

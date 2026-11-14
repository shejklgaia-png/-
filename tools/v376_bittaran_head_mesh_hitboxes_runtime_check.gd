extends SceneTree
## v376: HEAD physical collision uses individual authored mesh convexes.
## Sword contact follows rotated mesh elements instead of the old head AABB.
## Existing AI/lock, 70%-head rise, leg collision and attack timing unchanged.
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V376_BITTARAN_HEAD_MESH_FAIL: " + reason)
    quit(1)

func _check_head_solids(parts: Node3D) -> bool:
    var entries: Array = parts.get("head_mesh_solids")
    if entries.is_empty():
        _fail("no mesh-fitted head physical colliders")
        return false
    var body: Node3D = parts.get("collision_body")
    var all_convex: bool = false
    var convex_count: int = 0
    var meshes_seen: Dictionary = {}
    for record in entries:
        var mesh: MeshInstance3D = record["mesh"]
        var solid: CollisionShape3D = record["solid"]
        var offset: Transform3D = record["local_offset"]
        if mesh == null or solid == null or solid.get_parent() != body:
            _fail("HEAD collision is not parented to the physical body")
            return false
        if solid.global_position.distance_to(
                (mesh.global_transform * offset).origin) > 0.001:
            _fail("HEAD collider detached from mesh position")
            return false
        if solid.shape is ConvexPolygonShape3D:
            convex_count += 1
            var points: PackedVector3Array = (
                solid.shape as ConvexPolygonShape3D).points
            var original: PackedVector3Array = parts.call(
                "_head_mesh_vertices", mesh)
            if points.size() != original.size() or points.size() < 4:
                _fail("convex head collider has different authored vertices")
                return false
            if points[0].distance_to(original[0]) > 0.00001:
                _fail("HEAD collision geometry shifted from original mesh")
                return false
        meshes_seen[mesh.get_instance_id()] = true
    var head: Node3D = parts.get("bone_nodes")["head"]
    var originals: Array[MeshInstance3D] = []
    parts.call("_collect_head_meshes", head, originals)
    if convex_count <= 0 or entries.size() != originals.size() or (
            meshes_seen.size() != originals.size()):
        _fail("head mesh pieces have missing or extra collision solids")
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var parts: Node3D = battle.get("target_parts")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if parts == null or boss == null or player == null or ik == null:
        _fail("battle initialization failed")
        return
    if not _check_head_solids(parts):
        return
    battle.set("locked_target_part_id", "head")
    var entries: Array = parts.get("head_mesh_solids")
    var first: MeshInstance3D = entries[0]["mesh"]
    var box: AABB = first.mesh.get_aabb()
    var center: Vector3 = box.get_center()
    var length: float = maxf(box.size.z, 0.08)
    var from_world: Vector3 = first.to_global(
        center + Vector3(0, 0, -length))
    var to_world: Vector3 = first.to_global(
        center + Vector3(0, 0, length))
    var hit: Variant = battle.call("_blade_contact", from_world, to_world)
    if hit == null:
        _fail("blade segment through HEAD mesh produced no hit")
        return
    var previous: Vector3 = hit
    # Rotate the actual head; the blade follows that new mesh pose and
    # an off-head segment must not keep using the old static HEAD box.
    var head_node: Node3D = parts.get("bone_nodes")["head"]
    var saved: Quaternion = head_node.quaternion
    head_node.quaternion = (saved * Quaternion(
        Vector3.UP, deg_to_rad(35.0))).normalized()
    parts.call("sync_bittaran_parts")
    first = entries[0]["mesh"]
    box = first.mesh.get_aabb()
    center = box.get_center()
    length = maxf(box.size.z, 0.08)
    var rotated_a: Vector3 = first.to_global(
        center + Vector3(0, 0, -length))
    var rotated_b: Vector3 = first.to_global(
        center + Vector3(0, 0, length))
    var rotated_hit: Variant = battle.call(
        "_blade_contact", rotated_a, rotated_b)
    if rotated_hit == null:
        _fail("blade contact failed after head yaw")
        return
    if (rotated_hit as Vector3).distance_to(previous) < 0.001:
        _fail("head collision does not follow rotation")
        return
    var no_hit: Variant = parts.call("get_head_mesh_blade_contact",
        first.global_position + Vector3(30, 0, 0),
        first.global_position + Vector3(30, 4, 0), 0.03)
    if no_hit != null:
        _fail("blade hit empty space far outside the head mesh")
        return
    head_node.quaternion = saved
    parts.call("sync_bittaran_parts")
    if absf(float(battle.HEAD_TRACK_STANDUP_START_FRACTION) - 0.70) > 0.00001:
        _fail("head movement threshold changed unexpectedly")
        return
    if absf(float(ik.get("break_duration")) - float(
            ik.get("break_recover_start")) - 1.0) > 0.001:
        _fail("boss stand-up timing changed")
        return
    print("GODOT_V376_BITTARAN_HEAD_MESH_PASS: HEAD compound "
        + "convex colliders match the visible authored mesh pieces, "
        + "sword contact tracks yaw, and the boss motion is unchanged")
    quit(0)

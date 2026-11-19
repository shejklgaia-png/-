extends SceneTree
## v488: headless validation of both separate modes and the 3D NEXUS tap target.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_HUB_RUNTIME_FAIL: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    if packed == null:
        _fail("overworld scene missing")
        return
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    var sera: Node3D = hub.get("player") as Node3D
    var cam: Camera3D = hub.get("cam") as Camera3D
    var crate: Node3D = hub.get_node_or_null("CRATE") as Node3D
    var building: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    if sera == null or cam == null or crate == null or building == null or not cam.current:
        _fail("overworld actor, roaming CRATE, building, or camera missing")
        return
    # v490: a continuous ground surface covers ALL four screen corners even
    # as the camera follows SERA to each reachable edge of the outdoor hub.
    var ground: MeshInstance3D = hub.get_node_or_null(
        "PatchworkSteelFloor/ContinuousGround") as MeshInstance3D
    if ground == null or not ground.mesh is BoxMesh:
        _fail("one-piece opaque ground under all decorative plates is missing")
        return
    var ground_box: BoxMesh = ground.mesh as BoxMesh
    var half_x: float = ground_box.size.x * 0.5
    var half_z: float = ground_box.size.z * 0.5
    var ground_top: float = ground.global_position.y + ground_box.size.y * 0.5
    # v491: check the visible, multicolored 3D GRID plates (not just v490's
    # uniform continuous ground). Batching avoids thousands of draw calls.
    var tiled_floor: Node3D = hub.get_node("PatchworkSteelFloor") as Node3D
    var grid_batches: int = 0
    var grid_tiles: int = 0
    var min_x: float = INF
    var max_x: float = -INF
    var min_z: float = INF
    var max_z: float = -INF
    # Headless Godot's dummy RenderingServer does not round-trip GPU-backed
    # per-instance transforms (all read back as Vector3.ZERO). Verify the
    # renderer's explicit conservative culling AABB instead, alongside count,
    # color materials and the source-side coordinate placement assertions.
    for child in tiled_floor.get_children():
        if not child.name.begins_with("GridPlateBatch_"):
            continue
        var grid_node: MultiMeshInstance3D = child as MultiMeshInstance3D
        if grid_node == null or grid_node.multimesh == null:
            _fail("grid batch is missing instanced geometry")
            return
        var batch: MultiMesh = grid_node.multimesh
        var grid_mesh: BoxMesh = batch.mesh as BoxMesh
        if grid_mesh == null or grid_node.material_override == null:
            _fail("visible colored grid geometry/material missing")
            return
        grid_batches += 1
        grid_tiles += batch.instance_count
        if absf(grid_mesh.size.x - 2.94) > 0.01 or absf(grid_mesh.size.z - 2.94) > 0.01:
            _fail("grid has lost its authored 2.94m square plates")
            return
        var region: AABB = batch.custom_aabb
        if region.size.x <= 0.0 or region.size.z <= 0.0:
            _fail("instanced grid has no explicit broad culling bounds")
            return
        min_x = minf(min_x, region.position.x)
        max_x = maxf(max_x, region.end.x)
        min_z = minf(min_z, region.position.z)
        max_z = maxf(max_z, region.end.z)
    if grid_batches != 6 or grid_tiles < 7225:
        _fail("full-screen GRID was not batched into six colored multimeshes")
        return
    if min_x > -127.0 or max_x < 127.0 or min_z > -127.0 or max_z < 127.0:
        _fail("grid extents did not expand around entire viewport: x[%.3f, %.3f], z[%.3f, %.3f], batches=%d, tiles=%d" %
            [min_x, max_x, min_z, max_z, grid_batches, grid_tiles])
        return
    var view: Vector2 = cam.get_viewport().get_visible_rect().size
    if view.x < 1.0 or view.y < 1.0:
        _fail("camera viewport invalid")
        return
    for px in [-6.0, 0.0, 6.0]:
        for pz in [-10.0, 5.6, 10.0]:
            cam.position = Vector3(px * 0.18, 19.6, 13.3 + pz * 0.12)
            cam.look_at(Vector3(px * 0.18, 0.0, -2.2 + pz * 0.12), Vector3.UP)
            for screen in [Vector2(0, 0), Vector2(view.x, 0),
                    Vector2(0, view.y), Vector2(view.x, view.y)]:
                var origin: Vector3 = cam.project_ray_origin(screen)
                var direction: Vector3 = cam.project_ray_normal(screen)
                if direction.y >= -0.01:
                    _fail("camera shows sky instead of ground")
                    return
                var t: float = (ground_top - origin.y) / direction.y
                var hit: Vector3 = origin + direction * t
                if t <= 0.0 or absf(hit.x) >= half_x or absf(hit.z) >= half_z:
                    _fail("ground ends inside viewport at player (%.1f, %.1f) / screen %s" %
                        [px, pz, str(screen)])
                    return
                # Do not accept a plain ungridded background under the camera.
                if hit.x < min_x or hit.x > max_x \
                        or hit.z < min_z or hit.z > max_z:
                    _fail("GRID itself ends inside viewport at player (%.1f, %.1f)" %
                        [px, pz])
                    return
    cam.position = Vector3(0, 19.6, 13.3)
    cam.look_at(Vector3(0, 0, -2.2), Vector3.UP)

    var spot: Vector2 = cam.unproject_position(building.global_position + Vector3(0, 2.5, 0))
    if not bool(hub.call("_nexus_hit", spot)):
        _fail("tap on projected NEXUS building not recognized")
        return
    if bool(hub.call("_nexus_hit", Vector2(-1000, -1000))):
        _fail("tap outside building incorrectly recognized")
        return
    var start: Vector3 = crate.position
    hub.call("_update_crate", 6.0)
    if crate.position.distance_to(start) < 0.2:
        _fail("CRATE is still stationary")
        return
    if absf(crate.position.y - 0.06) > 0.00001:
        _fail("CRATE left its planar travel height")
        return
    sera.position = Vector3(0, 0.08, 8)
    hub.call("_move_player", Vector2(1, 1), 50.0)
    if sera.position.x > 6.0 or sera.position.z > 10.0:
        _fail("overworld SERA escaped floor bounds")
        return
    if absf(sera.position.y - 0.08) > 0.00001:
        _fail("SERA left planar travel height")
        return
    print("SERA_BASE_HUB_RUNTIME_PASS")
    quit(0)

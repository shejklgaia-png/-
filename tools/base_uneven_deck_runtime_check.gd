extends SceneTree
## Independent geometry contract: variable slab spans, full coverage and no overlaps.
const DeckLayout = preload("res://scripts/sera_base_deck_layout.gd")
const RADIUS: int = 42
const STEP: float = 3.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_UNEVEN_DECK_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("base scene missing")
        return
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    var floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    var detail: Node3D = hub.get_node_or_null(
        "PatchworkSteelFloor/DeckDetailGeometry") as Node3D
    if floor == null or detail == null:
        _fail("deck and surface detail hierarchy missing")
        return
    var building: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    var machines: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if building == null or machines == null:
        _fail("scene facilities could not be found")
        return
    var specs: Array = machines.get_script().get_script_constant_map().get(
        "FACILITY_SPECS", [])
    var sites: Array[Dictionary] = DeckLayout.facility_sites(
        building.position, specs)
    var layout: Array[Dictionary] = DeckLayout.generate(RADIUS, STEP, sites)
    if layout.size() < 3000 or layout.size() > 10500:
        _fail("unexpected panel count " + str(layout.size()))
        return
    var units: int = (RADIUS * 2 + 1) * 2
    var coverage := PackedByteArray()
    coverage.resize(units * units)
    var shapes: Dictionary = {}
    for panel in layout:
        var cell: Rect2 = panel["cells"]
        var x0: int = roundi(cell.position.x * 2.0)
        var z0: int = roundi(cell.position.y * 2.0)
        var nx: int = roundi(cell.size.x * 2.0)
        var nz: int = roundi(cell.size.y * 2.0)
        if x0 < 0 or z0 < 0 or x0 + nx > units or z0 + nz > units:
            _fail("panel extends beyond installed floor")
            return
        var kind: String = "%sx%s" % [str(nx), str(nz)]
        shapes[kind] = int(shapes.get(kind, 0)) + 1
        var real_size: Vector2 = panel["size"]
        if not is_equal_approx(real_size.x, cell.size.x * STEP - DeckLayout.GAP) or (
                not is_equal_approx(real_size.y, cell.size.y * STEP - DeckLayout.GAP)):
            _fail("variable panel mesh geometry does not match tiling units")
            return
        for rz in range(z0, z0 + nz):
            for rx in range(x0, x0 + nx):
                var index: int = rz * units + rx
                if coverage[index] != 0:
                    _fail("two panels overlap at half-cell " + str(index))
                    return
                coverage[index] = 1
    for covered in coverage:
        if covered != 1:
            _fail("deck has uncovered area beyond the deliberate 6cm seams")
            return
    if shapes.size() < 6 or not shapes.has("4x4") or not shapes.has("2x2") or (
            not shapes.has("1x2") and not shapes.has("2x1")):
        _fail("not enough large, medium and narrow panel variants: " + str(shapes))
        return
    var color_batches: int = 0
    var instanced_panels: int = 0
    for child in floor.get_children():
        if not child.name.begins_with("GridPlateBatch_"):
            continue
        var multi: MultiMeshInstance3D = child as MultiMeshInstance3D
        if multi == null or multi.multimesh == null or (
                not multi.multimesh.mesh is BoxMesh) or (
                (multi.multimesh.mesh as BoxMesh).size != Vector3.ONE):
            _fail("deck must use one unit cube Mesh batched by material")
            return
        color_batches += 1
        instanced_panels += multi.multimesh.instance_count
    if color_batches != 6 or instanced_panels != layout.size():
        _fail("rendered panel instances differ from deterministic slab layout")
        return
    var seam_count: int = 0
    for child in detail.get_children():
        if child.name.begins_with("PanelSeams_") and child is MultiMeshInstance3D:
            seam_count += child.multimesh.instance_count
    if seam_count < 300:
        _fail("slab boundaries were not traced from actual varying dimensions")
        return
    print("SERA_BASE_UNEVEN_DECK_RUNTIME_PASS panels=", layout.size(),
        " variants=", shapes)
    quit(0)

extends SceneTree
## Polygon-level verification independent of the author's feature names.
const Polygons = preload("res://scripts/sera_base_polygon_meshes.gd")
func _initialize() -> void:
    call_deferred("_run")

func _fail(s: String) -> void:
    push_error("SERA_BASE_POLYGON_GEOMETRY_FAIL: " + s)
    quit(1)

func _check_mesh(kind: String) -> bool:
    var mesh: ArrayMesh = Polygons.make(kind)
    if mesh == null or mesh.get_surface_count() != 1:
        return false
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    if vertices.size() < 36 or vertices.size() % 3 != 0:
        return false
    if normals.size() != vertices.size() or uvs.size() != vertices.size():
        return false
    var has_non_axis_edge: bool = false
    for i in range(0, vertices.size(), 3):
        var a: Vector3 = vertices[i]
        var b: Vector3 = vertices[i + 1]
        var c: Vector3 = vertices[i + 2]
        var geometric: Vector3 = (b - a).cross(c - a)
        if geometric.length_squared() < 0.00000001:
            return false
        # Godot's clockwise front-face rule is opposite to the right-handed
        # cross product. The explicit exported shading normals still point out.
        if geometric.normalized().dot(normals[i]) > -0.96:
            return false
        for v in [a, b, c]:
            if absf(v.x) > 0.51 or absf(v.y) > 0.51 or absf(v.z) > 0.51:
                return false
            if not v.is_finite():
                return false
        if not is_zero_approx(a.x - b.x) and not is_zero_approx(a.z - b.z):
            has_non_axis_edge = true
    return has_non_axis_edge

func _run() -> void:
    for kind in ["deck", "bevel", "hopper", "hood", "canvas", "drum", "gear"]:
        var first: ArrayMesh = Polygons.make(kind)
        var second: ArrayMesh = Polygons.make(kind)
        if first == null or first != second:
            _fail("polygon unit mesh not cached/reused: " + kind)
            return
        if not _check_mesh(kind):
            _fail("degenerate/box-only polygon sculpt: " + kind)
            return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for attempt in range(20):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    if floor == null:
        _fail("deck was not created")
        return
    var plate: MultiMeshInstance3D = floor.get_node_or_null("GridPlateBatch_00") as MultiMeshInstance3D
    if plate == null or not plate.multimesh.mesh is ArrayMesh:
        _fail("actual six-batch deck is not polygonal")
        return
    var expected := {
        "NEXUSBuilding/NexusArchitecture": "NexusCutCornerShell",
        "BaseFacilities/LABO/IndustrialModel": "FreshLabFabricationBed",
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": "FreshCollectorSortPan",
        "BaseFacilities/SMELTER/IndustrialModel": "FreshSmelterFurnaceBase",
        "BaseFacilities/RECYCLER/IndustrialModel": "FreshRecyclerRoller",
        "BaseFacilities/GENERATOR/IndustrialModel": "FreshGeneratorFrontRotor",
        "BaseFacilities/STORAGE/IndustrialModel": "FreshStorageOffsetStacks",
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": "FreshTerminalDisplayFrame",
    }
    for path in expected:
        var group: Node3D = hub.get_node_or_null(path) as Node3D
        if group == null or not (group.get_meta("unique_model_features", []) as Array).has(expected[path]):
            _fail("facility polygon was not installed: " + path)
            return
        # The archived command hall retains its authored polygonal armor.
        # Seven facilities deliberately replace rounded/beveled parts with
        # hard-edge BoxMesh batches; verify those real mesh instances instead.
        var is_nexus: bool = path.begins_with("NEXUSBuilding/")
        var count: int = 0
        for child in group.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var draw: MultiMeshInstance3D = child as MultiMeshInstance3D
            if draw.multimesh == null:
                continue
            if is_nexus and (
                    str(child.name).begins_with("Architectural_bevel_") or
                    str(child.name).begins_with("Architectural_hopper_") or
                    str(child.name).begins_with("Architectural_hood_") or
                    str(child.name).begins_with("Architectural_roof_")):
                if not draw.multimesh.mesh is ArrayMesh:
                    _fail("archived NEXUS armor polygon mesh missing")
                    return
                count += draw.multimesh.instance_count
            elif not is_nexus and str(child.name).begins_with("Architectural_cube_"):
                if not draw.multimesh.mesh is BoxMesh:
                    _fail("angular facility must render true sharp-edged cube: " + path)
                    return
                count += draw.multimesh.instance_count
        if count < (1 if is_nexus else 25):
            _fail("sharp facility / original NEXUS lacks real instanced geometry: " + path)
            return
    print("SERA_BASE_POLYGON_GEOMETRY_RUNTIME_PASS")
    quit(0)

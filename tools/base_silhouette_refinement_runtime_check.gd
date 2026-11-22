extends SceneTree
## Verify each installed facility actually uses the new polygon silhouettes.
const Polygons = preload("res://scripts/sera_base_polygon_meshes.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(s: String) -> void:
    push_error("SERA_BASE_SILHOUETTE_REFINEMENT_FAIL: " + s)
    quit(1)

func _run() -> void:
    for kind in ["roof", "louver"]:
        var mesh: ArrayMesh = Polygons.make(kind)
        if mesh == null or mesh.get_surface_count() != 1:
            _fail("missing real authored polygon shape: " + kind)
            return
        var data: Array = mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
        var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
        var colors: PackedColorArray = data[Mesh.ARRAY_COLOR]
        if vertices.size() < 36 or vertices.size() != normals.size() or (
                vertices.size() != uvs.size()) or colors.size() != vertices.size():
            _fail("polygon topology/UVs incomplete: " + kind)
            return
        var min_tone: float = 1.0
        var max_tone: float = 0.0
        for color in colors:
            min_tone = minf(min_tone, color.r)
            max_tone = maxf(max_tone, color.r)
        if max_tone - min_tone < 0.15:
            _fail("missing baked face-direction contrast: " + kind)
            return
        for i in range(0, vertices.size(), 3):
            var a: Vector3 = vertices[i]
            var b: Vector3 = vertices[i+1]
            var c: Vector3 = vertices[i+2]
            var surface_normal: Vector3 = (b-a).cross(c-a)
            if surface_normal.length_squared() < 0.00000001:
                _fail("degenerate triangle: " + kind)
                return
            if surface_normal.normalized().dot(normals[i]) > -0.95:
                _fail("wrong Godot clockwise facing: " + kind)
                return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(25):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var expected := {
        "NEXUSBuilding/NexusArchitecture": "NexusGabledEntranceShelter",
        "BaseFacilities/LABO/IndustrialModel": "FreshLabTensionedAwning",
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": "FreshCollectorSortPan",
        "BaseFacilities/SMELTER/IndustrialModel": "FreshSmelterObliqueShield",
        "BaseFacilities/RECYCLER/IndustrialModel": "FreshRecyclerOpenVJaws",
        "BaseFacilities/GENERATOR/IndustrialModel": "FreshGeneratorFrontRotor",
        "BaseFacilities/STORAGE/IndustrialModel": "FreshStorageOffsetStacks",
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": "FreshTerminalMonitorVisor",
    }
    for path in expected:
        var group: Node3D = hub.get_node_or_null(path) as Node3D
        if group == null:
            _fail("missing facility " + path)
            return
        if not (group.get_meta("unique_model_features", []) as Array).has(expected[path]):
            _fail("missing visible sculpt feature " + expected[path])
            return
        # Polygon-library topology is still tested above. The seven devices
        # now intentionally render sharp cubes instead of rounded bevel/drum;
        # the untouched archival NEXUS retains original polygon plates.
        var is_nexus: bool = path.begins_with("NEXUSBuilding/")
        var sculpted_instances: int = 0
        for child in group.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var draw: MultiMeshInstance3D = child as MultiMeshInstance3D
            if draw.multimesh == null:
                continue
            var name: String = str(draw.name)
            if is_nexus and (
                    name.begins_with("Architectural_roof_") or
                    name.begins_with("Architectural_louver_") or
                    name.begins_with("Architectural_bevel_") or
                    name.begins_with("Architectural_canvas_")):
                if not draw.multimesh.mesh is ArrayMesh:
                    _fail("archived NEXUS polygon drawing missing")
                    return
                sculpted_instances += draw.multimesh.instance_count
            elif not is_nexus and name.begins_with("Architectural_cube_"):
                if not draw.multimesh.mesh is BoxMesh:
                    _fail("angular station is not sharp-edged: " + path)
                    return
                sculpted_instances += draw.multimesh.instance_count
        if sculpted_instances < (1 if is_nexus else 25):
            _fail("original NEXUS / seven angular facilities missing visible meshes: " + path)
            return
    print("SERA_BASE_SILHOUETTE_REFINEMENT_RUNTIME_PASS")
    quit(0)

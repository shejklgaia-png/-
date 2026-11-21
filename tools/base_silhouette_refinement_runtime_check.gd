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
        if vertices.size() < 36 or vertices.size() != normals.size() or (
                vertices.size() != uvs.size()):
            _fail("polygon topology/UVs incomplete: " + kind)
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
        "BaseFacilities/LABO/IndustrialModel": "LabFabricCanopyRail",
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": "CollectorOpenGearHousing",
        "BaseFacilities/SMELTER/IndustrialModel": "FurnaceExhaustCowling",
        "BaseFacilities/RECYCLER/IndustrialModel": "CrusherLouveredDriveCase",
        "BaseFacilities/GENERATOR/IndustrialModel": "GeneratorFinnedVentFace",
        "BaseFacilities/STORAGE/IndustrialModel": "CargoShelterRoof",
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": "BlueprintShelteredMonitor",
    }
    for path in expected:
        var group: Node3D = hub.get_node_or_null(path) as Node3D
        if group == null:
            _fail("missing facility " + path)
            return
        if not (group.get_meta("unique_model_features", []) as Array).has(expected[path]):
            _fail("missing visible sculpt feature " + expected[path])
            return
        var sculpted_instances: int = 0
        for child in group.get_children():
            if child is MultiMeshInstance3D and (
                    child.name.begins_with("Architectural_roof_") or
                    child.name.begins_with("Architectural_louver_")):
                if not child.multimesh.mesh is ArrayMesh:
                    _fail("non-polygonal refinement in " + path)
                    return
                sculpted_instances += child.multimesh.instance_count
        if sculpted_instances < 1:
            _fail("no new polygon batches for " + path)
            return
    print("SERA_BASE_SILHOUETTE_REFINEMENT_RUNTIME_PASS")
    quit(0)

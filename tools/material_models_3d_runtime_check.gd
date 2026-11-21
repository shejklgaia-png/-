extends SceneTree
## SERA: verify all 12 resource models import as actual 3D mesh scenes.
const Materials = preload("res://scripts/sera_base_materials.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("SERA_MATERIAL_MODELS_3D_RUNTIME_FAIL: " + detail)
    quit(1)

func _run() -> void:
    var ids: Array = Materials.all_ids()
    if ids.size() != 12:
        _fail("catalog count must be 12")
        return
    for raw_id in ids:
        var id: String = str(raw_id)
        var path: String = "res://models/materials/" + id + ".gltf"
        if not ResourceLoader.exists(path):
            _fail("missing imported 3D resource " + path)
            return
        var pack: PackedScene = load(path) as PackedScene
        if pack == null:
            _fail("invalid glTF scene: " + id)
            return
        var model: Node = pack.instantiate()
        if model == null:
            _fail("could not instantiate: " + id)
            return
        var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
        if model is MeshInstance3D:
            meshes.append(model)
        var total_vertices: int = 0
        for child in meshes:
            var mesh: Mesh = (child as MeshInstance3D).mesh
            if mesh == null:
                continue
            for s in range(mesh.get_surface_count()):
                var arrays: Array = mesh.surface_get_arrays(s)
                var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                total_vertices += verts.size()
        model.free()
        if total_vertices < 60:
            _fail("model contains too little actual geometry: " + id)
            return
    print("SERA_MATERIAL_MODELS_3D_RUNTIME_PASS: 12 imported scenes")
    quit(0)

extends RefCounted
## Standalone 3D resource meshes. Do not replace or duplicate existing UI sprites.
## Avoid preloading all 12 scenes; load only when an actual 3D preview is visible.
const BaseMaterials = preload("res://scripts/sera_base_materials.gd")

static func path_for(material_id: String) -> String:
    if not BaseMaterials.MATERIAL_NAMES.has(material_id):
        return ""
    return "res://models/materials/" + material_id + ".gltf"

static func scene_for(material_id: String) -> PackedScene:
    var path: String = path_for(material_id)
    if path.is_empty():
        return null
    return ResourceLoader.load(path, "PackedScene") as PackedScene

static func instantiate(material_id: String) -> Node3D:
    var scene: PackedScene = scene_for(material_id)
    if scene == null:
        return null
    var instance: Node = scene.instantiate()
    if instance is Node3D:
        return instance as Node3D
    instance.free()
    return null

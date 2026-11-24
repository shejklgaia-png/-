extends RefCounted
## Versioned local binary bake cache. Only explicitly selected render-only roots
## are packed; runtime scripts, signal connections, moving machines and IDs
## are always constructed by their original owners.
const CACHE_DIR := "user://sera_static_bake_v1"
static var _source_hashes: Dictionary = {}

static func _source_hash(path: String) -> String:
    if _source_hashes.has(path):
        return str(_source_hashes[path])
    var digest := ""
    if FileAccess.file_exists(path):
        digest = FileAccess.get_sha256(path)
    else:
        # Exported Android projects may remap script/texture source to PCK data.
        for suffix in [".remap", ".import"]:
            var cfg := ConfigFile.new()
            if cfg.load(path + suffix) != OK:
                continue
            var values: Array = []
            if not cfg.has_section("remap"):
                continue
            for k in cfg.get_section_keys("remap"):
                if k == "path" or k.begins_with("path."):
                    var mapped: String = str(cfg.get_value("remap", k, ""))
                    if FileAccess.file_exists(mapped):
                        var item := FileAccess.get_sha256(mapped)
                        if not item.is_empty():
                            values.append(k + ":" + item)
            if not values.is_empty():
                digest = str(values).sha256_text()
                break
    _source_hashes[path] = digest
    return digest

static func cache_path(slot: String, dependencies: Array, parameters: Variant = null, extension: String = ".scn") -> String:
    # Dummy/headless rendering cannot guarantee serialized MultiMesh buffers.
    if DisplayServer.get_name() == "headless":
        return ""
    var identity: Array = [1, Engine.get_version_info(), ProjectSettings.get_setting("application/config/name", ""), parameters]
    var sources := dependencies.duplicate()
    sources.append("res://scripts/sera_static_bake.gd")
    for raw in sources:
        var path: String = str(raw)
        var digest := _source_hash(path)
        if digest.is_empty():
            return "" # Never use a stale bake when an input cannot be verified.
        identity.append([path, digest])
    var hashing := HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    hashing.update(var_to_bytes(identity))
    var key := hashing.finish().hex_encode()
    return CACHE_DIR.path_join(slot + "_" + key + extension)

static func _render_only(node: Node) -> bool:
    if node.get_script() != null or not node is Node3D:
        return false
    if not (node.get_class() in ["Node3D", "MeshInstance3D", "MultiMeshInstance3D", "Label3D"]):
        return false
    if node is MultiMeshInstance3D:
        var multi: MultiMesh = node.multimesh
        if multi == null or multi.mesh == null or multi.instance_count <= 0:
            return false
    for child in node.get_children():
        if not _render_only(child):
            return false
    return true

static func _buffers_present(node: Node) -> bool:
    if node is MultiMeshInstance3D:
        var multi: MultiMesh = node.multimesh
        var stride: int = 12 + (4 if multi.use_colors else 0) + (4 if multi.use_custom_data else 0)
        if multi.buffer.size() != multi.instance_count * stride:
            return false
    for child in node.get_children():
        if not _buffers_present(child):
            return false
    return true

static func load_scene(path: String, expected_name: String) -> Node3D:
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    # Fresh scene/subresources per owner, not a mutable shared instance.
    var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
    if scene == null or not scene.can_instantiate():
        return null
    var node := scene.instantiate() as Node3D
    if node == null:
        return null
    if String(node.name) != expected_name or node.get_child_count() == 0 or not _render_only(node):
        node.free()
        return null
    print("SERA_BAKE HIT: ", expected_name)
    return node

static func _assign_owners(node: Node, root: Node, old: Dictionary) -> void:
    for child in node.get_children():
        old[child] = child.owner
        child.owner = root
        _assign_owners(child, root, old)

static func _prepare_dir(path: String) -> bool:
    return not path.is_empty() and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR)) == OK

static func _publish(temp: String, path: String) -> bool:
    var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
    if result != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
        return false
    # Only retain the current revision for this exact slot. Slot names have
    # no underscores other than the single separator before the digest.
    var prefix: String = path.get_file().get_slice("_", 0) + "_"
    for filename in DirAccess.get_files_at(CACHE_DIR):
        if filename.begins_with(prefix) and filename != path.get_file():
            DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_DIR.path_join(filename)))
    return true

static func save_scene(path: String, root: Node3D) -> void:
    if path.is_empty() or not _render_only(root) or not _buffers_present(root) or not _prepare_dir(path):
        return
    var old: Dictionary = {}
    _assign_owners(root, root, old)
    var packed := PackedScene.new()
    var result := packed.pack(root)
    for child in old:
        child.owner = old[child]
    if result != OK:
        return
    var temp := path.get_basename() + ".tmp.scn"
    if ResourceSaver.save(packed, temp) == OK and _publish(temp, path):
        print("SERA_BAKE SAVED: ", root.name)

static func load_mesh(path: String) -> ArrayMesh:
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    var mesh := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
    return mesh if mesh != null and mesh.get_surface_count() > 0 else null

static func save_mesh(path: String, mesh: ArrayMesh) -> void:
    if mesh == null or mesh.get_surface_count() == 0 or not _prepare_dir(path):
        return
    var temp := path.get_basename() + ".tmp.res"
    if ResourceSaver.save(mesh, temp) == OK:
        _publish(temp, path)

static func load_data(path: String) -> Variant:
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    return file.get_var(false) if file != null else null

static func save_data(path: String, data: Variant) -> void:
    if not _prepare_dir(path):
        return
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return
    file.store_var(data, false)
    file.flush()
    var ok: bool = file.get_error() == OK
    file.close()
    if ok:
        _publish(temp, path)

## Bulk upload only for pure transform buffers (no color/custom ID).
## The existing per-instance path is retained for animated ID-role batches.
static func fill_static_transforms(multi: MultiMesh, poses: Array) -> void:
    if poses.is_empty():
        return
    if multi.use_colors or multi.use_custom_data or multi.transform_format != MultiMesh.TRANSFORM_3D:
        for i in range(poses.size()):
            multi.set_instance_transform(i, poses[i])
        return
    var buffer := PackedFloat32Array()
    buffer.resize(poses.size() * 12)
    for i in range(poses.size()):
        var pose: Transform3D = poses[i]
        var at: int = i * 12
        buffer[at] = pose.basis.x.x
        buffer[at+1] = pose.basis.y.x
        buffer[at+2] = pose.basis.z.x
        buffer[at+3] = pose.origin.x
        buffer[at+4] = pose.basis.x.y
        buffer[at+5] = pose.basis.y.y
        buffer[at+6] = pose.basis.z.y
        buffer[at+7] = pose.origin.y
        buffer[at+8] = pose.basis.x.z
        buffer[at+9] = pose.basis.y.z
        buffer[at+10] = pose.basis.z.z
        buffer[at+11] = pose.origin.z
    multi.buffer = buffer

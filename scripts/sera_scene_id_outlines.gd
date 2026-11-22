extends Control
## One shared visible-mesh-ID outline compositor PER rendering Viewport.
## Reuses the HEAD D idea: depth-tested colored IDs + a 3px canvas mask.
## No source mesh, material, hitbox, authored motion or render texture changes.
const ID_FRONT = preload("res://shaders/sera_scene_mesh_id_front.gdshader")
const ID_BACK = preload("res://shaders/sera_scene_mesh_id_back.gdshader")
const ID_DOUBLE = preload("res://shaders/sera_scene_mesh_id_double.gdshader")
const MULTI_ID_FRONT = preload("res://shaders/sera_scene_multimesh_id_front.gdshader")
const MULTI_ID_BACK = preload("res://shaders/sera_scene_multimesh_id_back.gdshader")
const MULTI_ID_DOUBLE = preload("res://shaders/sera_scene_multimesh_id_double.gdshader")
const INK = preload("res://shaders/sera_scene_mesh_id_outline.gdshader")
const MAX_IDENTIFIED_MESHES: int = 4095
const MAX_TARGET_PIXELS: int = 921600 # 720 x 1280; avoid high-res Android spikes.
const SCAN_INTERVAL: float = 0.65

var source_viewport: Viewport
var id_viewport: SubViewport
var id_camera: Camera3D
var ink: TextureRect
var _root_refs: Dictionary = {} # owner id -> WeakRef to scene/actor root
var _copies: Dictionary = {} # source instance id -> ID MeshInstance/MultiMeshInstance
var _source_refs: Dictionary = {}
var _next_id: int = 1
var _id_allocations: Dictionary = {} # source id -> {first, count}
var _free_ranges: Array[Dictionary] = []
var _scan_elapsed: float = 0.0
var _last_camera: Transform3D = Transform3D.IDENTITY
var _last_camera_fov: float = -1.0
var _last_camera_size: float = -1.0
var _last_camera_projection: int = -1
var _last_camera_near: float = -1.0
var _last_camera_far: float = -1.0
var _last_camera_aspect: int = -1
var _last_camera_mask: int = -1
var _ink_stroke: float = 3.0
var _target_scale: float = 1.0


func _ready() -> void:
    name = "SeraIDOutlineControl"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    source_viewport = get_viewport()
    id_viewport = SubViewport.new()
    id_viewport.name = "SeraVisibleIDs"
    id_viewport.size = Vector2i(384, 384)
    id_viewport.own_world_3d = true
    id_viewport.msaa_3d = Viewport.MSAA_DISABLED
    id_viewport.transparent_bg = false
    id_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(id_viewport)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color.BLACK
    var world := WorldEnvironment.new()
    world.environment = environment
    id_viewport.add_child(world)
    id_camera = Camera3D.new()
    id_camera.name = "SeraIDCamera"
    id_viewport.add_child(id_camera)
    id_camera.current = true
    ink = TextureRect.new()
    ink.name = "SeraVisibleMeshIDInk"
    ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ink.stretch_mode = TextureRect.STRETCH_SCALE
    ink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # A shader failure MUST NOT expose the colored debug IDs.
    var safe := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    safe.fill(Color.TRANSPARENT)
    ink.texture = ImageTexture.create_from_image(safe)
    var material := ShaderMaterial.new()
    material.shader = INK
    material.set_shader_parameter("mesh_id_texture", id_viewport.get_texture())
    material.set_shader_parameter("mesh_id_texel", Vector2(1.0 / 384.0, 1.0 / 384.0))
    material.set_shader_parameter("ink_color", Color("#17212f"))
    material.set_shader_parameter("stroke_px", _ink_stroke)
    ink.material = material
    add_child(ink)
    process_priority = 1000
    set_process(false)
    visible = false


func register_root(root: Node3D, owner: Node) -> void:
    if not is_instance_valid(root) or not is_instance_valid(owner):
        return
    _root_refs[owner.get_instance_id()] = weakref(root)
    _scan_elapsed = 0.0
    visible = true
    set_process(true)


func unregister_root(owner: Node) -> void:
    if is_instance_valid(owner):
        _root_refs.erase(owner.get_instance_id())
    if _root_refs.is_empty():
        _clear_copies()
        id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        visible = false
        set_process(false)


func set_stroke_px(px: float) -> void:
    _ink_stroke = clampf(px, 1.0, 3.0)
    if is_instance_valid(ink):
        (ink.material as ShaderMaterial).set_shader_parameter("stroke_px", _ink_stroke)


func _process(delta: float) -> void:
    if _root_refs.is_empty() or not is_instance_valid(source_viewport):
        return
    var source_camera: Camera3D = source_viewport.get_camera_3d()
    if not is_instance_valid(source_camera):
        ink.visible = false
        return
    ink.visible = true
    var dirty: bool = _sync_camera(source_camera)
    _scan_elapsed -= delta
    if _scan_elapsed <= 0.0:
        _scan_elapsed = SCAN_INTERVAL
        dirty = _rescan() or dirty
    dirty = _sync_copies() or dirty
    if dirty:
        id_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _sync_camera(source_camera: Camera3D) -> bool:
    var target_size: Vector2 = source_viewport.get_visible_rect().size
    if target_size.x < 32.0 or target_size.y < 32.0:
        return false
    # Keep one ID target per rendering viewport, rather than one per actor.
    var scale: float = minf(1.0, sqrt(
        float(MAX_TARGET_PIXELS) / maxf(1.0, target_size.x * target_size.y)))
    var desired := Vector2i(maxi(32, roundi(target_size.x * scale)),
        maxi(32, roundi(target_size.y * scale)))
    var dirty: bool = false
    if id_viewport.size != desired:
        id_viewport.size = desired
        _target_scale = scale
        (ink.material as ShaderMaterial).set_shader_parameter("mesh_id_texel",
            Vector2(1.0 / float(desired.x), 1.0 / float(desired.y)))
        (ink.material as ShaderMaterial).set_shader_parameter("stroke_px",
            minf(3.0, _ink_stroke * scale))
        dirty = true
    if _last_camera != source_camera.global_transform or (
            _last_camera_fov != source_camera.fov) or (
            _last_camera_size != source_camera.size) or (
            _last_camera_projection != source_camera.projection) or (
            _last_camera_near != source_camera.near) or (
            _last_camera_far != source_camera.far) or (
            _last_camera_aspect != source_camera.keep_aspect) or (
            _last_camera_mask != source_camera.cull_mask):
        _last_camera = source_camera.global_transform
        _last_camera_fov = source_camera.fov
        _last_camera_size = source_camera.size
        _last_camera_projection = source_camera.projection
        _last_camera_near = source_camera.near
        _last_camera_far = source_camera.far
        _last_camera_aspect = source_camera.keep_aspect
        _last_camera_mask = source_camera.cull_mask
        id_camera.projection = source_camera.projection
        id_camera.fov = source_camera.fov
        id_camera.size = source_camera.size
        id_camera.near = source_camera.near
        id_camera.far = source_camera.far
        id_camera.keep_aspect = source_camera.keep_aspect
        id_camera.cull_mask = source_camera.cull_mask
        id_camera.global_transform = source_camera.global_transform
        dirty = true
    return dirty


static func _is_visual_part(node: Node) -> bool:
    var cursor: Node = node
    while cursor != null:
        if bool(cursor.get_meta("sera_no_view_edges", false)) or (
                bool(cursor.get_meta("FX_NO_OUTLINE", false))):
            return false
        var label: String = str(cursor.name).to_lower()
        for blocked in ["viewedges", "seraedgeink", "afterimage", "ghost",
                "projectile", "laser", "beam", "trail", "slash", "spark",
                "smoke", "flame", "glow", "flash", "shockwave", "particle",
                "exhaust", "effect", "radiance", "debris", "blast",
                "gridplate", "floor", "backdrop", "sky", "ground",
                "collision", "trigger", "debug"]:
            if label.contains(blocked):
                return false
        cursor = cursor.get_parent()
    return true


static func _solid_material(part: GeometryInstance3D) -> bool:
    var material: Material = part.material_override
    if material is BaseMaterial3D:
        var solid: BaseMaterial3D = material as BaseMaterial3D
        return solid.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and (
            solid.blend_mode != BaseMaterial3D.BLEND_MODE_ADD) and (
            not solid.no_depth_test) and solid.albedo_color.a >= 0.999
    if material is ShaderMaterial:
        var shader: Shader = (material as ShaderMaterial).shader
        if shader == null:
            return false
        var code: String = shader.code
        return not (code.contains("ALPHA") or code.contains("blend_add") or (
            code.contains("depth_test_disabled")))
    return material == null


static func _eligible(node: Node3D) -> bool:
    if not _is_visual_part(node):
        return false
    if node is MeshInstance3D:
        var mesh: MeshInstance3D = node as MeshInstance3D
        return mesh.mesh != null and not mesh.mesh is QuadMesh and (
            not mesh.mesh is PlaneMesh) and _solid_material(mesh)
    if node is MultiMeshInstance3D:
        var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
        return batch.multimesh != null and batch.multimesh.mesh != null and (
            _solid_material(batch))
    return false


static func _background_occluder(node: Node3D) -> bool:
    # Floor and ground should occlude IDs behind them, but should NOT have
    # a thick black border. They receive ID=0 (same as background).
    if not node is MeshInstance3D and not node is MultiMeshInstance3D:
        return false
    if not _solid_material(node as GeometryInstance3D):
        return false
    var cursor: Node = node
    while cursor != null:
        var label: String = str(cursor.name).to_lower()
        for blocked in ["particle", "smoke", "flame", "glow", "flash",
                "laser", "beam", "trail", "effect", "projectile"]:
            if label.contains(blocked):
                return false
        for background in ["gridplate", "backdrop", "ground", "floor"]:
            if label.contains(background):
                return true
        cursor = cursor.get_parent()
    return false


func _allocate_ids(count: int) -> int:
    # Reuse freed contiguous blocks on layout regeneration/equipment changes.
    # Otherwise 4095 can be exhausted even when only a few meshes are alive.
    for i in range(_free_ranges.size()):
        var block: Dictionary = _free_ranges[i]
        if int(block["count"]) < count:
            continue
        var first: int = int(block["first"])
        if int(block["count"]) == count:
            _free_ranges.remove_at(i)
        else:
            block["first"] = first + count
            block["count"] = int(block["count"]) - count
            _free_ranges[i] = block
        return first
    if _next_id + count - 1 > MAX_IDENTIFIED_MESHES:
        return -1
    var first_new: int = _next_id
    _next_id += count
    return first_new


func _release_ids(record: Dictionary) -> void:
    if record.is_empty():
        return
    var released: Dictionary = {
        "first": int(record["first"]), "count": int(record["count"])
    }
    if int(released["count"]) > 0:
        _free_ranges.append(released)
    _free_ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a["first"]) < int(b["first"]))
    var packed: Array[Dictionary] = []
    for block in _free_ranges:
        if not packed.is_empty() and int(packed.back()["first"]) + (
                int(packed.back()["count"])) == int(block["first"]):
            var last: Dictionary = packed.pop_back()
            last["count"] = int(last["count"]) + int(block["count"])
            packed.append(last)
        else:
            packed.append(block)
    _free_ranges = packed


func _rescan() -> bool:
    var desired: Dictionary = {}
    var expired: Array[int] = []
    for owner_id in _root_refs.keys():
        var ref: WeakRef = _root_refs[owner_id]
        var root: Node3D = ref.get_ref() as Node3D
        if not is_instance_valid(root) or not root.is_inside_tree():
            expired.append(owner_id)
            continue
        var pending: Array[Node] = [root]
        while not pending.is_empty():
            var node: Node = pending.pop_back()
            if node is Node3D:
                var part: Node3D = node as Node3D
                var eligible: bool = _eligible(part)
                var occluding: bool = not eligible and _background_occluder(part)
                if eligible or occluding:
                    desired[node.get_instance_id()] = {
                        "node": part, "occluder": occluding
                    }
            for child in node.get_children():
                if child is Node3D and child.name != "ViewEdges" and (
                        child.name != "SeraEdgeInk"):
                    pending.append(child)
    for key in expired:
        _root_refs.erase(key)
    var dirty: bool = false
    for key in _copies.keys():
        if desired.has(key):
            continue
        var old: Node3D = _copies[key] as Node3D
        if is_instance_valid(old):
            old.queue_free()
        _copies.erase(key)
        _source_refs.erase(key)
        if _id_allocations.has(key):
            _release_ids(_id_allocations[key])
            _id_allocations.erase(key)
        dirty = true
    for key in desired.keys():
        if _copies.has(key):
            continue
        var entry: Dictionary = desired[key]
        var is_occluder: bool = bool(entry["occluder"])
        var source: Node3D = entry["node"] as Node3D
        var instance_count: int = 1
        if source is MultiMeshInstance3D:
            var mesh_batch: MultiMesh = (source as MultiMeshInstance3D).multimesh
            instance_count = mesh_batch.instance_count if mesh_batch != null else 1
        # For combined geometry, unique ID per instance preserves seams.
        # If the 4095-ID budget is exceeded, keep the batch's one draw call
        # with one ID instead of dropping the geometry.
        var per_instance_id: bool = false
        var identification: int = 0
        var allocation_count: int = 0
        if not is_occluder:
            allocation_count = instance_count if instance_count > 1 else 1
            identification = _allocate_ids(allocation_count)
            if identification >= 0:
                per_instance_id = instance_count > 1
            else:
                allocation_count = 1
                identification = _allocate_ids(1)
                if identification < 0:
                    continue
        var clone: GeometryInstance3D = null
        if source is MeshInstance3D:
            var mesh_copy := MeshInstance3D.new()
            mesh_copy.mesh = (source as MeshInstance3D).mesh
            clone = mesh_copy
        elif source is MultiMeshInstance3D:
            var batch_copy := MultiMeshInstance3D.new()
            batch_copy.multimesh = (source as MultiMeshInstance3D).multimesh
            clone = batch_copy
        if clone == null:
            if allocation_count > 0:
                _release_ids({"first": identification, "count": allocation_count})
            continue
        if allocation_count > 0:
            _id_allocations[key] = {
                "first": identification, "count": allocation_count
            }
        # RGB444 IDs permit many equipment pieces while keeping per-channel
        # jumps robust at nearest-neighbor sample resolution.
        var color_id := Vector3(float((identification >> 8) & 15) / 15.0,
            float((identification >> 4) & 15) / 15.0,
            float(identification & 15) / 15.0)
        var original: GeometryInstance3D = source as GeometryInstance3D
        var hint: bool = bool(original.get_meta("sera_single_sided", false))
        var native: Material = original.material_override
        var mat := ShaderMaterial.new()
        var shader: Shader = ID_DOUBLE
        if hint:
            shader = ID_FRONT
        elif native is BaseMaterial3D:
            var culling: int = (native as BaseMaterial3D).cull_mode
            if culling == BaseMaterial3D.CULL_FRONT:
                shader = ID_FRONT
            elif culling == BaseMaterial3D.CULL_BACK:
                shader = ID_BACK
        if per_instance_id:
            if shader == ID_FRONT:
                shader = MULTI_ID_FRONT
            elif shader == ID_BACK:
                shader = MULTI_ID_BACK
            else:
                shader = MULTI_ID_DOUBLE
        mat.shader = shader
        if per_instance_id:
            mat.set_shader_parameter("mesh_id_base", identification)
        else:
            mat.set_shader_parameter("mesh_id_rgb", color_id)
        clone.material_override = mat
        clone.name = "VisibleID_%d" % identification
        clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        clone.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        clone.layers = original.layers
        id_viewport.add_child(clone)
        _copies[key] = clone
        _source_refs[key] = weakref(source)
        dirty = true
    return dirty


func _sync_copies() -> bool:
    var dirty: bool = false
    for key in _copies.keys():
        var ref: WeakRef = _source_refs.get(key) as WeakRef
        var source: Node3D = (ref.get_ref() as Node3D if ref != null else null)
        if not is_instance_valid(source):
            continue
        var clone: Node3D = _copies[key] as Node3D
        if not is_instance_valid(clone):
            continue
        var show_id: bool = source.is_visible_in_tree()
        if clone.visible != show_id:
            clone.visible = show_id
            dirty = true
        if clone.global_transform != source.global_transform:
            clone.global_transform = source.global_transform
            dirty = true
        if source is MeshInstance3D and clone is MeshInstance3D:
            if (clone as MeshInstance3D).mesh != (source as MeshInstance3D).mesh:
                (clone as MeshInstance3D).mesh = (source as MeshInstance3D).mesh
                dirty = true
        elif source is MultiMeshInstance3D and clone is MultiMeshInstance3D:
            if (clone as MultiMeshInstance3D).multimesh != (
                    source as MultiMeshInstance3D).multimesh:
                (clone as MultiMeshInstance3D).multimesh = (
                    source as MultiMeshInstance3D).multimesh
                dirty = true
    return dirty


func _clear_copies() -> void:
    for clone in _copies.values():
        if is_instance_valid(clone):
            (clone as Node).queue_free()
    _copies.clear()
    _source_refs.clear()
    _id_allocations.clear()
    _free_ranges.clear()
    _next_id = 1

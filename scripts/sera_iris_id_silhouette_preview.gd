extends Control
## NEXUS-only HEAD D ID-buffer outline experiment.
## The normal preview's real 3D scene, palette, and equipment meshes are
## unchanged. A second 384-ish px SubViewport draws exactly six mesh IDs with
## their normal depth relationships and a CanvasItem shader finds visible
## per-mesh boundaries. Other screens and combat keep the existing renderer.
const ID_CLOSED = preload("res://shaders/sera_iris_mesh_id_closed.gdshader")
const ID_OPEN = preload("res://shaders/sera_iris_mesh_id_open.gdshader")
const INK = preload("res://shaders/sera_iris_mesh_id_outline.gdshader")

var source_preview: Node3D
var source_viewport: SubViewport
var id_viewport: SubViewport
var id_camera: Camera3D
var ink_rect: TextureRect
var _enabled: bool = false
var _copies: Dictionary = {}  # source_instance_id -> MeshInstance3D
var _source_refs: Dictionary = {}
var _original_ink_visibility: Dictionary = {}

func _ready() -> void:
    name = "NexusIrisVisibleMeshContour"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    clip_contents = true
    id_viewport = SubViewport.new()
    id_viewport.name = "IrisIDDepthViewport"
    id_viewport.size = Vector2i(384, 384)
    id_viewport.own_world_3d = true
    id_viewport.transparent_bg = false
    id_viewport.msaa_3d = Viewport.MSAA_DISABLED
    id_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(id_viewport)

    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color.BLACK
    var world_env := WorldEnvironment.new()
    world_env.environment = environment
    id_viewport.add_child(world_env)

    id_camera = Camera3D.new()
    id_camera.name = "IrisDepthIDCamera"
    id_viewport.add_child(id_camera)
    id_camera.current = true
    ink_rect = TextureRect.new()
    ink_rect.name = "IrisVisibleBoundary3px"
    ink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ink_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ink_rect.stretch_mode = TextureRect.STRETCH_SCALE
    ink_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ink_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
    ink_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ink_rect.texture = id_viewport.get_texture()
    var material := ShaderMaterial.new()
    material.shader = INK
    material.set_shader_parameter("ink_color", Color("#17212f"))
    material.set_shader_parameter("stroke_px", 3.0)
    ink_rect.material = material
    add_child(ink_rect)
    set_process(false)
    hide()

func set_active(enabled: bool, preview: Node3D = null,
        viewport: SubViewport = null) -> void:
    if enabled and (not is_instance_valid(preview) or not is_instance_valid(viewport)):
        enabled = false
    if not enabled:
        _enabled = false
        set_process(false)
        visible = false
        if id_viewport != null:
            id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        _restore_original_ink()
        _clear_copies()
        source_preview = null
        source_viewport = null
        return
    source_preview = preview
    source_viewport = viewport
    _enabled = true
    visible = true
    id_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    set_process(true)
    _sync_id_pass()

func _process(_delta: float) -> void:
    if not _enabled or not is_instance_valid(source_preview) or (
            not is_instance_valid(source_viewport)):
        set_active(false)
        return
    _sync_id_pass()

func _sync_id_pass() -> void:
    if not bool(source_preview.get("ready_for_commands")) or (
            str(source_preview.get("editing_slot")) != "head") or (
            str(source_preview.get("view_mode")) != "icon"):
        _clear_copies()
        return
    var new_size: Vector2i = source_viewport.size
    if new_size.x < 32 or new_size.y < 32:
        return
    if id_viewport.size != new_size:
        id_viewport.size = new_size
    var src_camera: Camera3D = source_preview.get("camera") as Camera3D
    if not is_instance_valid(src_camera):
        return
    id_camera.projection = src_camera.projection
    id_camera.size = src_camera.size
    id_camera.fov = src_camera.fov
    id_camera.near = src_camera.near
    id_camera.far = src_camera.far
    id_camera.keep_aspect = src_camera.keep_aspect
    id_camera.global_transform = src_camera.global_transform

    var sources: Array = source_preview.call("_mesh_in_slot", "head", "D")
    var wanted: Dictionary = {}
    # Stable ID per source element: six independently depth-tested pieces.
    for index in range(sources.size()):
        var source: MeshInstance3D = sources[index] as MeshInstance3D
        if not is_instance_valid(source) or source.mesh == null:
            continue
        var key: int = source.get_instance_id()
        wanted[key] = true
        var clone: MeshInstance3D = _copies.get(key) as MeshInstance3D
        if not is_instance_valid(clone):
            clone = MeshInstance3D.new()
            clone.name = "DepthID_%d" % index
            clone.mesh = source.mesh # Shared vertex data; NOT duplicated.
            var mat := ShaderMaterial.new()
            mat.shader = ID_CLOSED if bool(source.get_meta(
                "sera_single_sided", false)) else ID_OPEN
            mat.set_shader_parameter("mesh_id", float(index + 1) / 8.0)
            clone.material_override = mat
            clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            clone.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            id_viewport.add_child(clone)
            _copies[key] = clone
            _source_refs[key] = source
        # Source is in a separate World3D. Global transforms share the same
        # coordinate system because both viewport roots have identity transform.
        clone.global_transform = source.global_transform
        clone.visible = source.visible and source.is_visible_in_tree()
        var legacy_ink: MeshInstance3D = source.get_node_or_null(
            "SeraEdgeInk") as MeshInstance3D
        if is_instance_valid(legacy_ink):
            var ink_key: int = legacy_ink.get_instance_id()
            if not _original_ink_visibility.has(ink_key):
                _original_ink_visibility[ink_key] = {
                    "node": legacy_ink, "was_visible": legacy_ink.visible}
            legacy_ink.visible = false
    for key in _copies.keys():
        if wanted.has(key):
            continue
        var previous: MeshInstance3D = _copies[key] as MeshInstance3D
        if is_instance_valid(previous):
            previous.queue_free()
        _copies.erase(key)
        _source_refs.erase(key)

func _restore_original_ink() -> void:
    for old in _original_ink_visibility.values():
        var node: MeshInstance3D = old["node"] as MeshInstance3D
        if is_instance_valid(node):
            node.visible = bool(old["was_visible"])
    _original_ink_visibility.clear()

func _clear_copies() -> void:
    for copy in _copies.values():
        if is_instance_valid(copy):
            copy.queue_free()
    _copies.clear()
    _source_refs.clear()

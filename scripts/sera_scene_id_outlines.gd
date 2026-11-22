extends Control
## One shared visible-mesh-ID outline compositor PER rendering Viewport.
## All 3D scenes use one per-viewport RGB visible-ID pass with 3D ink before
## foreground VFX. One shared ID viewport, no CPU pixel reads or source edits.
# Reuse the proven IRIS resources, with no reimplementation of their code.
const ID_CLOSED = preload("res://shaders/sera_iris_mesh_id_closed.gdshader")
const ID_OPEN = preload("res://shaders/sera_iris_mesh_id_open.gdshader")
const MULTI_ID_CLOSED = preload("res://shaders/sera_scene_multimesh_iris_id_closed.gdshader")
const MULTI_ID_OPEN = preload("res://shaders/sera_scene_multimesh_iris_id_open.gdshader")
const INK = preload("res://shaders/sera_iris_mesh_id_outline.gdshader")
const NEXUS_CONTACT_INK = preload("res://shaders/sera_nexus_mesh_contact_ink.gdshader")
const NEXUS_CONTACT_CLOSED = preload("res://shaders/sera_nexus_mesh_contact_closed.gdshader")
const NEXUS_CONTACT_OPEN = preload("res://shaders/sera_nexus_mesh_contact_open.gdshader")
const SHARED_INK = preload("res://shaders/sera_scene_visible_ink_3d.gdshader")
const SHARED_ID_CLOSED = preload("res://shaders/sera_scene_visible_id_closed.gdshader")
const SHARED_ID_OPEN = preload("res://shaders/sera_scene_visible_id_open.gdshader")
const SHARED_MULTI_CLOSED = preload("res://shaders/sera_scene_visible_id_multi_closed.gdshader")
const SHARED_MULTI_OPEN = preload("res://shaders/sera_scene_visible_id_multi_open.gdshader")
# The IRIS shader compares red IDs spaced by 1/8. In one pass it
# distinguishes up to seven values; larger scenes necessarily reuse them.
const IRIS_PALETTE_COUNT: int = 7
# RGB channels quantized to 1/8, keeping 343 distinct visible SERA meshes
# without changing the architecture's working red-only IRIS palette.
const NEXUS_CONTACT_PALETTE_COUNT: int = 343
const MAX_IDENTIFIED_MESHES: int = 4095
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
var _redraw_requests: int = 0
var _nexus_sera_contact_mode: bool = false
var _contact_ids: Dictionary = {}
var _free_contact_ids: Array[int] = []
var _next_contact_id: int = 1
var _shared_scene_mode: bool = false
var _screen_quad: MeshInstance3D
var _screen_material: ShaderMaterial
var _screen_camera: Camera3D
var _styled_sources: Dictionary = {} # Visible IDs, excludes background depth masks.
var _pose_stamps: Dictionary = {}


func get_outline_metrics() -> Dictionary:
    # Runtime inspection only; does not invoke tests or read GPU pixels.
    return {
        "roots": _root_refs.size(),
        "source_viewport_size": size,
        "id_target_size": id_viewport.size if is_instance_valid(id_viewport) else Vector2i.ZERO,
        "id_copies": _copies.size(),
        "source_camera": is_instance_valid(source_viewport) and (
            is_instance_valid(source_viewport.get_camera_3d())),
        "overlay_visible": visible and (
            (is_instance_valid(_screen_quad) and _screen_quad.visible)
            if _shared_scene_mode else (
            is_instance_valid(ink) and ink.visible)),
        "ink_rect_size": ink.size if is_instance_valid(ink) else Vector2.ZERO,
        "ink_shader_bound": (is_instance_valid(_screen_quad) and
            _screen_material != null and
            _screen_material.shader == SHARED_INK) if _shared_scene_mode else (
            is_instance_valid(ink) and ink.material is ShaderMaterial and
            (ink.material as ShaderMaterial).shader == (
                NEXUS_CONTACT_INK if _nexus_sera_contact_mode else INK)),
        "shared_vfx_safe_3d_ink": _shared_scene_mode,
        "nexus_contact_vfx_safe_3d_ink": false,
        "front_effects_cover_ink": _shared_scene_mode,
        "ink_draw_source": "spatial_before_vfx" if _shared_scene_mode
            else "canvas",
        "id_encoding": "ROLE_GREEN_AND_RGB12" if _shared_scene_mode else (
            "NEXUS_RGB_7x7x7" if _nexus_sera_contact_mode else
            "IRIS_RED_1_OF_7"),
        "palette_collision_possible": _id_allocations.size() > (
            MAX_IDENTIFIED_MESHES if _shared_scene_mode else (
            NEXUS_CONTACT_PALETTE_COUNT if _nexus_sera_contact_mode
            else IRIS_PALETTE_COUNT)),
        "canvas_layer": (get_parent() as CanvasLayer).layer if (
            get_parent() is CanvasLayer) else -1,
        "redraw_requests": _redraw_requests
    }


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
    # Fail closed when the shared canvas shader cannot draw on a device.
    # A WHITE ColorRect covered both BASE and NEXUS in Android: never use
    # opaque fallback pixels in the viewport-wide shared compositor.
    # Preserve HEAD D's safe source texture instead of raw ID colors.
    ink = TextureRect.new()
    ink.name = "SeraVisibleMeshIDInk"
    ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ink.stretch_mode = TextureRect.STRETCH_SCALE
    ink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ink.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
    ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var safe_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    safe_image.fill(Color.TRANSPARENT)
    ink.texture = ImageTexture.create_from_image(safe_image)
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


func _exit_tree() -> void:
    # The 3D quad lives under the source Camera3D, not under this canvas.
    if is_instance_valid(_screen_quad):
        _screen_quad.queue_free()


# Transparent-3D ink precedes smoke/glow/slash effects in render_priority,
# whereas the old CanvasLayer ink always painted OVER those effects.
func set_shared_scene_mode(enabled: bool) -> void:
    # NEXUS full-body specifically requires the pre-existing RGB contact
    # Canvas shader; do not overwrite it when another root registers.
    if enabled and _nexus_sera_contact_mode:
        return
    if _shared_scene_mode == enabled:
        return
    _shared_scene_mode = enabled
    if enabled:
        _screen_material = ShaderMaterial.new()
        _screen_material.shader = SHARED_INK
        _screen_material.render_priority = -30
        _screen_material.set_shader_parameter(
            "mesh_id_texture", id_viewport.get_texture())
        _screen_material.set_shader_parameter("mesh_id_texel", Vector2(
            1.0 / float(id_viewport.size.x),
            1.0 / float(id_viewport.size.y)))
        _screen_material.set_shader_parameter(
            "ink_color", Color("#17212f"))
        _screen_material.set_shader_parameter(
            "ink_screen_bounds", Vector4.ZERO)
        ink.visible = false
    elif is_instance_valid(_screen_quad):
        _screen_quad.visible = false
    _clear_copies()
    _scan_elapsed = 0.0


func _sync_screen_quad(camera: Camera3D) -> void:
    if not _shared_scene_mode or not is_instance_valid(camera):
        return
    if _screen_material == null:
        return
    if not is_instance_valid(_screen_quad):
        _screen_quad = MeshInstance3D.new()
        _screen_quad.name = "SeraVisibleInkBeforeVFX"
        _screen_quad.mesh = QuadMesh.new()
        _screen_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _screen_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        _screen_quad.extra_cull_margin = 100.0
        _screen_quad.material_override = _screen_material
        _screen_quad.set_meta("FX_NO_OUTLINE", true)
        _screen_quad.set_meta("sera_skip_common_id_outline", true)
        camera.add_child(_screen_quad)
    elif _screen_quad.get_parent() != camera:
        _screen_quad.reparent(camera, false)
    if _screen_quad.material_override != _screen_material:
        _screen_quad.material_override = _screen_material
    _screen_camera = camera
    _screen_quad.position = Vector3(0.0, 0.0,
        -maxf(0.2, camera.near * 1.5))
    _screen_quad.visible = true


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
        if is_instance_valid(_screen_quad):
            _screen_quad.visible = false
        set_process(false)


func set_stroke_px(px: float) -> void:
    _ink_stroke = clampf(px, 1.0, 3.0)
    if is_instance_valid(ink):
        (ink.material as ShaderMaterial).set_shader_parameter("stroke_px", _ink_stroke)


# NEXUS keeps the proven RGB-ID Canvas renderer for outside silhouette.
# The 3D compositor is reserved for BASE, battle and GRID.
func set_nexus_sera_contact_mode(enabled: bool) -> void:
    if enabled and _shared_scene_mode:
        # Keep the proven RGB contact palette, not the generic RGB12 palette.
        set_shared_scene_mode(false)
    if _nexus_sera_contact_mode == enabled:
        return
    _nexus_sera_contact_mode = enabled
    if is_instance_valid(ink):
        var material: ShaderMaterial = ink.material as ShaderMaterial
        material.shader = NEXUS_CONTACT_INK if enabled else INK
        # Rebind all shared uniforms when replacing a shader resource.
        material.set_shader_parameter("mesh_id_texture", id_viewport.get_texture())
        material.set_shader_parameter("mesh_id_texel", Vector2(
            1.0 / float(id_viewport.size.x), 1.0 / float(id_viewport.size.y)))
        material.set_shader_parameter("ink_color", Color("#17212f"))
        material.set_shader_parameter("stroke_px", _ink_stroke)
        if enabled:
            # NEXUS SERA only. Retain the room/building 2px ID ink.
            material.set_shader_parameter("sera_stroke_px", 4.0)
            material.set_shader_parameter("sera_seam_px", 3.0)
            material.set_shader_parameter("sera_screen_bounds", Vector4.ZERO)
    # NEXUS dedicated RGB IDs must use the proven canvas compositor.
    # Never use the fullscreen spatial quad for the NEXUS full-body.
    if is_instance_valid(_screen_quad):
        _screen_quad.visible = false
    _clear_copies()
    _scan_elapsed = 0.0


func _process(delta: float) -> void:
    if _root_refs.is_empty() or not is_instance_valid(source_viewport):
        return
    var viewport_rect: Rect2 = source_viewport.get_visible_rect()
    # A CanvasLayer is not a Control layout parent: explicitly size the
    # compositing quad to the source viewport, including after resize.
    var desired_rect_size: Vector2 = viewport_rect.size
    if desired_rect_size.x < 32.0 or desired_rect_size.y < 32.0:
        return
    if size != desired_rect_size:
        size = desired_rect_size
    # A CanvasLayer has no Control layout parent. Always keep the actual
    # drawable rectangle at the source viewport's pixel dimensions.
    if ink.position != Vector2.ZERO:
        ink.position = Vector2.ZERO
    if ink.size != desired_rect_size:
        ink.size = desired_rect_size
    var source_camera: Camera3D = source_viewport.get_camera_3d()
    if not is_instance_valid(source_camera):
        ink.visible = false
        if is_instance_valid(_screen_quad):
            _screen_quad.visible = false
        return
    # NEXUS RGB mask: stable Canvas (restores missing outside silhouette).
    # BASE / battle / GRID retain transparent-3D composition before VFX.
    ink.visible = not _shared_scene_mode
    if _shared_scene_mode:
        _sync_screen_quad(source_camera)
    elif is_instance_valid(_screen_quad):
        _screen_quad.visible = false
    var dirty: bool = _sync_camera(source_camera)
    _scan_elapsed -= delta
    if _scan_elapsed <= 0.0:
        _scan_elapsed = SCAN_INTERVAL
        dirty = _rescan() or dirty
    dirty = _sync_copies() or dirty
    if dirty:
        if _shared_scene_mode:
            _update_shared_screen_bounds(source_camera)
        elif _nexus_sera_contact_mode:
            _update_nexus_sera_screen_bounds(source_camera)
        id_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
        _redraw_requests += 1




# Restrict the one-pixel OUTSIDE silhouette search to the screen-space region
# covered by the displayed SERA. This avoids a full-screen neighbor scan.
# Only calculate when ID rendering is dirty (camera/motion/equipment changes).
func _set_nexus_screen_bounds(bounds: Vector4) -> void:
    if is_instance_valid(ink) and ink.material is ShaderMaterial:
        (ink.material as ShaderMaterial).set_shader_parameter(
            "sera_screen_bounds", bounds)


func _update_nexus_sera_screen_bounds(camera: Camera3D) -> void:
    if not is_instance_valid(ink) or not is_instance_valid(camera):
        return
    var material: ShaderMaterial = ink.material as ShaderMaterial
    if material == null:
        return
    var viewport_size: Vector2 = source_viewport.get_visible_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        _set_nexus_screen_bounds(Vector4.ZERO)
        return
    var low: Vector2 = Vector2(1000000.0, 1000000.0)
    var high: Vector2 = Vector2(-1000000.0, -1000000.0)
    var found: bool = false
    var crosses_camera: bool = false
    for key in _contact_ids.keys():
        var weak: WeakRef = _source_refs.get(key) as WeakRef
        var source: MeshInstance3D = (
            weak.get_ref() as MeshInstance3D if weak != null else null)
        if not is_instance_valid(source) or not source.is_visible_in_tree() or (
                source.mesh == null):
            continue
        var bounds: AABB = source.get_aabb()
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var local: Vector3 = bounds.position + (
                        bounds.size * Vector3(x, y, z))
                    var world_point: Vector3 = source.global_transform * local
                    if camera.is_position_behind(world_point):
                        crosses_camera = true
                        continue
                    var point: Vector2 = camera.unproject_position(world_point)
                    low = low.min(point)
                    high = high.max(point)
                    found = true
    if crosses_camera:
        # Conservative: never crop an edge that might enter the near plane.
        _set_nexus_screen_bounds(Vector4(0.0, 0.0, 1.0, 1.0))
    elif found:
        var margin: Vector2 = Vector2(5.0, 5.0)
        var uv_min: Vector2 = ((low - margin) / viewport_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        var uv_max: Vector2 = ((high + margin) / viewport_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        _set_nexus_screen_bounds(Vector4(
            uv_min.x, uv_min.y, uv_max.x, uv_max.y))
    else:
        _set_nexus_screen_bounds(Vector4.ZERO)

# Project the bounds of styled opaque meshes for outside ink only. An empty
# mask draws no outline, so clear depth does not become a full-screen border.
func _update_shared_screen_bounds(camera: Camera3D) -> void:
    if _screen_material == null:
        return
    var screen_size: Vector2 = source_viewport.get_visible_rect().size
    if screen_size.x < 1.0 or screen_size.y < 1.0:
        return
    var low := Vector2(1000000.0, 1000000.0)
    var high := Vector2(-1000000.0, -1000000.0)
    var found: bool = false
    var near_plane: bool = false
    for key in _styled_sources.keys():
        var source_ref: WeakRef = _source_refs.get(key) as WeakRef
        var source: GeometryInstance3D = (
            source_ref.get_ref() as GeometryInstance3D
            if source_ref != null else null)
        if not is_instance_valid(source) or not source.is_visible_in_tree():
            continue
        var box: AABB = source.get_aabb()
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var corner: Vector3 = box.position + box.size * (
                        Vector3(x, y, z))
                    var point3: Vector3 = source.global_transform * corner
                    if camera.is_position_behind(point3):
                        near_plane = true
                        continue
                    var projected: Vector2 = camera.unproject_position(point3)
                    low = low.min(projected)
                    high = high.max(projected)
                    found = true
    if near_plane:
        _screen_material.set_shader_parameter("ink_screen_bounds",
            Vector4(0.0, 0.0, 1.0, 1.0))
    elif found:
        var margin := Vector2(6.0, 6.0)
        var lower: Vector2 = ((low - margin) / screen_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        var upper: Vector2 = ((high + margin) / screen_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        _screen_material.set_shader_parameter("ink_screen_bounds", Vector4(
            lower.x, lower.y, upper.x, upper.y))
    else:
        _screen_material.set_shader_parameter(
            "ink_screen_bounds", Vector4.ZERO)


func _sync_camera(source_camera: Camera3D) -> bool:
    var target_size: Vector2 = size
    if target_size.x < 32.0 or target_size.y < 32.0:
        return false
    # Keep one ID target per rendering viewport, rather than one per actor.
    # Mirror IRIS: sample one ID texel per final displayed viewport pixel.
    # The previous 921600-pixel cap produced a different sampling footprint.
    var desired := Vector2i(maxi(32, roundi(target_size.x)),
        maxi(32, roundi(target_size.y)))
    var dirty: bool = false
    if id_viewport.size != desired:
        id_viewport.size = desired
        (ink.material as ShaderMaterial).set_shader_parameter("mesh_id_texel",
            Vector2(1.0 / float(desired.x), 1.0 / float(desired.y)))
        if _screen_material != null:
            _screen_material.set_shader_parameter("mesh_id_texel", Vector2(
                1.0 / float(desired.x), 1.0 / float(desired.y)))
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
        # ID clones live in a separate World3D and always use layer one.
        # Do not inherit arbitrary per-effect source render masks: the
        # originals have already been checked for visibility/culling.
        id_camera.cull_mask = 1
        id_camera.global_transform = source_camera.global_transform
        dirty = true
    return dirty


static func _is_visual_part(node: Node) -> bool:
    var cursor: Node = node
    while cursor != null:
        # NEXUS-only GPU SERA silhouette: omit tagged display meshes from
        # the shared ID pass, but continue drawing the room and all other
        # Viewports. Do not use sera_no_view_edges, which also affects shading.
        if bool(cursor.get_meta("sera_skip_common_id_outline", false)) or (
                bool(cursor.get_meta("sera_no_view_edges", false))) or (
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


static func _is_nexus_contact_mesh(node: Node) -> bool:
    var cursor: Node = node
    while cursor != null:
        if bool(cursor.get_meta("sera_nexus_id_contact_only", false)):
            return true
        cursor = cursor.get_parent()
    return false


static func _outline_role(node: Node) -> int:
    var cursor: Node = node
    while cursor != null:
        var tag: String = str(cursor.get_meta("sera_outline_role", ""))
        match tag:
            "actor": return 1
            "facility": return 2
            "clutter": return 3
            "grid": return 4
        cursor = cursor.get_parent()
    return 1


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
        return mesh.mesh != null and not (mesh.mesh is QuadMesh) and (
            not (mesh.mesh is PlaneMesh)) and _solid_material(mesh)
    if node is MultiMeshInstance3D:
        var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
        return batch.multimesh != null and batch.multimesh.mesh != null and (
            _solid_material(batch))
    return false


static func _background_occluder(node: Node3D) -> bool:
    # Floor and ground should occlude IDs behind them, but should NOT have
    # a thick black border. They receive ID=0 (same as background).
    if not (node is MeshInstance3D) and not (node is MultiMeshInstance3D):
        return false
    if not _solid_material(node as GeometryInstance3D):
        return false
    if bool(node.get_meta("sera_outline_occluder_only", false)):
        return true
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


# Unique RGB ID for each visible NEXUS SERA mesh. Recycle IDs on swaps.
# Allocation is independent of the red-only room/architecture IDs.
func _contact_id_for(key: int) -> int:
    if _contact_ids.has(key):
        return int(_contact_ids[key])
    var contact_id: int = 0
    if not _free_contact_ids.is_empty():
        contact_id = _free_contact_ids.pop_back()
    elif _next_contact_id <= NEXUS_CONTACT_PALETTE_COUNT:
        contact_id = _next_contact_id
        _next_contact_id += 1
    if contact_id > 0:
        _contact_ids[key] = contact_id
    return contact_id


func _release_contact_id(key: int) -> void:
    if not _contact_ids.has(key):
        return
    _free_contact_ids.append(int(_contact_ids[key]))
    _contact_ids.erase(key)


func _range_less(a: Dictionary, b: Dictionary) -> bool:
    return int(a["first"]) < int(b["first"])


func _release_ids(record: Dictionary) -> void:
    if record.is_empty():
        return
    var released: Dictionary = {
        "first": int(record["first"]), "count": int(record["count"])
    }
    if int(released["count"]) > 0:
        _free_ranges.append(released)
    _free_ranges.sort_custom(_range_less)
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
                var skip_ink: bool = bool(
                    part.get_meta("sera_outline_occluder_only", false))
                var eligible: bool = _eligible(part) and not skip_ink
                var occluding: bool = (not eligible and
                    _background_occluder(part))
                if eligible or occluding:
                    desired[node.get_instance_id()] = {
                        "node": part, "occluder": occluding,
                        "contact": eligible and _nexus_sera_contact_mode and (
                            _is_nexus_contact_mesh(part))
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
        _styled_sources.erase(key)
        _pose_stamps.erase(key)
        _release_contact_id(key)
        if _id_allocations.has(key):
            _release_ids(_id_allocations[key])
            _id_allocations.erase(key)
        dirty = true
    for key in desired.keys():
        if _copies.has(key):
            continue
        var entry: Dictionary = desired[key]
        var is_occluder: bool = bool(entry["occluder"])
        var is_contact: bool = bool(entry.get("contact", false))
        var source: Node3D = entry["node"] as Node3D
        var instance_count: int = 1
        if source is MultiMeshInstance3D:
            var mesh_batch: MultiMesh = (source as MultiMeshInstance3D).multimesh
            instance_count = mesh_batch.instance_count if mesh_batch != null else 1
        # Preserve one ID draw call per MultiMesh with per-instance red
        # palette indices where possible. Seven repeating IRIS IDs do NOT
        # guarantee contact seams between every neighboring instance.
        # On logical allocation exhaustion, retain the batch as one ID.
        var per_instance_id: bool = false
        var identification: int = 0
        var allocation_count: int = 0
        if _shared_scene_mode and not is_occluder:
            allocation_count = instance_count if instance_count > 1 else 1
            identification = _allocate_ids(allocation_count)
            if identification >= 0:
                per_instance_id = instance_count > 1
            else:
                allocation_count = 1
                identification = _allocate_ids(1)
                if identification < 0:
                    continue
        elif is_contact:
            identification = _contact_id_for(key)
            if identification <= 0:
                continue
        elif not is_occluder:
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
            if is_contact:
                _release_contact_id(key)
            if allocation_count > 0:
                _release_ids({"first": identification, "count": allocation_count})
            continue
        if allocation_count > 0:
            _id_allocations[key] = {
                "first": identification, "count": allocation_count
            }
        # EXACT IRIS per-mesh encoding: (index + 1) / 8 in the red
        # channel, with green/blue zero. Background occluders use zero.
        # Repeating the seven-value palette makes every scene mesh visible
        # but can omit seams when adjacent objects share the same red ID.
        var red_id: float = 0.0
        if not is_occluder:
            red_id = float(((identification - 1) % IRIS_PALETTE_COUNT) + 1) / 8.0
        var closed: bool = bool((source as GeometryInstance3D).get_meta(
            "sera_single_sided", false))
        var mat := ShaderMaterial.new()
        if _shared_scene_mode:
            var role: int = _outline_role(source)
            if is_occluder:
                # Keep depth occlusion without drawing contours on FX/ground.
                mat.shader = SHARED_ID_CLOSED if closed else SHARED_ID_OPEN
                mat.set_shader_parameter("encoded_id", Vector3.ZERO)
            elif source is MultiMeshInstance3D:
                mat.shader = SHARED_MULTI_CLOSED if closed else SHARED_MULTI_OPEN
                mat.set_shader_parameter("mesh_id_base", identification)
                mat.set_shader_parameter("role_code", role)
                mat.set_shader_parameter("use_instance_roles", bool(
                    source.get_meta("sera_outline_instanced_roles", false)))
            else:
                mat.shader = SHARED_ID_CLOSED if closed else SHARED_ID_OPEN
                mat.set_shader_parameter("encoded_id", Vector3(
                    float(identification % 64) / 63.0, float(role) / 8.0,
                    float(int(identification / 64) % 64) / 63.0))
        elif is_contact:
            mat.shader = NEXUS_CONTACT_CLOSED if closed else NEXUS_CONTACT_OPEN
            var digit: int = identification - 1
            mat.set_shader_parameter("contact_id", Vector3(
                float(digit % 7 + 1) / 8.0,
                float(int(digit / 7) % 7 + 1) / 8.0,
                float(int(digit / 49) % 7 + 1) / 8.0))
        elif per_instance_id:
            mat.shader = MULTI_ID_CLOSED if closed else MULTI_ID_OPEN
            mat.set_shader_parameter("mesh_id_base", identification)
        else:
            mat.shader = ID_CLOSED if closed else ID_OPEN
            mat.set_shader_parameter("mesh_id", red_id)
        clone.material_override = mat
        clone.name = "VisibleID_%d" % identification
        clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        clone.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        clone.layers = 1
        id_viewport.add_child(clone)
        _copies[key] = clone
        _source_refs[key] = weakref(source)
        if _shared_scene_mode and not is_occluder:
            _styled_sources[key] = true
        dirty = true
    return dirty


func _sync_copies() -> bool:
    var dirty: bool = false
    for key in _copies.keys():
        var ref: WeakRef = _source_refs.get(key) as WeakRef
        var source: Node3D = null
        if ref != null:
            source = ref.get_ref() as Node3D
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
        if _shared_scene_mode and source is MultiMeshInstance3D:
            # MultiMesh is shared with the opaque source; in-place animated
            # instance transforms do not change the resource identity.
            var parent_node: Node = source.get_parent()
            var stamp: int = int(parent_node.get_meta(
                "sera_outline_pose_stamp", 0)) if parent_node != null else 0
            if stamp != int(_pose_stamps.get(key, -1)):
                _pose_stamps[key] = stamp
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
    _styled_sources.clear()
    _pose_stamps.clear()
    _id_allocations.clear()
    _free_ranges.clear()
    _next_id = 1
    _contact_ids.clear()
    _free_contact_ids.clear()
    _next_contact_id = 1

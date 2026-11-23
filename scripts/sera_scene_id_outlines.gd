extends Control
## One shared visible-mesh-ID outline compositor PER rendering Viewport.
## All 3D scenes use one per-viewport RGB visible-ID pass with 3D ink before
## foreground VFX. One shared ID viewport, no CPU pixel reads or source edits.
# Reuse the proven IRIS resources, with no reimplementation of their code.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const ID_CLOSED = preload("res://shaders/sera_iris_mesh_id_closed.gdshader")
const ID_OPEN = preload("res://shaders/sera_iris_mesh_id_open.gdshader")
const MULTI_ID_CLOSED = preload("res://shaders/sera_scene_multimesh_iris_id_closed.gdshader")
const MULTI_ID_OPEN = preload("res://shaders/sera_scene_multimesh_iris_id_open.gdshader")
const INK = preload("res://shaders/sera_iris_mesh_id_outline.gdshader")
const NEXUS_CONTACT_INK = preload("res://shaders/sera_nexus_mesh_contact_ink.gdshader")
const NEXUS_SPATIAL_INK = preload("res://shaders/sera_nexus_mesh_contact_spatial_ink.gdshader")
const NEXUS_CONTACT_CLOSED = preload("res://shaders/sera_nexus_mesh_contact_closed.gdshader")
const NEXUS_CONTACT_OPEN = preload("res://shaders/sera_nexus_mesh_contact_open.gdshader")
const SHARED_INK = preload("res://shaders/sera_bittaran_visible_mesh_id_ink.gdshader")
const ConvexInk = preload("res://scripts/sera_scene_convex_ink.gd")
const OutlineStandard = preload("res://scripts/sera_outline_standard.gd")
# Same Shader resource, not a visually similar replacement.
const BITTARAN_ID_INK = SHARED_INK
const SHARED_CANVAS_INK = preload("res://shaders/sera_scene_visible_ink_canvas.gdshader")
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
var _base_scene: WeakRef
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
# -1 means use the scene's preset. Only an explicit ViewEdges.set_stroke_px
# overrides the actor OUTSIDE radius, never its seam or inside radius.
var _actor_inside_override_px: float = -1.0
var _actor_outside_override_px: float = -1.0
var _actor_seam_override_px: float = -1.0
var _output_px_per_id_pixel: Vector2 = Vector2.ONE
var _redraw_requests: int = 0
var _nexus_sera_contact_mode: bool = false
var _contact_ids: Dictionary = {}
var _free_contact_ids: Array[int] = []
var _next_contact_id: int = 1
var _shared_scene_mode: bool = false
# Bittaran, training, BASE, NEXUS and previews now all use the single
# documented actor 4/0/2, facility 4/0/3, clutter 3/0/1, NEXUS 3/0/2
# standard. Scene profiles change role-2/3 widths only.
var _bittaran_id_mode: bool = false
# Numeric profile selects environment: 0=BASE/default, 1=Bittaran,
# 2=NEXUS room, 3=training. Character widths stay universally 4/0/2.
var _requested_scene_profile: int = 0
# In combat, read the interpolated render pose only from late _process.
# The Bittaran battle and the articulated SERA rig finish their own _process
# before our process_priority=10000. Capturing at frame_pre_draw happened
# outside this render-frame update phase and could use a different pose sample.
# Non-Bittaran screens retain their existing synchronization behavior.
var _bittaran_pose_frame: int = -1
var _bittaran_pose_dirty_frame: int = -1
# Only independent equipment preview SubViewports use 2D shared-ID ink.
var _part_preview_canvas_mode: bool = false
# Combat needs the interpolated pose every render frame, not the last physics tick.
# Keep BASE, NEXUS and part previews on their existing on-demand ID updates.
var _combat_scene_mode: bool = false
var _screen_quad: MeshInstance3D
var _screen_material: ShaderMaterial
var _screen_camera: Camera3D
var _convex_ink: Node
var _styled_sources: Dictionary = {} # Visible IDs, excludes background depth masks.
var _pose_stamps: Dictionary = {}
# Reuse one interpolated parent pose for ALL of that parent's visible parts
# during one frame. No joint can see a different interpolation sample.
var _combat_anchor_pose_frame: int = -1
var _combat_anchor_pose_cache: Dictionary = {}
var _base_outline_enabled: bool = true
var _character_outline_enabled: bool = true
var _part_outline_enabled: bool = true

# Refresh on page changes instead of loading config for every mesh/frame.
func refresh_graphics_preferences() -> void:
    _base_outline_enabled = GraphicsSettings.get_enabled("base_outline")
    _character_outline_enabled = GraphicsSettings.get_enabled("character_outline")
    _part_outline_enabled = GraphicsSettings.get_enabled("part_outline")
    _scan_elapsed = 0.0

func _graphics_outline_allowed(part: Node3D) -> bool:
    var cursor: Node = part
    while cursor != null:
        match str(cursor.get_meta("sera_graphics_outline_category", "")):
            "base":
                return _base_outline_enabled
            "character":
                return _character_outline_enabled
            "part":
                return _part_outline_enabled
        cursor = cursor.get_parent()
    # Training/boss actors and ordinary full-body models use this default.
    return _character_outline_enabled



# The combat flag lives on main.gd and is inherited by actor descendants.
# Checking live roots also prevents a window-owned compositor from leaking
# combat's continuous update mode into the next scene.
static func _is_combat_descendant(node: Node) -> bool:
    var current: Node = node
    while current != null:
        if bool(current.get_meta("sera_combat_convex_ink", false)):
            return true
        current = current.get_parent()
    return false


# Scene roots retain their normal ID/shading logic. For an isolated part
# viewer, only the final ink layer changes from 3D quad to CanvasLayer.
func _refresh_part_preview_canvas_mode() -> void:
    var preview: bool = false
    for value in _root_refs.values():
        var root_ref: WeakRef = value as WeakRef
        var root: Node3D = (root_ref.get_ref() as Node3D
            if root_ref != null else null)
        if is_instance_valid(root) and _outline_role(root) == 6:
            preview = true
            break
    if _part_preview_canvas_mode == preview:
        return
    _part_preview_canvas_mode = preview
    if _shared_scene_mode and is_instance_valid(ink):
        var mat: ShaderMaterial = ink.material as ShaderMaterial
        if mat != null:
            mat.shader = SHARED_CANVAS_INK if preview else INK
            if preview:
                OutlineStandard.apply_id_widths(mat)
            mat.set_shader_parameter("mesh_id_texture", id_viewport.get_texture())
            mat.set_shader_parameter("mesh_id_texel", Vector2(
                1.0 / float(id_viewport.size.x),
                1.0 / float(id_viewport.size.y)))
            mat.set_shader_parameter("ink_color", Color("#17212f"))
            if preview and _shared_scene_mode:
                mat.set_shader_parameter("output_px_per_id_pixel",
                    _output_px_per_id_pixel)
                mat.set_shader_parameter("actor_inside_override_px",
                    _actor_inside_override_px)
                mat.set_shader_parameter("actor_outside_override_px",
                    _actor_outside_override_px)
                mat.set_shader_parameter("actor_seam_override_px",
                    _actor_seam_override_px)
                mat.set_shader_parameter("scene_profile",
                    _active_scene_profile())
    if preview and is_instance_valid(_screen_quad):
        _screen_quad.visible = false


func _refresh_combat_viewport_mode() -> void:
    var combat: bool = false
    for entry in _root_refs.values():
        var ref: WeakRef = entry as WeakRef
        if ref == null:
            continue
        var root: Node3D = ref.get_ref() as Node3D
        if is_instance_valid(root) and _is_combat_descendant(root):
            combat = true
            break
    _combat_scene_mode = combat
    # The actor rig evaluates before the main combat camera (priority 0).
    # Capture the final _process render pose after both have advanced, not the pose
    # from the beginning of this frame. Non-combat viewports keep their
    # existing scheduling to avoid changing preview/BASE behavior.
    # Let player, boss, authored joints and camera finish their idle-frame
    # updates before copying their displayed (interpolated) source poses.
    process_priority = 10000 # Final _process sync for every 3D scene.
    if not is_instance_valid(id_viewport):
        return
    if _root_refs.is_empty():
        id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    else:
        # Bittaran's continuous RGB12 ID rendering in every active viewport.
        id_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


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
            if (_shared_scene_mode and not _part_preview_canvas_mode) else (
            is_instance_valid(ink) and ink.visible)),
        "ink_rect_size": ink.size if is_instance_valid(ink) else Vector2.ZERO,
        "ink_shader_bound": (is_instance_valid(_screen_quad) and
            _screen_material != null and
            _screen_material.shader == (
                BITTARAN_ID_INK if _bittaran_id_mode else SHARED_INK)) if (
            _shared_scene_mode and not _part_preview_canvas_mode) else (
            is_instance_valid(ink) and ink.material is ShaderMaterial and
            (ink.material as ShaderMaterial).shader == (
                NEXUS_CONTACT_INK if _nexus_sera_contact_mode else
                (SHARED_CANVAS_INK if _part_preview_canvas_mode else INK))),
        "bittaran_mesh_id_mode": _bittaran_id_mode,
        "canonical_id_shader": true,
        "scene_width_profile": _active_scene_profile(),
        "convex_draw_batches": int(_convex_ink.call("get_draw_count")) if (
            is_instance_valid(_convex_ink)) else 0,
        "base_facility_convex_px": OutlineStandard.BASE_FACILITY_CONVEX_PX,
        "base_clutter_convex_px": OutlineStandard.BASE_CLUTTER_CONVEX_PX,
        "nexus_environment_convex_px": OutlineStandard.NEXUS_CONVEX_PX,
        "display_px_per_id_texel": _output_px_per_id_pixel,
        "actor_inside_override_px": _actor_inside_override_px,
        "actor_outside_override_px": _actor_outside_override_px,
        "actor_seam_override_px": _actor_seam_override_px,
        "actor_inside_px": _effective_actor_inside_px(),
        "actor_outside_px": _effective_actor_outside_px(),
        "actor_seam_px": _effective_actor_seam_px(),
        "actor_total_silhouette_px": (
            _effective_actor_inside_px() + _effective_actor_outside_px()),
        "bittaran_pose_frame": _bittaran_pose_frame,
        "bittaran_pose_dirty_frame": _bittaran_pose_dirty_frame,
        "shared_vfx_safe_3d_ink": _shared_scene_mode,
        "nexus_contact_vfx_safe_3d_ink": false,
        "front_effects_cover_ink": (_shared_scene_mode and not _part_preview_canvas_mode),
        "ink_draw_source": "spatial_before_vfx" if (
            _shared_scene_mode and not _part_preview_canvas_mode) else "canvas",
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
    refresh_graphics_preferences()
    name = "SeraIDOutlineControl"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    source_viewport = get_viewport()
    _convex_ink = ConvexInk.new()
    _convex_ink.name = "SeraVisibleIDConvexOnly"
    add_child(_convex_ink)
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
    # Copy the render camera exactly; do not interpolate the ID camera again.
    id_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
    # This compositor belongs to the Window, not to the current scene.
    # After NEXUS exits its RGB contact mode must not block the next
    # combat/BASE actor from selecting the shared role+RGB12 ID palette.
    # Both modes are mutually exclusive, including across scene changes.
    if enabled and _nexus_sera_contact_mode:
        _nexus_sera_contact_mode = false
    if _shared_scene_mode == enabled:
        return
    _shared_scene_mode = enabled
    if enabled:
        _screen_material = ShaderMaterial.new()
        _screen_material.shader = SHARED_INK
        OutlineStandard.apply_id_widths(_screen_material)
        _screen_material.render_priority = -30
        _screen_material.set_shader_parameter(
            "scene_profile", _active_scene_profile())
        _screen_material.set_shader_parameter("actor_inside_override_px",
            _actor_inside_override_px)
        _screen_material.set_shader_parameter("actor_outside_override_px",
            _actor_outside_override_px)
        _screen_material.set_shader_parameter("actor_seam_override_px",
            _actor_seam_override_px)
        _screen_material.set_shader_parameter("output_px_per_id_pixel",
            _output_px_per_id_pixel)
        _screen_material.set_shader_parameter(
            "mesh_id_texture", id_viewport.get_texture())
        _screen_material.set_shader_parameter("mesh_id_texel", Vector2(
            1.0 / float(id_viewport.size.x),
            1.0 / float(id_viewport.size.y)))
        _screen_material.set_shader_parameter(
            "ink_color", Color("#17212f"))
        # CRATE can register before BASE's root. Resolve the actual scene
        # color again whenever roots enter, independent of registration order.
        _refresh_shared_ink_color()
        _set_shared_screen_bounds(Vector4.ZERO)
        # The source ID target remains the same. Small part previews use a
        # CanvasLayer overlay because the Compatibility 3D quad can vanish.
        var canvas_mat: ShaderMaterial = ink.material as ShaderMaterial
        canvas_mat.shader = SHARED_CANVAS_INK if _part_preview_canvas_mode else INK
        if _part_preview_canvas_mode:
            OutlineStandard.apply_id_widths(canvas_mat)
        canvas_mat.set_shader_parameter("mesh_id_texture", id_viewport.get_texture())
        canvas_mat.set_shader_parameter("mesh_id_texel", Vector2(
            1.0 / float(id_viewport.size.x), 1.0 / float(id_viewport.size.y)))
        canvas_mat.set_shader_parameter("ink_color", Color("#17212f"))
        canvas_mat.set_shader_parameter("ink_screen_bounds", Vector4.ZERO)
        if _part_preview_canvas_mode:
            canvas_mat.set_shader_parameter(
                "output_px_per_id_pixel", _output_px_per_id_pixel)
            canvas_mat.set_shader_parameter("actor_inside_override_px",
                _actor_inside_override_px)
            canvas_mat.set_shader_parameter("actor_outside_override_px",
                _actor_outside_override_px)
            canvas_mat.set_shader_parameter("actor_seam_override_px",
                _actor_seam_override_px)
            canvas_mat.set_shader_parameter("scene_profile",
                _active_scene_profile())
        ink.visible = _part_preview_canvas_mode
    elif is_instance_valid(_screen_quad):
        _screen_quad.visible = false
    _clear_copies()
    _scan_elapsed = 0.0


# The SAME ID pose commit is made from late _process in every 3D scene,
# after each scene's original camera and articulated model handlers.
# Capture camera projection, shake offsets and every actor's interpolated
# render transform in one consecutive pass, before either viewport renders.
# The ID target stays UPDATE_ALWAYS and the completed-frame SubViewport
# continues presenting the combined image through its existing dependency.
# This fixes mismatched CPU sampling times, not a possible GPU texture lag.
func _commit_visible_render_pose(
        source_camera: Camera3D, mesh_changed: bool) -> void:
    var frame: int = Engine.get_process_frames()
    if _bittaran_pose_frame == frame:
        return
    _bittaran_pose_frame = frame
    var dirty: bool = mesh_changed
    dirty = _sync_camera(source_camera) or dirty
    dirty = _sync_copies() or dirty
    if dirty:
        _update_shared_screen_bounds(source_camera)
        _bittaran_pose_dirty_frame = frame
        _redraw_requests += 1
    if id_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
        id_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# Select the dedicated Bittaran ID-contacts compositor without changing the
# shared-ID source pass, depth resolve or the other scenes' shader settings.
# This is intentionally NOT a topology-based convex/crease detector.
func _active_scene_profile() -> int:
    return 1 if _bittaran_id_mode else _requested_scene_profile


func set_scene_profile(profile: int) -> void:
    # Only numeric widths/color vary: same shader, RGB IDs and pose pipeline.
    var requested: int = clampi(profile, 0, 3)
    if _requested_scene_profile == requested:
        return
    _requested_scene_profile = requested
    if _screen_material != null:
        _screen_material.set_shader_parameter(
            "scene_profile", _active_scene_profile())
        _refresh_shared_ink_color()
    if _part_preview_canvas_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        (ink.material as ShaderMaterial).set_shader_parameter(
            "scene_profile", _active_scene_profile())
    _scan_elapsed = 0.0


func set_bittaran_id_mode(enabled: bool) -> void:
    if _bittaran_id_mode == enabled:
        return
    _bittaran_id_mode = enabled
    _bittaran_pose_frame = -1
    _bittaran_pose_dirty_frame = -1
    if _screen_material != null:
        _screen_material.set_shader_parameter(
            "scene_profile", _active_scene_profile())
        _refresh_shared_ink_color()
    if _part_preview_canvas_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        (ink.material as ShaderMaterial).set_shader_parameter(
            "scene_profile", _active_scene_profile())
    _scan_elapsed = 0.0
    _last_camera_projection = -1


func _sync_screen_quad(camera: Camera3D) -> void:
    if not (_shared_scene_mode or _nexus_sera_contact_mode) or not is_instance_valid(camera):
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


func _refresh_shared_ink_color() -> void:
    if _screen_material == null:
        return
    var base_scene: bool = false
    for value in _root_refs.values():
        var root_ref: WeakRef = value as WeakRef
        var root: Node3D = (
            root_ref.get_ref() as Node3D if root_ref != null else null)
        if is_instance_valid(root) and str(root.get_meta(
                "sera_graphics_outline_category", "")) == "base":
            base_scene = true
            break
    # BASE keeps black ink, NEXUS keeps blue-grey. Color only, same shader.
    base_scene = base_scene and _active_scene_profile() != 2
    _screen_material.set_shader_parameter(
        "ink_color", Color.BLACK if base_scene else Color("#17212f"))
    # The reserved ID role 7 keeps emitter protection in the SINGLE ink
    # shader. No physical crease material is created or updated.
    _screen_material.set_shader_parameter(
        "emissive_contact_alpha", 0.45 if base_scene else 1.0)


func register_root(root: Node3D, owner: Node) -> void:
    if not is_instance_valid(root) or not is_instance_valid(owner):
        return
    if root.get_meta("sera_graphics_outline_category", "") == "base":
        _base_scene = weakref(root)
        if not get_tree().node_added.is_connected(_base_geometry_changed):
            get_tree().node_added.connect(_base_geometry_changed)
            get_tree().node_removed.connect(_base_geometry_changed)
    _root_refs[owner.get_instance_id()] = weakref(root)
    _refresh_part_preview_canvas_mode()
    _refresh_combat_viewport_mode()
    _refresh_shared_ink_color()
    _scan_elapsed = 0.0
    visible = true
    set_process(true)


func _base_geometry_changed(node: Node) -> void:
    if _scan_elapsed == 0.0 or not (node is MeshInstance3D or node is MultiMeshInstance3D):
        return
    var base := _base_scene.get_ref() as Node3D
    if is_instance_valid(base) and base.is_ancestor_of(node):
        _scan_elapsed = 0.0

func unregister_root(owner: Node) -> void:
    if is_instance_valid(owner):
        var ref := _root_refs.get(owner.get_instance_id()) as WeakRef
        if _base_scene != null and ref != null and ref.get_ref() == _base_scene.get_ref():
            get_tree().node_added.disconnect(_base_geometry_changed)
            get_tree().node_removed.disconnect(_base_geometry_changed)
            _base_scene = null
        _root_refs.erase(owner.get_instance_id())
        _scan_elapsed = 0.0
    _refresh_part_preview_canvas_mode()
    _refresh_combat_viewport_mode()
    _refresh_shared_ink_color()
    if _root_refs.is_empty():
        _clear_copies()
        id_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        visible = false
        if is_instance_valid(_screen_quad):
            _screen_quad.visible = false
        # The CanvasLayer and compositor outlive the scene (they are children
        # of the Window). Do not leak NEXUS RGB contact mode into combat.
        _shared_scene_mode = false
        _nexus_sera_contact_mode = false
        _bittaran_id_mode = false
        _requested_scene_profile = 0
        _actor_inside_override_px = -1.0
        _actor_outside_override_px = -1.0
        _actor_seam_override_px = -1.0
        _output_px_per_id_pixel = Vector2.ONE
        _bittaran_pose_frame = -1
        _bittaran_pose_dirty_frame = -1
        _screen_material = null
        # A new camera can have exactly the same transform and projection;
        # force its settings back into the independent ID camera on entry.
        _last_camera_projection = -1
        _last_camera_mask = -1
        set_process(false)


# Legacy scalar now really changes only the actor OUTSIDE width.
# The caller can also override all three independently without changing
# facility, CRATE, clutter or part-preview settings.
func set_stroke_px(px: float) -> void:
    _ink_stroke = clampf(px, 0.0, 8.0)
    _actor_outside_override_px = _ink_stroke
    _apply_actor_width_overrides()
    if not _shared_scene_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        (ink.material as ShaderMaterial).set_shader_parameter(
            "stroke_px", _ink_stroke)


func set_actor_outline_widths(inside_px: float, outside_px: float,
        seam_px: float) -> void:
    _actor_inside_override_px = clampf(inside_px, 0.0, 8.0)
    _actor_outside_override_px = clampf(outside_px, 0.0, 8.0)
    _actor_seam_override_px = clampf(seam_px, 0.0, 8.0)
    _ink_stroke = _actor_outside_override_px
    _apply_actor_width_overrides()


func _apply_actor_width_overrides() -> void:
    if _screen_material != null and _shared_scene_mode:
        _screen_material.set_shader_parameter(
            "actor_inside_override_px", _actor_inside_override_px)
        _screen_material.set_shader_parameter(
            "actor_outside_override_px", _actor_outside_override_px)
        _screen_material.set_shader_parameter(
            "actor_seam_override_px", _actor_seam_override_px)
    if _part_preview_canvas_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        var canvas: ShaderMaterial = ink.material as ShaderMaterial
        canvas.set_shader_parameter(
            "actor_inside_override_px", _actor_inside_override_px)
        canvas.set_shader_parameter(
            "actor_outside_override_px", _actor_outside_override_px)
        canvas.set_shader_parameter(
            "actor_seam_override_px", _actor_seam_override_px)


func _effective_actor_inside_px() -> float:
    if _actor_inside_override_px >= 0.0:
        return _actor_inside_override_px
    return OutlineStandard.ACTOR_INSIDE_PX


func _effective_actor_outside_px() -> float:
    if _actor_outside_override_px >= 0.0:
        return _actor_outside_override_px
    return OutlineStandard.ACTOR_OUTSIDE_PX


func _effective_actor_seam_px() -> float:
    if _actor_seam_override_px >= 0.0:
        return _actor_seam_override_px
    return OutlineStandard.ACTOR_SEAM_PX


# Compute what one ID target texel occupies on the FINAL display.
# Viewport.get_screen_transform includes nested SubViewportContainers and
# root Window canvas-items stretching; the ID camera itself stays 1:1 with
# source_viewport to preserve exact 3D visibility/depth.
func _refresh_output_pixel_scale() -> void:
    var scale: Vector2 = source_viewport.get_screen_transform().get_scale().abs()
    if scale.x < 0.125 or scale.y < 0.125:
        scale = Vector2.ONE
    if scale.is_equal_approx(_output_px_per_id_pixel):
        return
    _output_px_per_id_pixel = scale
    if is_instance_valid(_convex_ink):
        _convex_ink.call("set_render_context",
            _active_scene_profile(), id_viewport.get_texture(), scale)
    if _screen_material != null:
        _screen_material.set_shader_parameter(
            "output_px_per_id_pixel", scale)
    if _part_preview_canvas_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        (ink.material as ShaderMaterial).set_shader_parameter(
            "output_px_per_id_pixel", scale)



# NEXUS keeps the proven RGB contact-ID mask, but composites the ink in
# transparent 3D BEFORE the gate/glow effects instead of over them as Canvas.
# Backwards-compatible entry point: selecting the old NEXUS contact mode
# must NEVER turn on another ID palette, Canvas-only stencil, or shader.
# It now selects only the canonical NEXUS numeric 1/2/2 and 2px widths.
func set_nexus_sera_contact_mode(enabled: bool) -> void:
    _nexus_sera_contact_mode = false
    set_scene_profile(2 if enabled else 0)


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
    _refresh_output_pixel_scale()
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
    # Both modes use a depth-resolved ID mask, with ink drawn before room VFX.
    # Canvas remains only for standalone legacy IRIS previews.
    # The NEXUS character and isolated parts are inked after opaque 3D.
    # BASE, CRATE and combat keep their existing before-VFX spatial ink.
    var spatial_mode: bool = _shared_scene_mode and not _part_preview_canvas_mode
    ink.visible = not spatial_mode
    if spatial_mode:
        _sync_screen_quad(source_camera)
    elif is_instance_valid(_screen_quad):
        _screen_quad.visible = false
    # Exactly the Bittaran late _process pose capture for each shared-ID
    # scene; the part preview only differs in how the final pixels are shown.
    var dirty: bool = false
    if _base_scene == null or not is_instance_valid(_base_scene.get_ref()):
        _scan_elapsed -= delta
    if _scan_elapsed <= 0.0:
        _scan_elapsed = SCAN_INTERVAL
        dirty = _rescan()
    if _shared_scene_mode:
        _commit_visible_render_pose(source_camera, dirty)
        if is_instance_valid(_convex_ink):
            _convex_ink.call("sync_animated_multimeshes")
    else:
        dirty = _sync_camera(source_camera) or dirty
        dirty = _sync_copies() or dirty
        if dirty:
            if _nexus_sera_contact_mode:
                _update_nexus_sera_screen_bounds(source_camera)
            id_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
            _redraw_requests += 1




# Restrict the one-pixel OUTSIDE silhouette search to the screen-space region
# covered by the displayed SERA. This avoids a full-screen neighbor scan.
# Only calculate when ID rendering is dirty (camera/motion/equipment changes).
func _set_nexus_screen_bounds(bounds: Vector4) -> void:
    if _nexus_sera_contact_mode and _screen_material != null:
        _screen_material.set_shader_parameter("sera_screen_bounds", bounds)
    elif is_instance_valid(ink) and ink.material is ShaderMaterial:
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
        var margin: Vector2 = Vector2(3.0, 3.0)
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
# Send the projected bounds to the active compositor. The 2D part
# shader uses the same ID-space bounds as the regular spatial renderer.
func _set_shared_screen_bounds(bounds: Vector4) -> void:
    if _screen_material != null:
        _screen_material.set_shader_parameter("ink_screen_bounds", bounds)
    if _part_preview_canvas_mode and is_instance_valid(ink) and (
            ink.material is ShaderMaterial):
        (ink.material as ShaderMaterial).set_shader_parameter(
            "ink_screen_bounds", bounds)


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
        # The ID mesh uses an interpolated render-space pose in combat.
        # Bound the SAME pose; bounding the raw physics pose can clip the
        # silhouette during fast steps, articulated attacks or camera pans.
        # Use the SAME composite pose as the ID pixel generator, so fast
        # steps and articulated joints never clip the new 4px outer ink.
        var bounds_pose: Transform3D = source.global_transform
        if _combat_scene_mode:
            var id_copy: Node3D = _copies.get(key) as Node3D
            bounds_pose = (id_copy.global_transform if is_instance_valid(id_copy)
                else _visible_combat_pose(source))
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var corner: Vector3 = box.position + box.size * (
                        Vector3(x, y, z))
                    var point3: Vector3 = bounds_pose * corner
                    if camera.is_position_behind(point3):
                        near_plane = true
                        continue
                    var projected: Vector2 = camera.unproject_position(point3)
                    low = low.min(projected)
                    high = high.max(projected)
                    found = true
    if near_plane:
        _set_shared_screen_bounds(Vector4(0.0, 0.0, 1.0, 1.0))
    elif found:
        # The old fixed 6-ID-pixel padding could clip 4 DISPLAY-pixel
        # silhouettes when the completed frame is displayed at <1x scale.
        var smallest_scale: float = maxf(0.125, minf(
            _output_px_per_id_pixel.x, _output_px_per_id_pixel.y))
        var display_outer_px: float = 4.0
        var margin_in_id_px: float = maxf(6.0,
            display_outer_px / smallest_scale + 1.0)
        var margin := Vector2(margin_in_id_px, margin_in_id_px)
        var lower: Vector2 = ((low - margin) / screen_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        var upper: Vector2 = ((high + margin) / screen_size).clamp(
            Vector2.ZERO, Vector2.ONE)
        _set_shared_screen_bounds(Vector4(
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
    # Bittaran's camera shake uses projection offsets, not a node transform.
    # Mirror both independently: a stationary global_transform must not
    # leave the visible-ID pass at its pre-shake projection for even one frame.
    # Also clears stale shake offsets when returning to NEXUS/BASE.
    if id_camera.h_offset != source_camera.h_offset or (
            id_camera.v_offset != source_camera.v_offset):
        id_camera.h_offset = source_camera.h_offset
        id_camera.v_offset = source_camera.v_offset
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
    # Live equipment viewers are a separate render class (G=6), including
    # any SeraRig descendants that otherwise carry their own actor tag.
    # Do this before checking per-mesh roles so preview ink is consistent.
    var preview_cursor: Node = node
    while preview_cursor != null:
        if str(preview_cursor.get_meta(
                "sera_graphics_outline_category", "")) == "part":
            return 6
        preview_cursor = preview_cursor.get_parent()
    var cursor: Node = node
    while cursor != null:
        var tag: String = str(cursor.get_meta("sera_outline_role", ""))
        match tag:
            "actor": return 1
            "facility": return 2
            "clutter": return 3
            "grid": return 4
            "crate": return 5
            "part": return 6
        # The displayed/active SERA inherits a NEXUS/BASE facility root.
        # Its closer character category MUST take priority over that root,
        # otherwise the player becomes a role-2 facility (and gains convex).
        if str(cursor.get_meta("sera_graphics_outline_category", "")) == (
                "character"):
            return 1
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
                var valid_geometry: bool = _eligible(part) and not skip_ink
                var contact_geometry: bool = (_nexus_sera_contact_mode and
                    _is_nexus_contact_mesh(part))
                var eligible: bool = (valid_geometry and
                    _graphics_outline_allowed(part))
                # Even with character ink OFF, its solid meshes still occlude
                # room IDs. Otherwise NEXUS edges draw through the character.
                # Some real lamp glass lives below FX_NO_OUTLINE nodes.
                # It is physically opaque, so keep it in the ID depth pass
                # as ROLE 7 even though its VFX subtree is not outlined.
                var protect_emission: bool = (_shared_scene_mode and
                    bool(part.get_meta(
                        "sera_outline_emissive_protect", false)) and
                    part is GeometryInstance3D and
                    _solid_material(part as GeometryInstance3D))
                var occluding: bool = (not eligible and (
                    _background_occluder(part) or valid_geometry or
                    protect_emission))
                # Non-emissive FX and floor remain excluded/ID0; the
                # protected lamps keep their actual depth without black ink.
                if eligible or occluding:
                    desired[node.get_instance_id()] = {
                        "node": part, "occluder": occluding,
                        "protected_emission": protect_emission,
                        "contact": eligible and contact_geometry
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
        var is_protected_emission: bool = bool(
            entry.get("protected_emission", false))
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
            var player_tag := 0.0
            if role == 1:
                var ancestor: Node = source
                while ancestor != null:
                    if ancestor.has_meta("sera_player_outline"):
                        player_tag = 1.0 / 32.0
                        break
                    ancestor = ancestor.get_parent()
            if is_occluder:
                # ID role 7 protects luminous solid cores from the 3px
                # facility outer stroke; other occluders remain zero-ID
                # depth-only, as before. No second visible ID pass.
                mat.shader = SHARED_ID_CLOSED if closed else SHARED_ID_OPEN
                mat.set_shader_parameter("encoded_id", (
                    Vector3(0.0, 7.0 / 8.0, 0.0) if is_protected_emission
                    else Vector3.ZERO))
            elif source is MultiMeshInstance3D:
                mat.shader = SHARED_MULTI_CLOSED if closed else SHARED_MULTI_OPEN
                mat.set_shader_parameter("mesh_id_base", identification)
                mat.set_shader_parameter("role_code", role)
                mat.set_shader_parameter("player_tag", player_tag)
                mat.set_shader_parameter("use_instance_roles", bool(
                    source.get_meta("sera_outline_instanced_roles", false)))
            else:
                mat.shader = SHARED_ID_CLOSED if closed else SHARED_ID_OPEN
                # An odd stride permutes all 4096 IDs and separates adjacent codes.
                var code := (identification * 1733) % 4096
                mat.set_shader_parameter("encoded_id", Vector3(
                    float(code % 64) / 63.0, float(role) / 8.0 + player_tag,
                    float(int(code / 64)) / 63.0))
        elif is_occluder and _nexus_sera_contact_mode:
            # NEXUS depth-only floor panels must be distinguishable from the
            # empty backdrop, otherwise the exterior SERA dilation draws
            # through them. B=1 is reserved outside normal room/SERA IDs.
            mat.shader = NEXUS_CONTACT_CLOSED if closed else NEXUS_CONTACT_OPEN
            mat.set_shader_parameter("contact_id", Vector3(0.0, 0.0, 1.0))
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
        # This clone receives the already-interpolated source render pose.
        # A second physics interpolation in its separate World3D would lag.
        clone.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
        clone.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        clone.layers = 1
        id_viewport.add_child(clone)
        _copies[key] = clone
        _source_refs[key] = weakref(source)
        if _shared_scene_mode and not is_occluder:
            _styled_sources[key] = true
        dirty = true
    # Only world facility and clutter receive convex ink, never SERA,
    # bosses, CRATE, or preview parts. One role-filtered MultiMesh draw per
    # material/style, using the EXACT same solid sources as the RGB ID pass.
    if is_instance_valid(_convex_ink):
        _convex_ink.call("sync_sources", desired, _active_scene_profile(),
            id_viewport.get_texture(), _output_px_per_id_pixel)
    return dirty


# Resolve the same world-space render transform as the visible model.
# Player/target roots advance at physics cadence, but child armor, joints
# and equipment animate each _process. Sampling each child through its own
# physics history can interpolate render-frequency animation a second time.
# Instead interpolate the nearest physics-driven ANCHOR once, then apply
# the complete current-frame local pose of every descendant relative to
# that anchor. This is the same rule for SERA and the training target.
func _visible_combat_pose(source: Node3D) -> Transform3D:
    var frame: int = Engine.get_process_frames()
    if _combat_anchor_pose_frame != frame:
        _combat_anchor_pose_frame = frame
        _combat_anchor_pose_cache.clear()
    var anchor: Node3D = source
    while is_instance_valid(anchor):
        if anchor.physics_interpolation_mode == (
                Node.PHYSICS_INTERPOLATION_MODE_ON):
            var key: int = anchor.get_instance_id()
            var anchor_pose: Transform3D
            if _combat_anchor_pose_cache.has(key):
                anchor_pose = _combat_anchor_pose_cache[key]
            else:
                anchor_pose = anchor.get_global_transform_interpolated()
                _combat_anchor_pose_cache[key] = anchor_pose
            var relative_pose: Transform3D = (
                anchor.global_transform.affine_inverse() *
                source.global_transform)
            return anchor_pose * relative_pose
        anchor = anchor.get_parent() as Node3D
    # An entirely render-updated hierarchy has no physics interpolation.
    return source.global_transform


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
        # Hidden meshes cannot contribute pixels to the ID buffer. Defer
        # transform/mesh synchronization until visible again; the first
        # visible frame still updates both before rendering.
        if not show_id:
            continue
        # Combat source meshes inherit a smoothly interpolated body pose,
        # but their animated joints are already at the CURRENT render frame.
        # Recreate that composite pose without interpolating the joint twice.
        var render_transform: Transform3D = (
            _visible_combat_pose(source) if _combat_scene_mode
            else source.global_transform)
        if clone.global_transform != render_transform:
            clone.global_transform = render_transform
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
    if is_instance_valid(_convex_ink):
        _convex_ink.call("clear")
    _combat_anchor_pose_cache.clear()
    _combat_anchor_pose_frame = -1
    _id_allocations.clear()
    _free_ranges.clear()
    _next_id = 1
    _contact_ids.clear()
    _free_contact_ids.clear()
    _next_contact_id = 1

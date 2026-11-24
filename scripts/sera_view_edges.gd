extends Node3D
## SERA's common visible-mesh-ID outline registration.
## The old inverted hull is intentionally no longer instantiated. All active
## actors and world roots sharing one Viewport use one ID depth pass, as IRIS.
const SceneIDOutlines = preload("res://scripts/sera_scene_id_outlines.gd")
const LAYER_NAME: String = "SeraIDOutlineLayer"
const COMPOSITOR_NAME: String = "SeraIDOutlineControl"

var _contour_enabled: bool = true
var _stroke_px: float = 3.0
# Do not silently overwrite per-element actor widths when ViewEdges enters
# a shared compositor; the setter is an EXPLICIT override only.
var _stroke_explicit: bool = false
var _all_widths_explicit: bool = false
var _actor_widths_px: Vector3 = Vector3(-1.0, -1.0, -1.0)
var _nexus_sera_contact_mode: bool = false
var _numeric_outline_profile: int = 0
var _compositor: Control


func _ready() -> void:
    # SeraRig may still be under construction when ViewEdges enters the tree.
    # Add the viewport-owned CanvasLayer after the parent hierarchy settles.
    _register.call_deferred()


func _exit_tree() -> void:
    if is_instance_valid(_compositor):
        _compositor.call("unregister_root", self)
    _compositor = null


# Bittaran uses a depth-resolved mesh-ID contact mask, NOT GPU topology
# ribbons. This prevents front-facing hard/convex ridges from appearing.
static func _in_bittaran_id_scene(actor: Node3D) -> bool:
    var cursor: Node = actor
    while cursor != null:
        if bool(cursor.get_meta("sera_bittaran_id_outline", false)):
            return true
        cursor = cursor.get_parent()
    return false


static func _in_training_id_scene(actor: Node3D) -> bool:
    var cursor: Node = actor
    while cursor != null:
        if bool(cursor.get_meta("sera_training_id_outline", false)):
            return true
        cursor = cursor.get_parent()
    return false


func _register() -> void:
    if not _contour_enabled or not is_inside_tree():
        return
    var actor: Node3D = get_parent() as Node3D
    if not is_instance_valid(actor):
        return
    var viewport: Viewport = get_viewport()
    if not is_instance_valid(viewport):
        return
    var layer: CanvasLayer = viewport.get_node_or_null(LAYER_NAME) as CanvasLayer
    if layer == null:
        layer = CanvasLayer.new()
        layer.name = LAYER_NAME
        # Use a dedicated foreground CanvasLayer. Layer 0 shares the
        # default world canvas and may be composited before the 3D image
        # in GL Compatibility. The overlay must be strictly above 3D.
        # Scene HUDs use layer 2+ and remain above the ID ink.
        layer.layer = 1
        viewport.add_child(layer)
    _compositor = layer.get_node_or_null(COMPOSITOR_NAME) as Control
    if _compositor == null:
        _compositor = SceneIDOutlines.new()
        _compositor.name = COMPOSITOR_NAME
        layer.add_child(_compositor)
    _compositor.call("register_root", actor, self)
    # NEXUS full-body uses the dedicated RGB-ID canvas, while other
    # scenes retain the shared pre-VFX spatial compositor.
    # Select Bittaran's dedicated shader before enabling the shared path,
    # avoiding a SHARED_INK -> battle shader swap on the first scene frame.
    # Convex/crease geometry is never created for this battle.
    var is_bittaran: bool = _in_bittaran_id_scene(actor)
    _compositor.call("set_bittaran_id_mode", is_bittaran)
    # All scene elements use Bittaran's exact shared RGB12 ID pipeline.
    # This selects only existing widths; no NEXUS-specific ID/ink shader.
    _compositor.call("set_shared_scene_mode", true)
    # Every character/boss/CRATE now uses 6 outside, 0 inside, 1px seams.
    # Training and Bittaran retain their scene IDs for world-only settings.
    var profile: int = (
        3 if _in_training_id_scene(actor) and not is_bittaran
        else _numeric_outline_profile)
    _compositor.call("set_scene_profile", profile)
    if _all_widths_explicit:
        _compositor.call("set_actor_outline_widths",
            _actor_widths_px.x, _actor_widths_px.y, _actor_widths_px.z)
    elif _stroke_explicit:
        _compositor.call("set_stroke_px", _stroke_px)


func set_contour_enabled(enabled: bool) -> void:
    if _contour_enabled == enabled:
        return
    _contour_enabled = enabled
    if not enabled:
        if is_instance_valid(_compositor):
            _compositor.call("unregister_root", self)
        _compositor = null
    else:
        _register()


func set_stroke_px(width: float) -> void:
    _stroke_px = clampf(width, 0.0, 8.0)
    _stroke_explicit = true
    if _all_widths_explicit:
        _actor_widths_px.y = _stroke_px
    if is_instance_valid(_compositor):
        _compositor.call("set_stroke_px", _stroke_px)


# Set character silhouette inside, outside and separate-mesh boundary
# independently, in final output pixels. No other role/scene is changed.
func set_outline_widths(inside_px: float, outside_px: float,
        seam_px: float) -> void:
    _actor_widths_px = Vector3(
        clampf(inside_px, 0.0, 8.0), clampf(outside_px, 0.0, 8.0),
        clampf(seam_px, 0.0, 8.0))
    _all_widths_explicit = true
    _stroke_px = _actor_widths_px.y
    if is_instance_valid(_compositor):
        _compositor.call("set_actor_outline_widths",
            _actor_widths_px.x, _actor_widths_px.y, _actor_widths_px.z)

# Only width presets differ: 0=default, 1=Bittaran, 2=NEXUS, 3=training.
# Every profile keeps exactly the same depth-resolved RGB-ID algorithm.
func set_outline_profile(profile: int) -> void:
    _numeric_outline_profile = clampi(profile, 0, 4)
    if is_instance_valid(_compositor):
        _compositor.call("set_scene_profile", _numeric_outline_profile)


# Compatibility API: old NEXUS callers now select the numeric profile,
# never its legacy red-only/stencil mask or a separate outline shader.
func set_nexus_sera_contact_mode(enabled: bool) -> void:
    _nexus_sera_contact_mode = enabled
    set_outline_profile(2 if enabled else 0)

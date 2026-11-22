extends Node3D
## SERA's common visible-mesh-ID outline registration.
## The old inverted hull is intentionally no longer instantiated. All active
## actors and world roots sharing one Viewport use one ID depth pass, as IRIS.
const SceneIDOutlines = preload("res://scripts/sera_scene_id_outlines.gd")
const LAYER_NAME: String = "SeraIDOutlineLayer"
const COMPOSITOR_NAME: String = "SeraIDOutlineControl"

var _contour_enabled: bool = true
var _stroke_px: float = 3.0
var _nexus_sera_contact_mode: bool = false
var _compositor: Control


func _ready() -> void:
    # SeraRig may still be under construction when ViewEdges enters the tree.
    # Add the viewport-owned CanvasLayer after the parent hierarchy settles.
    _register.call_deferred()


func _exit_tree() -> void:
    if is_instance_valid(_compositor):
        _compositor.call("unregister_root", self)
    _compositor = null


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
    _compositor.call("set_stroke_px", _stroke_px)
    if _nexus_sera_contact_mode:
        _compositor.call("set_nexus_sera_contact_mode", true)


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
    _stroke_px = clampf(width, 1.0, 3.0)
    if is_instance_valid(_compositor):
        _compositor.call("set_stroke_px", _stroke_px)

# NEXUS only: the existing ID viewport draws contact seams for the display.
# All other viewports keep the original IRIS shader and palette.
func set_nexus_sera_contact_mode(enabled: bool) -> void:
    _nexus_sera_contact_mode = enabled
    if enabled and is_instance_valid(_compositor):
        _compositor.call("set_nexus_sera_contact_mode", true)

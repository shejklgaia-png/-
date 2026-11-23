extends Node3D
## SERA's common visible-mesh-ID outline registration.
## The old inverted hull is intentionally no longer instantiated. All active
## actors and world roots sharing one Viewport use one ID depth pass, as IRIS.
const SceneIDOutlines = preload("res://scripts/sera_scene_id_outlines.gd")
const VisibleConvexInk = preload("res://scripts/nexus_sera_gpu_convex_silhouette.gd")
const LAYER_NAME: String = "SeraIDOutlineLayer"
const COMPOSITOR_NAME: String = "SeraIDOutlineControl"

var _contour_enabled: bool = true
var _stroke_px: float = 3.0
var _nexus_sera_contact_mode: bool = false
var _compositor: Control
var _combat_convex: Node3D


func _ready() -> void:
    # SeraRig may still be under construction when ViewEdges enters the tree.
    # Add the viewport-owned CanvasLayer after the parent hierarchy settles.
    _register.call_deferred()


func _exit_tree() -> void:
    if is_instance_valid(_compositor):
        _compositor.call("unregister_root", self)
    _compositor = null
    _release_combat_convex()


# This experimental direct-GPU contour replaces the ID pass ONLY inside the
# authored Bittaran battle. Ordinary training, BASE and NEXUS remain unchanged.
static func _in_bittaran_gpu_scene(actor: Node3D) -> bool:
    var cursor: Node = actor
    while cursor != null:
        if bool(cursor.get_meta("sera_bittaran_gpu_outline", false)):
            return true
        cursor = cursor.get_parent()
    return false


func _release_combat_convex() -> void:
    if is_instance_valid(_combat_convex):
        _combat_convex.queue_free()
    _combat_convex = null


func _register() -> void:
    if not _contour_enabled or not is_inside_tree():
        return
    var actor: Node3D = get_parent() as Node3D
    if not is_instance_valid(actor):
        return
    var viewport: Viewport = get_viewport()
    if not is_instance_valid(viewport):
        return
    if _in_bittaran_gpu_scene(actor):
        # No ID target, camera clone or screen-space composite in this battle.
        # GPU ribbons draw only external contours and disjoint mesh boundaries;
        # same-mesh convex ridges are intentionally excluded.
        # Every edge belongs to its source mesh and uses the SAME camera,
        # including Camera3D.h_offset/v_offset during impact shake.
        if is_instance_valid(_compositor):
            _compositor.call("unregister_root", self)
        _compositor = null
        if not is_instance_valid(_combat_convex):
            var gpu: Node3D = VisibleConvexInk.new()
            gpu.name = "SeraBittaranGPUContourController"
            gpu.set("enable_combat_gpu_full_edges", true)
            gpu.set("silhouette_inside_px", 1.0)
            gpu.set("silhouette_outside_px", 3.0)
            gpu.set("seam_stroke_px", 3.0)
            gpu.set("ink_render_priority", -29)
            gpu.set("overlay_name", "SeraBittaranGPUContour")
            gpu.set("scan_interval_seconds", 1.05)
            actor.add_child(gpu)
            _combat_convex = gpu
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
    if _nexus_sera_contact_mode:
        _compositor.call("set_nexus_sera_contact_mode", true)
    else:
        _compositor.call("set_shared_scene_mode", true)
    _compositor.call("set_stroke_px", _stroke_px)
    # SERA, enemies and CRATE use visible-ID outer silhouettes and
    # separate-mesh seams in all other scenes. Do not create any convex
    # corner ribbon for those characters; facility/clutter ink is separate.
    _release_combat_convex()


func set_contour_enabled(enabled: bool) -> void:
    if _contour_enabled == enabled:
        return
    _contour_enabled = enabled
    if not enabled:
        if is_instance_valid(_compositor):
            _compositor.call("unregister_root", self)
        _compositor = null
        _release_combat_convex()
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

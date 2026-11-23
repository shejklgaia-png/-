extends Node3D
## SERA's common visible-mesh-ID outline registration.
## The old inverted hull is intentionally no longer instantiated. All active
## actors and world roots sharing one Viewport use one ID depth pass, as IRIS.
const SceneIDOutlines = preload("res://scripts/sera_scene_id_outlines.gd")
const GPUContours = preload("res://scripts/nexus_sera_gpu_convex_silhouette.gd")
const LAYER_NAME: String = "SeraIDOutlineLayer"
const COMPOSITOR_NAME: String = "SeraIDOutlineControl"

var _contour_enabled: bool = true
var _stroke_px: float = 3.0
var _nexus_sera_contact_mode: bool = false
var _compositor: Control
var _bittaran_gpu_silhouette: Node3D


func _ready() -> void:
    # SeraRig may still be under construction when ViewEdges enters the tree.
    # Add the viewport-owned CanvasLayer after the parent hierarchy settles.
    _register.call_deferred()


func _exit_tree() -> void:
    _release_bittaran_gpu_silhouette()
    if is_instance_valid(_compositor):
        _compositor.call("unregister_root", self)
    _compositor = null


func _release_bittaran_gpu_silhouette() -> void:
    if is_instance_valid(_bittaran_gpu_silhouette):
        _bittaran_gpu_silhouette.queue_free()
    _bittaran_gpu_silhouette = null


func _ensure_bittaran_gpu_silhouette(actor: Node3D) -> void:
    if is_instance_valid(_bittaran_gpu_silhouette):
        return
    # One cached ribbon controller per actual actor (SERA, Bittaran, turret).
    # Its generated meshes are children of each source MeshInstance3D and
    # inherit the very same frame's interpolated pose and camera projection.
    # The visible-ID pass alone owns the separate-mesh 2px contact seams.
    var gpu: Node3D = GPUContours.new()
    gpu.name = "SeraBittaranGPUSilhouette"
    gpu.set("enable_combat_gpu_full_edges", true)
    gpu.set("combat_silhouette_only", true)
    gpu.set("silhouette_inside_px", 0.0)
    gpu.set("silhouette_outside_px", 3.0)
    gpu.set("seam_stroke_px", 2.0)
    gpu.set("ink_render_priority", -31)
    gpu.set("overlay_name", "SeraBittaranGPUSilhouetteRibbons")
    actor.add_child(gpu)
    _bittaran_gpu_silhouette = gpu


# The Bittaran hybrid uses GPU only for paired front/back silhouette edges
# and shared depth-resolved visible IDs only for different-mesh seams.
static func _in_bittaran_id_scene(actor: Node3D) -> bool:
    var cursor: Node = actor
    while cursor != null:
        if bool(cursor.get_meta("sera_bittaran_id_outline", false)):
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
    var bittaran_hybrid: bool = _in_bittaran_id_scene(actor)
    _compositor.call("set_bittaran_id_mode", bittaran_hybrid)
    if bittaran_hybrid:
        _ensure_bittaran_gpu_silhouette(actor)
    else:
        _release_bittaran_gpu_silhouette()
    if _nexus_sera_contact_mode:
        _compositor.call("set_nexus_sera_contact_mode", true)
    else:
        _compositor.call("set_shared_scene_mode", true)
    _compositor.call("set_stroke_px", _stroke_px)


func set_contour_enabled(enabled: bool) -> void:
    if _contour_enabled == enabled:
        return
    _contour_enabled = enabled
    if not enabled:
        _release_bittaran_gpu_silhouette()
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

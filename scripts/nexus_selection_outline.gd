extends Control
# v127: thicker camera-projected contours with occlusion-safe gate line fragments.
# Selection lines only; CUSTOMIZE portrait's separate 3D radial backdrop is in CommandNexus.
var polygons: Dictionary = {}
# Optional open polylines after gate/SERA occlusion (only for DEPLOYMENT).
var clipped_strokes: Dictionary = {}
var active_target: String = ""
var hide_customize_preview_outline: bool = false
var pulse_time: float = 0.0
const OVERVIEW_STROKE_PX: float = 4.5
const FOCUSED_STROKE_PX: float = 5.0
const DIM_COLOR: Color = Color(0.35, 0.85, 0.98, 0.15)
const BRIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    # Only color/opacity oscillates each frame. The expensive polygon contour
    # is cached by the scene and recomputed solely on camera/viewport changes.
    if not is_visible_in_tree():
        return
    pulse_time = fposmod(pulse_time + delta, TAU / 3.6)
    queue_redraw()

func _draw() -> void:
    var blink := 0.5 + 0.5 * sin(pulse_time * 3.6)
    for name in polygons.keys():
        if not active_target.is_empty() and name != active_target:
            continue
        if hide_customize_preview_outline and name == "CUSTOMIZE":
            continue
        var selected: bool = name == active_target
        var stroke: Color = DIM_COLOR.lerp(BRIGHT_COLOR, blink)
        var thickness: float = FOCUSED_STROKE_PX if selected else OVERVIEW_STROKE_PX
        if clipped_strokes.has(name):
            # Already segmented along SERA's silhouette; never re-close these
            # lines or a diagonal border would appear through the foreground.
            var fragments: Array = clipped_strokes[name]
            for fragment in fragments:
                if fragment.size() >= 2:
                    draw_polyline(fragment, stroke, thickness, true)
        else:
            var contours: Array = polygons[name]
            for shape in contours:
                if shape.size() < 3:
                    continue
                var closed := PackedVector2Array(shape)
                closed.append(shape[0])
                draw_polyline(closed, stroke, thickness, true)

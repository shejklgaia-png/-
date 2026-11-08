extends Control
# v125: camera-projected silhouette targets. Pure CanvasItem strokes:
# no particles, bloom, full-screen flashes or postprocess effects.
var polygons: Dictionary = {}
var active_target: String = ""
var pulse_time: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    pulse_time += delta
    queue_redraw()

func _draw() -> void:
    for name in polygons.keys():
        if not active_target.is_empty() and name != active_target:
            continue
        var shape: PackedVector2Array = polygons[name]
        if shape.size() < 3:
            continue
        var selected: bool = name == active_target
        # In overview, all five silhouettes blink quietly in dark cyan.
        # Tapping a silhouette simply locks its border to a brighter shade.
        var pulse := 0.5 + 0.5 * sin(pulse_time * 2.8)
        var opacity := 0.98 if selected else 0.18 + 0.16 * pulse
        var stroke := Color(0.36, 0.88, 1.0, opacity)
        var shade := Color(0.012, 0.050, 0.085, 0.025 if selected else 0.045)
        draw_colored_polygon(shape, shade)
        var closed := PackedVector2Array(shape)
        closed.append(shape[0])
        draw_polyline(closed, stroke, 3.0 if selected else 2.0, true)

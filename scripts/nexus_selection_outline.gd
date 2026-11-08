extends Control
# v126: lightweight, camera-projected outlines of real Blockbench/SERA meshes.
# No cloned mesh instances, render passes, particles, glow or screen flashes.
var polygons: Dictionary = {}
var active_target: String = ""
var pulse_time: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    # Only color/opacity oscillates each frame. The expensive polygon contour
    # is cached by the scene and recomputed solely on camera/viewport changes.
    pulse_time += delta
    queue_redraw()

func _draw() -> void:
    var blink := 0.5 + 0.5 * sin(pulse_time * 3.6)
    for name in polygons.keys():
        if not active_target.is_empty() and name != active_target:
            continue
        var selected: bool = name == active_target
        var alpha := 0.98 if selected else 0.15 + 0.47 * blink
        var stroke := Color(0.35, 0.85, 0.98, alpha)
        var thickness := 3.0 if selected else 2.5
        var contours: Array = polygons[name]
        for shape in contours:
            if shape.size() < 3:
                continue
            var closed := PackedVector2Array(shape)
            closed.append(shape[0])
            draw_polyline(closed, stroke, thickness, true)

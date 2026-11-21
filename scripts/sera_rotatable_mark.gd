extends Control
## Small vector rotate cue; language/font independent and non-interactive.
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(28, 28)
    queue_redraw()

func _draw() -> void:
    var tint: Color = Color("#93c1cc")
    var center: Vector2 = size * 0.5
    var r: float = minf(size.x, size.y) * 0.28
    draw_arc(center, r, deg_to_rad(-65), deg_to_rad(225), 20, tint, 1.6, true)
    var tip: Vector2 = center + Vector2(
        cos(deg_to_rad(-65)), sin(deg_to_rad(-65))) * r
    draw_line(tip, tip + Vector2(-5.2, -0.4), tint, 1.6, true)
    draw_line(tip, tip + Vector2(-0.3, 5.0), tint, 1.6, true)

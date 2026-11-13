extends Control
## Geometric reticle glyph: independent of fonts and user lock mode.
func _draw() -> void:
    var center: Vector2 = size * 0.5
    var ink := Color(0.65, 0.94, 1.0, 0.95)
    draw_arc(center, 12.0, -PI * 0.25, PI * 1.25, 36, ink, 2.2, true)
    draw_arc(center, 12.0, PI * 0.75, PI * 2.25, 36, ink, 2.2, true)
    for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        draw_line(center + direction * 17.0,
            center + direction * 25.0, ink, 2.1, true)
    draw_circle(center, 2.5, ink)

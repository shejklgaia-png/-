extends Control
## Small reusable vector marker. No font glyphs, images or per-frame textures:
## favorite is an amber star; unwanted/discard is the same red bin everywhere.
var kind: String = "favorite":
    set(value):
        kind = value
        queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var side: float = minf(size.x, size.y)
    if side <= 0.0:
        return
    var center: Vector2 = size * 0.5
    var tint: Color = Color("#f6cd4f") if kind == "favorite" else Color("#fa6570")
    if kind == "favorite":
        var points := PackedVector2Array()
        for index in range(10):
            var radius: float = side * (0.44 if index % 2 == 0 else 0.205)
            var angle: float = -PI * 0.5 + float(index) * PI / 5.0
            points.append(center + Vector2(cos(angle), sin(angle)) * radius)
        draw_colored_polygon(points, tint)
    else:
        # Solid waste-bin silhouette: identical geometry for the item mark,
        # detail action and bulk disposal action.
        var x: float = center.x
        var y: float = center.y
        var unit: float = side / 24.0
        draw_rect(Rect2(x - 6.5 * unit, y - 5.0 * unit,
            13.0 * unit, 14.0 * unit), tint)
        draw_rect(Rect2(x - 8.0 * unit, y - 8.0 * unit,
            16.0 * unit, 2.3 * unit), tint)
        draw_rect(Rect2(x - 3.5 * unit, y - 10.5 * unit,
            7.0 * unit, 2.0 * unit), tint)
        var inset: Color = Color("#172431")
        for offset in [-2.9, 2.9]:
            draw_line(Vector2(x + offset * unit, y - 2.5 * unit),
                Vector2(x + offset * unit, y + 6.0 * unit),
                inset, maxf(1.0, 1.5 * unit), true)

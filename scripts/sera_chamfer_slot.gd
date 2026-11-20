@tool
extends PanelContainer
## Visible matte UI slot with beveled (cut-off) corners, including empty items.
var cut_size: float = 12.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    resized.connect(queue_redraw)
    queue_redraw()

func _border_points(dim: Vector2) -> PackedVector2Array:
    var w: float = maxf(1.0, dim.x)
    var h: float = maxf(1.0, dim.y)
    var k: float = minf(cut_size, minf(w, h) * 0.22)
    return PackedVector2Array([
        Vector2(k, 0), Vector2(w-k, 0), Vector2(w, k),
        Vector2(w, h-k), Vector2(w-k, h), Vector2(k, h),
        Vector2(0, h-k), Vector2(0, k), Vector2(k, 0)
    ])

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    var outline: PackedVector2Array = _border_points(size)
    var fill: PackedVector2Array = outline.slice(0, 8)
    draw_colored_polygon(fill, Color("#203747"))
    draw_polyline(outline, Color("#59c6da"), 2.0, true)

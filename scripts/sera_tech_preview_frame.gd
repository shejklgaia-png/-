extends Control
## Shared lightweight chamfered 2D rim for interactive previews.
## No input capture and no extra 3D render pass.
const FRAME: Color = Color("#6f93a3")
const CORNER: Color = Color("#9fd7e6")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
    queue_redraw()


func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w <= 34.0 or h <= 34.0:
        return
    var s: float = 2.0
    var cut: float = 12.0
    var rim := PackedVector2Array([
        Vector2(s + cut, s), Vector2(w - s - cut, s),
        Vector2(w - s, s + cut), Vector2(w - s, h - s - cut),
        Vector2(w - s - cut, h - s), Vector2(s + cut, h - s),
        Vector2(s, h - s - cut), Vector2(s, s + cut),
        Vector2(s + cut, s)
    ])
    draw_polyline(rim, FRAME, 1.6, true)
    # The same restrained top-left / bottom-right technical accents
    # used by SERA equipment icon outlines.
    draw_line(Vector2(s + cut + 6.0, s),
        Vector2(s + cut + 34.0, s), CORNER, 2.6, true)
    draw_line(Vector2(s, s + cut + 6.0),
        Vector2(s, s + cut + 29.0), CORNER, 2.6, true)
    draw_line(Vector2(w - s - cut - 34.0, h - s),
        Vector2(w - s - cut - 6.0, h - s), CORNER, 2.6, true)
    draw_line(Vector2(w - s, h - s - cut - 29.0),
        Vector2(w - s, h - s - cut - 6.0), CORNER, 2.6, true)

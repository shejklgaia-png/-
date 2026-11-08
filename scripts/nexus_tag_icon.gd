extends Control
# v120: five small vector icons shared by the read-only base signplates.
const BLUE := Color("#6bddfa")
var kind: String = ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(36, 36)
    size = Vector2(36, 36)
    queue_redraw()

func _draw() -> void:
    match kind:
        "TRAINING":
            draw_arc(Vector2(18, 18), 12, 0.0, TAU, 36, BLUE, 2.0)
            draw_arc(Vector2(18, 18), 5.0, 0.0, TAU, 24, BLUE, 2.0)
            draw_line(Vector2(18, 0), Vector2(18, 9), BLUE, 2.0)
            draw_line(Vector2(18, 27), Vector2(18, 36), BLUE, 2.0)
            draw_line(Vector2(0, 18), Vector2(9, 18), BLUE, 2.0)
            draw_line(Vector2(27, 18), Vector2(36, 18), BLUE, 2.0)
        "DATA ARCHIVE":
            for y in [8.0, 17.0, 26.0]:
                draw_arc(Vector2(18, y), 11.5, 0.0, TAU, 32, BLUE, 2.0)
            draw_line(Vector2(6.5, 8), Vector2(6.5, 26), BLUE, 1.7)
            draw_line(Vector2(29.5, 8), Vector2(29.5, 26), BLUE, 1.7)
        "DEPLOYMENT":
            draw_line(Vector2(6, 33), Vector2(6, 9), BLUE, 3.0)
            draw_line(Vector2(30, 33), Vector2(30, 9), BLUE, 3.0)
            draw_line(Vector2(6, 9), Vector2(18, 2), BLUE, 3.0)
            draw_line(Vector2(30, 9), Vector2(18, 2), BLUE, 3.0)
            draw_line(Vector2(13, 34), Vector2(13, 12), BLUE, 2.0)
            draw_line(Vector2(23, 34), Vector2(23, 12), BLUE, 2.0)
        "SYSTEM":
            draw_arc(Vector2(18, 18), 10.5, 0.0, TAU, 32, BLUE, 4.0)
            draw_arc(Vector2(18, 18), 4, 0.0, TAU, 24, BLUE, 3.0)
            for i in range(8):
                var a := TAU * float(i) / 8.0
                draw_line(Vector2(18, 18) + Vector2(cos(a), sin(a)) * 12,
                    Vector2(18, 18) + Vector2(cos(a), sin(a)) * 17, BLUE, 4.0)
        "CUSTOMIZE":
            draw_rect(Rect2(13, 3, 10, 9), BLUE, true)
            draw_rect(Rect2(9, 14, 18, 9), BLUE, true)
            draw_rect(Rect2(2, 15, 6, 12), BLUE, true)
            draw_rect(Rect2(28, 15, 6, 12), BLUE, true)
            draw_rect(Rect2(10, 25, 6, 10), BLUE, true)
            draw_rect(Rect2(20, 25, 6, 10), BLUE, true)

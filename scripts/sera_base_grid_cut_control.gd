extends Control
## Procedural, texture-free chamfered SERA UI: large mode plate, module and
## bare wireframe operation icons. No emoji/fallback icon glyphs.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")

signal activated(code: String)

var variant: String = "title"
var code: String = ""
var caption: String = ""
var selected: bool = false


func configure(kind: String, value: String, subtitle: String = "") -> void:
    variant = kind
    code = value
    caption = subtitle
    mouse_filter = Control.MOUSE_FILTER_IGNORE if kind == "title" else (
        Control.MOUSE_FILTER_STOP)
    focus_mode = Control.FOCUS_NONE
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if variant == "title":
        return
    var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (
        event is InputEventMouseButton and event.pressed and
        event.button_index == MOUSE_BUTTON_LEFT)
    if tapped:
        activated.emit(code)
        accept_event()


func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    var active: Color = Color("#9dcede") if selected else Color("#688c9d")
    var ink: Color = Color("#e1edf3") if selected else Color("#bacdd7")
    if variant == "title":
        # Cut corners, flat matte fill and a thin blue-grey industrial seam.
        var cut: float = 22.0
        var corners := PackedVector2Array([
            Vector2(0.0, 0.0), Vector2(w - cut, 0.0),
            Vector2(w, cut), Vector2(w, h - 2.0),
            Vector2(cut * 0.48, h - 2.0), Vector2(0.0, h - cut * 0.48),
        ])
        draw_colored_polygon(corners, Color("#122633"))
        draw_polyline(PackedVector2Array([
            corners[0], corners[1], corners[2], corners[3],
            corners[4], corners[5], corners[0],
        ]), Color("#55798a"), 1.4, true)
        draw_line(Vector2(15.0, h - 10.0),
            Vector2(w * 0.53, h - 10.0), Color("#55798a"), 1.0)
        draw_string(LaboSkin.title_font(), Vector2(20.0, h * 0.65),
            code, HORIZONTAL_ALIGNMENT_LEFT, w - 30.0, 42,
            Color("#dfeaf0"))
        draw_string(LaboSkin.ui_font(), Vector2(w - 94.0, h * 0.70),
            caption, HORIZONTAL_ALIGNMENT_LEFT, 78.0, 16,
            Color("#a7bdcb"))
        return
    if variant == "module":
        var cut: float = 11.0
        var outline := PackedVector2Array([
            Vector2(2, 2), Vector2(w - cut, 2), Vector2(w - 2, cut),
            Vector2(w - 2, h - 2), Vector2(2, h - 2), Vector2(2, 2),
        ])
        draw_colored_polygon(PackedVector2Array([
            Vector2(2, 2), Vector2(w - cut, 2), Vector2(w - 2, cut),
            Vector2(w - 2, h - 2), Vector2(2, h - 2),
        ]), Color("#233e4d") if selected else Color("#152b39"))
        draw_polyline(outline, active if selected else Color("#456475"),
            1.4, true)
        draw_string(LaboSkin.title_font(), Vector2(0, h * 0.62), code,
            HORIZONTAL_ALIGNMENT_CENTER, w, 30, ink)
        draw_string(LaboSkin.data_font(), Vector2(0, h - 7.0),
            caption, HORIZONTAL_ALIGNMENT_CENTER, w, 10,
            Color("#91aab9"))
        if selected:
            draw_line(Vector2(13, h - 3), Vector2(w - 13, h - 3),
                Color("#91d1db"), 2.0)
        return

    # Right-hand tools are glyphs ONLY: no filled/background rectangle.
    var center := Vector2(w * 0.5, h * 0.39)
    var c: Color = Color("#a9dbe5") if selected else Color("#a2b9c7")
    var r: float = 15.0
    match code:
        "PLACE":
            draw_line(center + Vector2(-r, 0), center + Vector2(r, 0),
                c, 2.7, true)
            draw_line(center + Vector2(0, -r), center + Vector2(0, r),
                c, 2.7, true)
            draw_circle(center, 3.4, c)
            for a in [-1.0, 1.0]:
                draw_line(center + Vector2(a * 23.0, -8),
                    center + Vector2(a * 23.0, 8), c, 1.4)
        "MOVE":
            draw_line(center + Vector2(-19, 0), center + Vector2(19, 0),
                c, 2.2, true)
            draw_line(center + Vector2(0, -19), center + Vector2(0, 19),
                c, 2.2, true)
            for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
                var tip: Vector2 = center + d * 21.0
                var wing := Vector2(-d.y, d.x) * 5.5
                draw_line(tip, tip - d * 8.0 + wing, c, 2.0, true)
                draw_line(tip, tip - d * 8.0 - wing, c, 2.0, true)
        "ROTATE":
            draw_arc(center, 16.5, -PI * 0.80, PI * 0.67, 24,
                c, 2.6, true)
            var tip := center + Vector2(cos(PI * 0.67), sin(PI * 0.67)) * 16.5
            draw_line(tip, tip + Vector2(-9, -1), c, 2.5, true)
            draw_line(tip, tip + Vector2(-2, -9), c, 2.5, true)
            draw_circle(center, 3.0, c)
        "REMOVE":
            draw_line(center + Vector2(-13, -13), center + Vector2(13, 13), c, 2.7, true)
            draw_line(center + Vector2(13, -13), center + Vector2(-13, 13), c, 2.7, true)
    draw_string(LaboSkin.ui_font(), Vector2(0, h - 6.0), caption,
        HORIZONTAL_ALIGNMENT_CENTER, w, 12, ink)
    if selected:
        draw_line(Vector2(w * 0.29, h - 1.0),
            Vector2(w * 0.71, h - 1.0), Color("#8ccbd8"), 2.0)

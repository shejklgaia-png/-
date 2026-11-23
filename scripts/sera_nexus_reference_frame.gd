extends Control
# Decorative COMMAND NEXUS header/footer matching the reference image.
# Kept outside all 3D hit areas, with no input interception or extra viewport.
const Skin = preload("res://scripts/sera_labo_round_skin.gd")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _fill(points: PackedVector2Array, tint: Color) -> void:
    draw_colored_polygon(points, tint)

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w <= 0.0 or h <= 0.0:
        return
    var s: float = w / 720.0
    var steel := Color("#172531")
    var plate := Color("#24394a")
    var pale := Color("#daf4ff")
    var accent := Color("#4bd5ff")
    # Stepped industrial banner; allow title and game version to breathe.
    _fill(PackedVector2Array([
        Vector2(0, 9*s), Vector2(218*s, 9*s),
        Vector2(249*s, 39*s), Vector2(410*s, 39*s),
        Vector2(437*s, 59*s), Vector2(w, 59*s),
        Vector2(w, 102*s), Vector2(0, 102*s)
    ]), steel)
    _fill(PackedVector2Array([
        Vector2(0, 13*s), Vector2(216*s, 13*s),
        Vector2(244*s, 44*s), Vector2(406*s, 44*s),
        Vector2(432*s, 64*s), Vector2(w, 64*s),
        Vector2(w, 88*s), Vector2(0, 88*s)
    ]), plate)
    draw_line(Vector2(0, 106*s), Vector2(w, 106*s), accent.darkened(0.60), 1.0*s)
    for i in range(5):
        var xx: float = (24.0 + float(i)*12.0)*s
        draw_line(Vector2(xx, 61*s), Vector2(xx+13*s, 30*s),
            pale, 4*s)
    var font: Font = Skin.display_font()
    draw_string(font, Vector2(97*s, 58*s), "SERA",
        HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(14, int(38*s)), pale)
    draw_string(font, Vector2(98*s, 79*s), "COMMAND NEXUS",
        HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(14*s)), pale)
    for i in range(4):
        var x: float = w-(100.0-float(i)*18.0)*s
        draw_line(Vector2(x, 86*s), Vector2(x+12*s, 86*s),
            accent, 4*s)
    # A slim industrial bottom bevel leaves the existing exit button untouched.
    _fill(PackedVector2Array([
        Vector2(0,h-28*s), Vector2(148*s,h-28*s),
        Vector2(165*s,h-11*s), Vector2(0,h-11*s)
    ]), plate)
    _fill(PackedVector2Array([
        Vector2(w-185*s,h-11*s), Vector2(w-160*s,h-35*s),
        Vector2(w,h-35*s), Vector2(w,h-11*s)
    ]), steel)
    for i in range(5):
        var x: float = (17.0 + float(i)*21.0)*s
        draw_line(Vector2(x,h-19*s), Vector2(x+12*s,h-19*s),
            Color("#e9b644"), 6*s)
    for i in range(5):
        var x: float = w-(146.0 - float(i)*21.0)*s
        draw_line(Vector2(x,h-28*s), Vector2(x+12*s,h-28*s),
            Color("#e9b644"), 6*s)

extends Control
## Engine-native 2D startup streak. No texture imports, shader compilation,
## fonts, 3D effects, or per-frame node allocation on Android first boot.
const LOOP_SECONDS: float = 0.78
const SEGMENTS: int = 20

var phase: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    # At both loop endpoints the whole streak is outside the viewport;
    # the reset cannot flash or suddenly teleport across the visible line.
    phase = fposmod(phase + maxf(delta, 0.0), LOOP_SECONDS)
    queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var w: float = size.x
    var cy: float = size.y * 0.575
    var width: float = w * 0.225
    var x: float = lerpf(-width * 1.2, w + width * 1.2, phase / LOOP_SECONDS)
    # Dim technical rail anchors the animation without hiding the title.
    draw_line(Vector2(w * 0.13, cy), Vector2(w * 0.87, cy),
        Color("#24465c", 0.40), 1.0, true)
    # Four tapered translucent hulls: cold blue halo -> cyan -> icy core -> white.
    _draw_streak(x, cy, width * 1.15, 15.0, Color("#125db6"), 0.15)
    _draw_streak(x, cy, width * 1.05, 8.0, Color("#209dff"), 0.62)
    _draw_streak(x, cy, width * 0.88, 3.4, Color("#b3e8ff"), 0.87)
    _draw_streak(x, cy, width * 0.68, 1.65, Color("#ffffff"), 0.99)

func _draw_streak(cx: float, cy: float, half_width: float,
        half_height: float, tint: Color, opacity: float) -> void:
    var vertices := PackedVector2Array()
    var colors := PackedColorArray()
    # A shared contour for top and bottom.  Both tips converge to height 0,
    # and per-vertex opacity fades into the blue at the narrowing ends.
    for i in range(SEGMENTS + 1):
        var t: float = float(i) / float(SEGMENTS)
        var longitudinal: float = 2.0 * t - 1.0
        var taper: float = pow(maxf(0.0, 1.0 - absf(longitudinal)), 1.32)
        vertices.append(Vector2(cx + longitudinal * half_width, cy - half_height * taper))
        colors.append(Color(tint.r, tint.g, tint.b, opacity * taper))
    for i in range(SEGMENTS, -1, -1):
        var t: float = float(i) / float(SEGMENTS)
        var longitudinal: float = 2.0 * t - 1.0
        var taper: float = pow(maxf(0.0, 1.0 - absf(longitudinal)), 1.32)
        vertices.append(Vector2(cx + longitudinal * half_width, cy + half_height * taper))
        colors.append(Color(tint.r, tint.g, tint.b, opacity * taper))
    draw_polygon(vertices, colors)

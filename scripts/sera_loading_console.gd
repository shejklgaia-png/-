extends Control
## SERA / shared system loading terminal.
## Live mode is driven only by completed boot tasks.  The 5s simulation is
## explicitly opt-in from BASE; it never replaces a real loading metric.
signal preview_finished

const PREVIEW_SECONDS: float = 5.0
const PREVIEW_STEPS: int = 100
const MAX_HISTORY: int = 120
const PREVIEW_MESSAGES = [
    "CORE / RESONANCE VERIFIED",
    "SHELL / GEOMETRY INDEXED",
    "OS / SYNCHRONIZER HANDSHAKE",
    "NEXUS / UPLINK STABLE",
    "GRID / CONDUCTOR LINKED",
    "LAB / FABRICATOR ONLINE",
    "ARCHIVE / MEMORY CHECK",
    "CRATE / SIGNAL CONFIRMED",
    "SHELL / ACTUATOR READY",
    "CORE / ENERGY PATH OPEN",
    "OS / INTEGRITY VERIFIED",
    "WORLD / SECTOR STREAM READY"
]

var percent: int = 0
var history: Array[String] = []
var preview_elapsed: float = 0.0
var preview_running: bool = false
var preview_hold: float = -1.0
var noise_elapsed: float = 0.0
var noise_phase: int = 0
var electronic_texture: Texture2D
var screen_font: Font

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    screen_font = ThemeDB.fallback_font
    _create_electronic_texture()
    resized.connect(queue_redraw)
    if history.is_empty():
        set_stage("BOOT / SYSTEM LINK OPEN", 0)
    set_process(true)

func set_cyber_font(font: Font) -> void:
    if font != null:
        screen_font = font
        queue_redraw()

func set_stage(message: String, completed_percent: int) -> void:
    var next_percent: int = clampi(completed_percent, 0, 100)
    if next_percent < percent:
        return
    if next_percent == percent and not history.is_empty() and history.back() == message:
        return
    percent = next_percent
    history.push_back(message)
    while history.size() > MAX_HISTORY:
        history.pop_front()
    queue_redraw()

func start_preview() -> void:
    # Preview progress is fake by design; the live path never calls this.
    preview_elapsed = 0.0
    preview_running = true
    preview_hold = -1.0
    percent = 0
    history.clear()
    set_stage(_preview_message(0), 0)
    set_process(true)

func _preview_message(point: int) -> String:
    var index: int = (maxi(point, 1) - 1) % PREVIEW_MESSAGES.size()
    if point == 0:
        return "CORE / DEMO SESSION START"
    if point == PREVIEW_STEPS:
        return "SYSTEM / SIMULATION COMPLETE"
    return "%s / %03d" % [PREVIEW_MESSAGES[index], point]

func _process(delta: float) -> void:
    var dt: float = maxf(delta, 0.0)
    noise_elapsed += dt
    if noise_elapsed >= 0.055:
        noise_elapsed = fposmod(noise_elapsed, 0.055)
        noise_phase += 1
        queue_redraw()
    if preview_running:
        preview_elapsed = minf(PREVIEW_SECONDS, preview_elapsed + dt)
        var target: int = mini(PREVIEW_STEPS,
            int(floor(preview_elapsed * float(PREVIEW_STEPS) / PREVIEW_SECONDS + 0.00001)))
        # Every 50 ms is one independent log tick, even after a slow frame.
        for point in range(percent + 1, target + 1):
            set_stage(_preview_message(point), point)
        if target == PREVIEW_STEPS:
            preview_running = false
            preview_hold = 0.15  # Briefly show 100% before returning to BASE.
    elif preview_hold >= 0.0:
        preview_hold -= dt
        if preview_hold < 0.0:
            preview_hold = -1.0
            preview_finished.emit()
            set_process(false)

func _create_electronic_texture() -> void:
    # Small, deterministic, CPU-generated screen texture.  Never import an
    # external resource or instantiate a ShaderMaterial on Android first boot.
    var screen_image: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
    screen_image.fill(Color(0.0, 0.0, 0.0, 0.0))
    for y in range(96):
        for x in range(96):
            var v: int = (x * 41 + y * 71 + x * y * 13) % 251
            if y % 6 == 0 and (x + y) % 7 < 5:
                screen_image.set_pixel(x, y, Color(0.33, 0.73, 0.96, 0.090))
            elif v < 15:
                screen_image.set_pixel(x, y, Color(0.59, 0.85, 0.99, 0.065))
            elif x % 23 == 0 and y % 11 < 6:
                screen_image.set_pixel(x, y, Color(0.15, 0.47, 0.62, 0.060))
    electronic_texture = ImageTexture.create_from_image(screen_image)

func _draw() -> void:
    if size.x < 120.0 or size.y < 180.0:
        return
    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color("#1b303e"))
    if electronic_texture != null:
        draw_texture_rect(electronic_texture, Rect2(Vector2.ZERO, size),
            true, Color(1.0, 1.0, 1.0, 0.85))
    # Fixed scanlines plus changing granular noise: no traveling horizontal band.
    for y in range(0, int(h), 7):
        draw_line(Vector2(0, y), Vector2(w, y),
            Color("#05131e", 0.15), 1.0)
    for n in range(18):
        var fx: float = float((n * 137 + noise_phase * 41) % maxi(1, int(w)))
        var fy: float = float((n * 293 + noise_phase * 19) % maxi(1, int(h)))
        draw_rect(Rect2(fx, fy, float(2 + n % 5), 1.0),
            Color("#b6eeff", 0.040 + float(n % 3) * 0.026))
    _draw_frame(w, h)
    _draw_readout(w, h)

func _draw_frame(w: float, h: float) -> void:
    var m: float = 20.0
    var cut: float = 17.0
    var edge := PackedVector2Array([
        Vector2(m + cut, m), Vector2(w - m - cut, m),
        Vector2(w - m, m + cut), Vector2(w - m, h - m - cut),
        Vector2(w - m - cut, h - m), Vector2(m + cut, h - m),
        Vector2(m, h - m - cut), Vector2(m, m + cut),
        Vector2(m + cut, m)
    ])
    draw_polyline(edge, Color("#55798a", 0.95), 1.5, true)
    draw_line(Vector2(m + cut, 107.0), Vector2(w - m - cut, 107.0),
        Color("#55798a", 0.73), 1.0)
    # Corner markers and angular blue-grey hardware rails, as used by SERA UI.
    for side in [m, w - m]:
        var dir: float = 1.0 if side == m else -1.0
        draw_line(Vector2(side, 55.0), Vector2(side + dir * 11.0, 55.0),
            Color("#9edfff", 0.70), 2.0)
        draw_line(Vector2(side, h - 99.0), Vector2(side + dir * 16.0, h - 99.0),
            Color("#9edfff", 0.70), 2.0)
    var rail_y: float = h - 72.0
    var left: float = m + 24.0
    var usable: float = w - left - m - 24.0
    draw_rect(Rect2(left, rail_y, usable, 10.0), Color("#0a1c28", 0.70))
    for step in range(PREVIEW_STEPS):
        var x: float = left + usable * float(step) / float(PREVIEW_STEPS)
        var span: float = maxf(1.0, usable / float(PREVIEW_STEPS) - 1.2)
        var tint: Color = (Color("#a7efff") if step < percent
            else Color("#55798a", 0.24))
        draw_rect(Rect2(x, rail_y + 1.0, span, 8.0), tint)
    draw_line(Vector2(left, rail_y + 13.0), Vector2(left + usable, rail_y + 13.0),
        Color("#55798a", 0.25), 1.0)

func _draw_text(message: String, at: Vector2, font_size: int,
        color: Color, glow: bool = false) -> void:
    if screen_font == null:
        return
    if glow:
        draw_string(screen_font, at + Vector2(1.0, 0.0), message,
            HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
            Color("#47c9ff", 0.40))
        draw_string(screen_font, at + Vector2(-1.0, 0.0), message,
            HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
            Color("#47c9ff", 0.28))
    draw_string(screen_font, at, message, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, font_size, color)

func _draw_readout(w: float, h: float) -> void:
    var compact: bool = w < 510.0
    _draw_text("SERA // OMNI SYNCHRONIZER", Vector2(42.0, 68.0),
        22 if compact else 29, Color("#d3f4ff"), true)
    _draw_text("CORE LINK  /  SHELL BUS  /  OS", Vector2(43.0, 94.0),
        13 if compact else 16, Color("#6e9db2"))
    var latest_y: float = h - 122.0
    var first_x: float = 42.0
    var count: int = mini(history.size() - 1, 9)
    for i in range(count):
        var index: int = history.size() - 2 - i
        var alpha: float = maxf(0.17, 0.62 - float(i) * 0.052)
        var previous: String = history[index]
        var previous_y: float = latest_y - 63.0 - float(i) * 39.0
        _draw_text("> " + previous, Vector2(first_x, previous_y),
            15 if compact else 19, Color(0.48, 0.73, 0.83, alpha))
    var latest: String = history.back() if not history.is_empty() else "BOOT"
    # Reserve the right-hand corner for the 0–100 numerical readout.
    var available: float = maxf(120.0, w - 205.0)
    var fitted: String = latest
    var max_chars: int = maxi(10, int(available / (14.7 if compact else 16.6)))
    if fitted.length() > max_chars:
        fitted = fitted.substr(0, max_chars - 2) + ".."
    _draw_text("> " + fitted, Vector2(first_x, latest_y),
        20 if compact else 27, Color("#e5fbff"), true)
    _draw_text("%03d%%" % percent, Vector2(w - (142.0 if compact else 172.0),
        latest_y + 4.0), 39 if compact else 50, Color("#efffff"), true)
    draw_line(Vector2(first_x, latest_y + 19.0),
        Vector2(w - 45.0, latest_y + 19.0), Color("#55798a", 0.62), 1.0)
    _draw_text("LINK %s   /   STREAM ACTIVE" % ("OK" if percent == 100 else "SYNC"),
        Vector2(43.0, h - 37.0), 13 if compact else 16, Color("#85bfd7"))

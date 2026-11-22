extends Control
## SERA / shared system loading terminal.
## Live mode is driven only by completed boot tasks.  The 5s simulation is
## explicitly opt-in from BASE; it never replaces a real loading metric.
signal preview_finished

const TerminalPixelFont = preload("res://scripts/sera_terminal_pixel_font.gd")

const PREVIEW_SECONDS: float = 5.0
const PREVIEW_STEPS: int = 100
const MAX_HISTORY: int = 120
# Loading terminal only: live loading remains at 50%; BASE previews may use
# two lower internal raster resolutions without changing gameplay or UI sizes.
const CONSOLE_RENDER_SCALE: float = 0.5
const PREVIEW_RENDER_SCALE_1: float = 0.375
const PREVIEW_RENDER_SCALE_2: float = 0.25
# Every activation is keyed to a completed BASE loading milestone.
const SYSTEM_PHASE_THRESHOLDS = {
    "CORE": 18, "NEXUS": 33, "LAB": 49, "GRID": 67,
    "ARCHIVE": 79, "SHELL": 86, "CRATE": 92, "OS": 99,
}
const SYSTEM_NODE_ORDER = [
    "CORE", "SHELL", "OS", "NEXUS", "GRID", "LAB", "ARCHIVE", "CRATE"
]
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
var anim_time: float = 0.0
var visual_elapsed: float = 0.0
var electronic_texture: Texture2D
var screen_font: Font
var pixel_font_atlas: Texture2D
var pixel_source_mode: bool = false
var console_render_scale: float = CONSOLE_RENDER_SCALE
var pixel_viewport: SubViewport
var pixel_source: Control
var pixel_output: TextureRect

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE if pixel_source_mode else Control.MOUSE_FILTER_STOP
    screen_font = ThemeDB.fallback_font
    if pixel_source_mode:
        # Font and procedural noise stay inside this overlay, never in gameplay.
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
        pixel_font_atlas = TerminalPixelFont.make_atlas()
        _create_electronic_texture()
        resized.connect(queue_redraw)
    else:
        _setup_pixel_renderer()
        resized.connect(_resize_pixel_renderer)
    if history.is_empty():
        set_stage("BOOT / SYSTEM LINK OPEN", 0)
    # The offscreen CanvasItem never runs another timer or preview.
    set_process(not pixel_source_mode)

func set_render_scale(scale_value: float) -> void:
    # Preview-only quality selection. Real loading keeps CONSOLE_RENDER_SCALE.
    # The offscreen replica never changes the controller's render scale.
    if pixel_source_mode:
        return
    console_render_scale = clampf(scale_value, PREVIEW_RENDER_SCALE_2, CONSOLE_RENDER_SCALE)
    _resize_pixel_renderer()

func _setup_pixel_renderer() -> void:
    # An offscreen SubViewport rasterizes the unchanged 720x1280 layout at the
    # selected scale. Only this loading overlay is sampled; gameplay is not.
    pixel_viewport = SubViewport.new()
    pixel_viewport.name = "TerminalLowResViewport"
    pixel_viewport.disable_3d = true
    pixel_viewport.transparent_bg = false
    pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(pixel_viewport)

    var script_source: GDScript = get_script() as GDScript
    pixel_source = script_source.new() as Control
    pixel_source.name = "TerminalLowResCanvas"
    pixel_source.set("pixel_source_mode", true)
    pixel_viewport.add_child(pixel_source)
    pixel_source.scale = Vector2(console_render_scale, console_render_scale)

    pixel_output = TextureRect.new()
    pixel_output.name = "TerminalLowResOutput"
    pixel_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pixel_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pixel_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pixel_output.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(pixel_output)
    pixel_output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pixel_output.texture = pixel_viewport.get_texture()
    _resize_pixel_renderer()

func _resize_pixel_renderer() -> void:
    if pixel_source_mode or pixel_viewport == null or pixel_source == null:
        return
    var render_width: int = maxi(1, int(ceilf(size.x * console_render_scale)))
    var render_height: int = maxi(1, int(ceilf(size.y * console_render_scale)))
    pixel_viewport.size = Vector2i(render_width, render_height)
    # Keep existing absolute UI coordinates and font sizes; scale only when
    # rasterizing into the viewport. This is not a gameplay viewport resize.
    pixel_source.size = size
    pixel_source.set("console_render_scale", console_render_scale)
    pixel_source.scale = Vector2(console_render_scale, console_render_scale)
    _queue_console_redraw()

func _queue_console_redraw() -> void:
    if pixel_source_mode:
        queue_redraw()
        return
    if pixel_source == null:
        return
    # State is owned by the actual/loading presenter, never independently
    # simulated by the low-res visual replica.
    pixel_source.set("percent", percent)
    pixel_source.set("history", history.duplicate())
    pixel_source.set("noise_phase", noise_phase)
    pixel_source.set("anim_time", anim_time)
    pixel_source.set("screen_font", screen_font)
    pixel_source.queue_redraw()

func set_cyber_font(font: Font) -> void:
    if font != null:
        screen_font = font
        _queue_console_redraw()

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
    _queue_console_redraw()

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
    # Cosmetic animation may run independently, but never advances progress.
    anim_time += dt
    visual_elapsed += dt
    if visual_elapsed >= 1.0 / 30.0:
        visual_elapsed = fposmod(visual_elapsed, 1.0 / 30.0)
        _queue_console_redraw()
    noise_elapsed += dt
    if noise_elapsed >= 0.055:
        noise_elapsed = fposmod(noise_elapsed, 0.055)
        noise_phase += 1
        _queue_console_redraw()
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
    if not pixel_source_mode:
        return  # The presenter must never draw a full-resolution duplicate.
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
    _draw_system_visual(w, h)
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

func _system_node_online(label: String) -> bool:
    return percent >= int(SYSTEM_PHASE_THRESHOLDS.get(label, 101))

func _system_visual_bounds(w: float, h: float) -> Rect2:
    # Separate the 3 animated zones from the existing terminal log and HUD.
    var top: float = 154.0 if h >= 940.0 else 120.0
    var scale: float = clampf((h - 800.0) / 480.0, 0.0, 1.0)
    var bottom: float = h - (290.0 + 240.0 * scale)
    return Rect2(Vector2(28.0, top),
        Vector2(maxf(0.0, w - 56.0), maxf(0.0, bottom - top)))

func _visible_history_count(h: float) -> int:
    # Old log lines stop before the illustration instead of overlapping it.
    var first_line: float = h - 185.0
    var free_space: float = first_line - _system_visual_bounds(size.x, h).end.y - 23.0
    return mini(9, maxi(0, int(floor(free_space / 39.0)) + 1))

func _draw_system_visual(w: float, h: float) -> void:
    if w < 330.0 or h < 620.0:
        return
    var bounds: Rect2 = _system_visual_bounds(w, h)
    var center := Vector2(w * 0.5, bounds.position.y + bounds.size.y * 0.52)
    var radius: float = minf(125.0, minf(w * 0.17, bounds.size.y * 0.23))
    var diagram_title: String = "CORE // SYSTEM INTEGRITY" if w >= 510.0 else "CORE // STATUS"
    _draw_text(diagram_title, Vector2(43.0, bounds.position.y + 17.0),
        14 if w >= 510.0 else 12, Color("#7fb6cf", 0.86))
    _draw_system_nodes(center, radius, true)
    _draw_core_visual(center, radius)
    _draw_system_nodes(center, radius, false)
    _draw_diagnostics(w, bounds)

func _draw_core_visual(center: Vector2, radius: float) -> void:
    var pulse: float = 1.0 + 0.055 * sin(anim_time * 2.6)
    var core_r: float = radius * 0.225 * pulse
    for layer in range(5, 0, -1):
        draw_circle(center, core_r + float(layer) * 8.0,
            Color("#41bbff", 0.018 + float(6 - layer) * 0.015))
    var hexagon := PackedVector2Array()
    for point in range(7):
        var angle: float = TAU * float(point) / 6.0 - PI / 6.0
        hexagon.append(center + Vector2(cos(angle), sin(angle)) * core_r * 1.47)
    draw_polyline(hexagon, Color("#9aebff", 0.73), 1.6, true)
    draw_circle(center, core_r, Color("#85defa", 0.42))
    draw_circle(center, core_r * 0.72, Color("#d5f9ff", 0.91))
    draw_circle(center, core_r * 0.40, Color("#ffffff", 0.98))
    # Broken rings, separate angular velocities, no horizontal sweep lines.
    for ring in range(3):
        var ring_r: float = radius * (0.53 + float(ring) * 0.235)
        var segments: int = 5 + ring * 3
        var speed: float = 0.66 if ring == 0 else (-0.43 if ring == 1 else 0.27)
        var stroke: float = 3.5 if ring == 0 else (2.7 if ring == 1 else 1.9)
        var tint: Color = Color("#b9f3ff", 0.93) if ring == 0 else (
            Color("#6fdcff", 0.70) if ring == 1 else Color("#55798a", 0.79))
        for piece in range(segments):
            var start: float = TAU * float(piece) / float(segments) + anim_time * speed
            draw_arc(center, ring_r, start,
                start + TAU / float(segments) * 0.64, 12, tint, stroke, true)

func _system_node_positions(center: Vector2, r: float) -> Array[Vector2]:
    var span: float = r + 36.0
    return [
        center + Vector2(0.0, -r - 47.0),
        center + Vector2(-span, -r * 0.47),
        center + Vector2(span, -r * 0.47),
        center + Vector2(-span, r * 0.27),
        center + Vector2(span, r * 0.27),
        center + Vector2(-r * 0.77, r + 52.0),
        center + Vector2(0.0, r + 57.0),
        center + Vector2(r * 0.77, r + 52.0),
    ]

func _draw_system_nodes(center: Vector2, radius: float, wires_only: bool) -> void:
    var positions: Array[Vector2] = _system_node_positions(center, radius)
    for i in range(SYSTEM_NODE_ORDER.size()):
        var label: String = str(SYSTEM_NODE_ORDER[i])
        var point: Vector2 = positions[i]
        var active: bool = _system_node_online(label)
        if wires_only:
            draw_line(center, point,
                Color("#6bd9f5", 0.48) if active else Color("#55798a", 0.25), 1.2)
            continue
        draw_circle(point, 8.0, Color("#152c3b", 0.97))
        draw_circle(point, 5.0, Color("#b9f2ff") if active else Color("#446475"))
        if active:
            draw_arc(point, 11.0, 0.0, TAU, 16, Color("#74dfff", 0.36), 1.7, true)
        var font_size: int = 12 if size.x >= 510.0 else 10
        # At extremely narrow 25%-raster previews, abbreviate only the
        # decorative node captions; the underlying system IDs never change.
        var caption: String = label
        if size.x < 510.0 and console_render_scale < 0.4:
            caption = {"SHELL": "SHL", "NEXUS": "NXS",
                "ARCHIVE": "ARC", "CRATE": "CRT"}.get(label, label)
        var text_w: float = _pixel_text_width(caption, font_size)
        _draw_text(caption, point + Vector2(-text_w * 0.5, 22.0),
            font_size, Color("#d5f7ff") if active else Color("#698ea0", 0.75))

func _draw_diagnostics(w: float, bounds: Rect2) -> void:
    var panel_w: float = minf(128.0, maxf(64.0, w * 0.20 - 20.0))
    var panel_h: float = minf(222.0, maxf(138.0, bounds.size.y * 0.43))
    var y: float = bounds.position.y + minf(88.0, bounds.size.y * 0.23)
    _draw_diag_panel(Rect2(35.0, y, panel_w, panel_h), 0)
    _draw_diag_panel(Rect2(w - panel_w - 35.0, y, panel_w, panel_h), 1)

func _draw_diag_panel(rect: Rect2, mode: int) -> void:
    draw_rect(rect, Color("#0b1f2c", 0.68))
    draw_rect(rect, Color("#55798a", 0.62), false, 1.0)
    var title: String = "CORE / DIAG" if mode == 0 else "BUS / DIAG"
    if _pixel_text_width(title, 12) > rect.size.x - 16.0:
        title = "CORE" if mode == 0 else "BUS"
    if _pixel_text_width(title, 10) > rect.size.x - 16.0:
        title = "C" if mode == 0 else "B"
    _draw_text(title, rect.position + Vector2(8.0, 19.0),
        10 if title.length() <= 4 else 12, Color("#b4eeff", 0.88))
    var x: float = rect.position.x + 9.0
    var chart_w: float = rect.size.x - 18.0
    var row_step: float = maxf(13.0, (rect.size.y - 105.0) / 6.0)
    for i in range(6):
        var value: float = 0.23 + 0.72 * absf(sin(
            anim_time * (0.92 + float(i) * 0.15) + float(i) * 0.81 + float(mode) * 1.2))
        var y: float = rect.position.y + 43.0 + float(i) * row_step
        draw_rect(Rect2(x, y, chart_w, 5.0), Color("#284454", 0.48))
        draw_rect(Rect2(x, y, chart_w * value, 5.0),
            Color("#82dcfa", 0.43 + 0.25 * value))
    var wave := PackedVector2Array()
    for point in range(24):
        var t: float = float(point)
        var fx: float = x + chart_w * t / 23.0
        var fy: float = rect.end.y - 35.0 + 7.0 * sin(anim_time * 1.8 + t * 0.37 + float(mode))
        fy += 3.0 * cos(anim_time * 1.13 + t * 0.18)
        wave.append(Vector2(fx, fy))
    draw_polyline(wave, Color("#a6ebff", 0.67), 1.25, true)
    _draw_text("SIGNAL", Vector2(x, rect.end.y - 8.0), 9,
        Color("#608ba0", 0.82))

# Text sizes are quantized to *integer internal pixels*. Unlike shrinking
# a vector font, every 5x7 glyph remains a complete, crisp pixel pattern.
func _pixel_cell_pixels(font_size: int) -> int:
    if console_render_scale >= 0.49:
        if font_size >= 36:
            return 3
        if font_size >= 20:
            return 2
    elif console_render_scale >= 0.35:
        # A bold but shortened heading remains visible at 37.5%.
        if font_size >= 29:
            return 2
    elif font_size >= 36 and size.x >= 510.0:
        # At 25%, the percentage still receives a 2px dot stroke.
        return 2
    return 1

func _pixel_text_width(message: String, font_size: int) -> float:
    var cell: int = _pixel_cell_pixels(font_size)
    return float(message.length() * 6 * cell) / console_render_scale

func _fit_pixel_text(message: String, font_size: int, max_width: float) -> String:
    var cell: int = _pixel_cell_pixels(font_size)
    var max_chars: int = maxi(1, int(floorf(
        maxf(max_width, 0.0) * console_render_scale / float(6 * cell))))
    if message.length() <= max_chars:
        return message
    if max_chars <= 2:
        return message.substr(0, max_chars)
    return message.substr(0, max_chars - 2) + ".."

func _draw_text(message: String, at: Vector2, font_size: int,
        color: Color, glow: bool = false) -> void:
    if pixel_font_atlas == null:
        return
    var cell: int = _pixel_cell_pixels(font_size)
    # Snap the complete baseline and all advances in internal raster pixels.
    var physical_x: int = roundi(at.x * console_render_scale)
    var physical_y: int = roundi(at.y * console_render_scale) - 7 * cell
    var physical_size: Vector2 = Vector2(float(5 * cell), float(7 * cell))
    var inv_scale: float = 1.0 / console_render_scale
    for i in range(message.length()):
        var glyph: int = TerminalPixelFont.glyph_index(message.substr(i, 1))
        var src_rect := Rect2(float(glyph * 6), 0.0, 5.0, 7.0)
        var destination := Rect2(
            Vector2(float(physical_x + i * 6 * cell), float(physical_y)) * inv_scale,
            physical_size * inv_scale)
        if glow:
            var halo := Rect2(destination.position + Vector2(inv_scale, 0.0),
                destination.size)
            draw_texture_rect_region(pixel_font_atlas, halo, src_rect,
                Color("#47c9ff", color.a * 0.22))
        draw_texture_rect_region(pixel_font_atlas, destination, src_rect, color)

func _draw_readout(w: float, h: float) -> void:
    var compact: bool = w < 510.0
    var heading: String = "SERA // OMNI SYNCHRONIZER"
    if compact:
        heading = "SERA // OS"
    elif console_render_scale >= 0.35 and console_render_scale < 0.49:
        heading = "SERA // OMNI SYNC"
    var heading_size: int = 22
    if not compact or (console_render_scale >= 0.35 and console_render_scale < 0.49):
        heading_size = 29
    _draw_text(heading, Vector2(42.0, 68.0),
        heading_size, Color("#d3f4ff"), true)
    _draw_text("CORE / OS" if compact else "CORE / SHELL / OS",
        Vector2(43.0, 94.0),
        13 if compact else 16, Color("#6e9db2"))
    var latest_y: float = h - 122.0
    var first_x: float = 42.0
    var count: int = mini(history.size() - 1, _visible_history_count(h))
    for i in range(count):
        var index: int = history.size() - 2 - i
        var alpha: float = maxf(0.17, 0.62 - float(i) * 0.052)
        var previous: String = history[index]
        var previous_y: float = latest_y - 63.0 - float(i) * 39.0
        var previous_size: int = 15 if compact else 19
        _draw_text(_fit_pixel_text("> " + previous, previous_size, w - first_x - 42.0),
            Vector2(first_x, previous_y),
            previous_size, Color(0.48, 0.73, 0.83, alpha))
    var latest: String = history.back() if not history.is_empty() else "BOOT"
    var percent_size: int = 39 if compact else 50
    var percentage: String = "%03d%%" % percent
    # The right-aligned percentage has a reserved, independently measured
    # width so neither it nor the most recent log can collide at 25%.
    var percent_x: float = w - 40.0 - _pixel_text_width(percentage, percent_size)
    # Compact width needs the 1px glyph cell to keep enough log characters.
    var latest_size: int = 19 if compact else 27
    var log_room: float = maxf(24.0, percent_x - first_x - 16.0)
    _draw_text(_fit_pixel_text("> " + latest, latest_size, log_room),
        Vector2(first_x, latest_y), latest_size, Color("#e5fbff"), true)
    _draw_text(percentage, Vector2(percent_x, latest_y + 4.0),
        percent_size, Color("#efffff"), true)
    draw_line(Vector2(first_x, latest_y + 19.0),
        Vector2(w - 45.0, latest_y + 19.0), Color("#55798a", 0.62), 1.0)
    var status: String = "LINK %s / STREAM ACTIVE" % (
        "OK" if percent == 100 else "SYNC")
    _draw_text(_fit_pixel_text(status, 13 if compact else 16, w - 86.0),
        Vector2(43.0, h - 37.0), 13 if compact else 16, Color("#85bfd7"))

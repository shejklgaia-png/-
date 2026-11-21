extends RefCounted
## Cached matte UI skin and sharp cyber typography shared across SERA screens.
static var _cache: Dictionary = {}
static var _card_cache: Dictionary = {}
static var _tab_cache: Dictionary = {}
static var _segment_cache: Dictionary = {}
static var _panel_cache: StyleBoxTexture
## Original SIL OFL 1.1 Japanese TTF fonts are vendored in assets/fonts/.
## No OS fallback or runtime network access: Android GitSync works offline.
## UDEV Gothic: readable Japanese page names, items and interaction labels.
## Moralerspace Neon: mixed Japanese stats, codes, engineering readouts.
const JP_FONT_PATH: String = "res://assets/fonts/UDEVGothic-Regular.ttf"
const JP_TITLE_FONT_PATH: String = "res://assets/fonts/UDEVGothic-Bold.ttf"
const JP_STATS_FONT_PATH: String = "res://assets/fonts/MoralerspaceNeon-Regular.ttf"
const JP_UI_FONT_PATH: String = JP_FONT_PATH
const JP_CONTROL_FONT_PATH: String = JP_TITLE_FONT_PATH
const NAV_FONT_PATH: String = "res://assets/fonts/MoralerspaceNeon-Bold.ttf"
const DATA_FONT_PATH: String = JP_STATS_FONT_PATH
static var _jp_source: FontFile
static var _jp_title_source: FontFile
static var _jp_stats_source: FontFile
static var _jp_ui_source: FontFile
static var _jp_control_source: FontFile
static var _nav_source: FontFile
static var _data_source: FontFile
static var _ui_font: FontVariation
static var _title_font: FontVariation
static var _equipment_font: FontVariation
static var _control_font: FontVariation
static var _stats_font: FontVariation
static var _display_font: FontFile
static var _data_font: FontFile
static var _tracked_display: FontVariation
static var _tracked_data: FontVariation


## Record exactly which font load path succeeded on the running device.
## A Godot Android editor often has raw res:// files before its .godot import
## cache is regenerated; an exported PCK can instead use imported resources.
static var _font_load_status: Dictionary = {}
static var _bundled_face_cache: Dictionary = {}


static func font_load_status(path: String) -> String:
    return str(_font_load_status.get(path, "NOT_ATTEMPTED"))


static func _font_from_raw(path: String, required_glyph: int) -> FontFile:
    if not FileAccess.file_exists(path):
        return null
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    # TrueType/OTF and WOFF2 are both allowed by FontFile.data.
    if bytes.size() < 100:
        return null
    var signature: String = bytes.slice(0, 4).get_string_from_ascii()
    if signature != "wOF2" and signature != "OTTO":
        # TrueType starts with the binary 00 01 00 00 signature.
        if not (bytes[0] == 0 and bytes[1] == 1 and
                bytes[2] == 0 and bytes[3] == 0):
            return null
    var face := FontFile.new()
    face.data = bytes
    face.allow_system_fallback = false
    if not face.has_char(required_glyph):
        return null
    return face


static func _load_bundled_font(path: String, required_glyph: int) -> FontFile:
    # Seven roles share four immutable TTF source objects, cached by path.
    if _bundled_face_cache.has(path):
        return _bundled_face_cache[path] as FontFile
    var raw_exists: bool = FileAccess.file_exists(path)
    var imported_exists: bool = ResourceLoader.exists(path)
    var font: FontFile = null
    var method: String = "FAILED"
    # Prefer raw bytes: works in Android project editors even if .import is
    # stale or missing. Assets are loaded once, not every frame/card.
    if raw_exists:
        font = _font_from_raw(path, required_glyph)
        if font != null:
            method = "RAW_BYTES"
    # Exported APKs may only contain the engine's converted font resource.
    if font == null and imported_exists:
        var imported: Resource = ResourceLoader.load(path)
        if imported is FontFile:
            var candidate: FontFile = imported as FontFile
            candidate.allow_system_fallback = false
            if candidate.has_char(required_glyph):
                font = candidate
                method = "IMPORTED_RESOURCE"
    var details: String = ("%s / raw=%s / imported=%s / glyph=%s" % [
        method,
        "YES" if raw_exists else "NO",
        "YES" if imported_exists else "NO",
        "YES" if font != null and font.has_char(required_glyph) else "NO"
    ])
    _font_load_status[path] = details
    if font == null:
        push_error("SERA_FONT_LOAD_FAILED: " + path + " / " + details)
    else:
        _bundled_face_cache[path] = font
        print("SERA_FONT_LOAD_OK: " + path + " / " + details)
    return font


static func _jp_face() -> FontFile:
    if _jp_source == null:
        _jp_source = _load_bundled_font(JP_FONT_PATH, 0x65E5)
    return _jp_source


static func display_font() -> FontFile:
    if _display_font == null:
        _nav_source = _load_bundled_font(NAV_FONT_PATH, 0x41)
        _display_font = _nav_source
    return _display_font


static func data_font() -> FontFile:
    if _data_font == null:
        _data_source = _load_bundled_font(DATA_FONT_PATH, 0x41)
        _data_font = _data_source
    return _data_font


## Keep a FontVariation object per role (cached); released TTF faces have
## real Regular/Bold weights, not a variable OpenType wght axis.
static func _jp_weight(weight: int) -> FontVariation:
    var result := FontVariation.new()
    result.base_font = _jp_face()
    var ts: TextServer = TextServerManager.get_primary_interface()
    result.variation_opentype = {ts.name_to_tag("wght"): weight}
    return result


## UDEV Gothic Bold: titles, equipment and controls.
## UDEV Gothic Regular: Japanese materials and body.
## Moralerspace Neon Regular/Bold: Japanese-capable stats, Latin navigation,
## codes and combat telemetry. No source font is instantiated per UI card.
static func _title_face() -> FontFile:
    if _jp_title_source == null:
        _jp_title_source = _load_bundled_font(JP_TITLE_FONT_PATH, 0x88C5)
    return _jp_title_source


static func _stats_face() -> FontFile:
    if _jp_stats_source == null:
        _jp_stats_source = _load_bundled_font(JP_STATS_FONT_PATH, 0x65E5)
    return _jp_stats_source


static func _ui_face() -> FontFile:
    if _jp_ui_source == null:
        _jp_ui_source = _load_bundled_font(JP_UI_FONT_PATH, 0x88C5)
    return _jp_ui_source


static func _control_face() -> FontFile:
    if _jp_control_source == null:
        _jp_control_source = _load_bundled_font(JP_CONTROL_FONT_PATH, 0x88C5)
    return _jp_control_source


static func _variation_from_face(face: FontFile, weight: int = 0) -> FontVariation:
    var variation := FontVariation.new()
    variation.base_font = face
    if weight > 0:
        var ts: TextServer = TextServerManager.get_primary_interface()
        variation.variation_opentype = {ts.name_to_tag("wght"): weight}
    return variation


static func ui_font() -> FontVariation:
    if _ui_font == null:
        _ui_font = _variation_from_face(_ui_face())
    return _ui_font


static func title_font() -> FontVariation:
    if _title_font == null:
        _title_font = _variation_from_face(_title_face())
        _title_font.spacing_glyph = 1
    return _title_font


static func equipment_font() -> FontVariation:
    if _equipment_font == null:
        _equipment_font = _variation_from_face(_title_face())
        _equipment_font.spacing_glyph = 1
    return _equipment_font


static func control_font() -> FontVariation:
    if _control_font == null:
        _control_font = _variation_from_face(_control_face())
        _control_font.spacing_glyph = 1
    return _control_font


static func stats_font() -> FontVariation:
    if _stats_font == null:
        _stats_font = _variation_from_face(_stats_face())
    return _stats_font


static func tracked_display_font() -> FontVariation:
    if _tracked_display == null:
        _tracked_display = FontVariation.new()
        _tracked_display.base_font = display_font()
        _tracked_display.spacing_glyph = 1
    return _tracked_display


static func tracked_data_font() -> FontVariation:
    if _tracked_data == null:
        _tracked_data = FontVariation.new()
        _tracked_data.base_font = data_font()
        _tracked_data.spacing_glyph = 1
    return _tracked_data


## Shared name-only accent. Draw beneath the visible text (never tabs,
## action buttons, data tags or empty/LOCKED placeholders). A 1px matte rule
## is enough at Android portrait size; mouse input passes through it.
const NAME_UNDERLINE_COLOR: Color = Color("#55798a")
const NAME_UNDERLINE_HEIGHT: float = 3.0

static func attach_name_underline(label: Label) -> void:
    if label == null or label.get_node_or_null("NameUnderline") != null:
        return
    var line := ColorRect.new()
    line.name = "NameUnderline"
    line.color = NAME_UNDERLINE_COLOR
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_child(line)
    # Recalculate on responsive layout changes, not every rendered frame.
    label.resized.connect(refresh_name_underline.bind(label), CONNECT_DEFERRED)
    refresh_name_underline(label)


static func refresh_name_underline(label: Label) -> void:
    if not is_instance_valid(label):
        return
    var line: ColorRect = label.get_node_or_null("NameUnderline") as ColorRect
    if line == null:
        return
    var lines: PackedStringArray = label.text.split("\n")
    var name_text: String = lines[lines.size() - 1].strip_edges()
    if name_text.is_empty():
        line.visible = false
        return
    var font: Font = label.get_theme_font("font")
    if font == null or label.size.x <= 2.0:
        line.visible = false
        return
    var font_size: int = label.get_theme_font_size("font_size")
    var measured: float = font.get_string_size(
        name_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
    var rule_width: float = minf(maxf(0.0, measured), label.size.x - 2.0)
    if rule_width <= 2.0:
        line.visible = false
        return
    var x: float = 0.0
    if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
        x = (label.size.x - rule_width) * 0.5
    elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
        x = label.size.x - rule_width
    var line_count: int = lines.size()
    var text_height: float = font.get_height(font_size) * float(line_count)
    text_height += float(maxi(0, line_count - 1)) * float(
        label.get_theme_constant("line_spacing"))
    var y: float = 0.0
    if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
        y = maxf(0.0, (label.size.y - text_height) * 0.5)
    elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
        y = maxf(0.0, label.size.y - text_height)
    y = clampf(y + text_height + 1.0, 0.0,
        maxf(0.0, label.size.y - NAME_UNDERLINE_HEIGHT))
    line.position = Vector2(x, y)
    line.size = Vector2(rule_width, NAME_UNDERLINE_HEIGHT)
    line.visible = true


static func style(kind: String = "normal") -> StyleBoxFlat:
    # Matte terminal controls: use a slim active underline, not a glowing
    # filled cyan rectangle. Shared by navigation, category, and Back.
    if _cache.has(kind):
        return _cache[kind] as StyleBoxFlat
    var result := StyleBoxFlat.new()
    result.bg_color = Color("#112631")
    result.border_color = Color("#345566")
    match kind:
        "card":
            result.bg_color = Color("#142936")
            result.border_color = Color("#456473")
        "card_hover", "hover":
            result.bg_color = Color("#244352")
            result.border_color = Color("#69a7b6")
        "card_pressed", "pressed", "hover_pressed":
            result.bg_color = Color("#1a4652")
            result.border_color = Color("#8bf0ee")
        "disabled":
            result.bg_color = Color("#101b25")
            result.border_color = Color("#243945")
        _:
            pass
    result.set_corner_radius_all(5)
    result.set_border_width_all(1)
    if kind in ["card_pressed", "pressed", "hover_pressed"]:
        result.border_width_bottom = 3
    result.shadow_size = 0
    result.content_margin_left = 12.0
    result.content_margin_right = 12.0
    result.content_margin_top = 6.0
    result.content_margin_bottom = 6.0
    _cache[kind] = result
    return result


## Compact, matte segmented controls for the LOWER console, kept separate
## from the hanging navigation. A single narrow cyan rail marks selection.
static func terminal_segment_style(kind: String = "normal") -> StyleBoxFlat:
    if _segment_cache.has(kind):
        return _segment_cache[kind] as StyleBoxFlat
    var panel := StyleBoxFlat.new()
    panel.bg_color = Color("#142b38")
    panel.border_color = Color("#3a6272")
    panel.set_border_width_all(1)
    match kind:
        "selected", "pressed", "hover_pressed":
            panel.bg_color = Color("#204553")
            panel.border_color = Color("#87e2e9")
            panel.border_width_bottom = 3
        "hover":
            panel.bg_color = Color("#1b3948")
            panel.border_color = Color("#6594a2")
        "disabled":
            panel.bg_color = Color("#101e28")
            panel.border_color = Color("#334653")
        "destructive":
            panel.bg_color = Color("#251d27")
            panel.border_color = Color("#73505d")
        _:
            pass
    panel.set_corner_radius_all(3)
    panel.corner_radius_top_left = 1
    panel.corner_radius_top_right = 1
    panel.shadow_size = 0
    panel.content_margin_left = 8.0
    panel.content_margin_right = 8.0
    panel.content_margin_top = 7.0
    panel.content_margin_bottom = 7.0
    _segment_cache[kind] = panel
    return panel

## Alpha-backed trapezoid tabs hang from the viewport top edge. The image and
## its nine-patch corners are generated once per state; there are no per-frame
## drawing calls, overlays, glow shaders or blur passes.
static func panel_style() -> StyleBoxTexture:
    if _panel_cache != null:
        return _panel_cache
    var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
    var top := Color("#133442")
    var bottom := Color("#080f1c")
    var border := Color("#456878")
    for y in range(64):
        var fill: Color = top.lerp(bottom, float(y) / 63.0)
        for x in range(32):
            var corner_distance: int = mini(
                mini(x + y, 31 - x + y),
                mini(x + 63 - y, 94 - x - y))
            if corner_distance < 4:
                img.set_pixel(x, y, Color.TRANSPARENT)
            elif x == 0 or x == 31 or y == 0 or y == 63 or corner_distance < 6:
                img.set_pixel(x, y, border)
            elif x == 2 and y > 11 and y < 51:
                img.set_pixel(x, y, Color("#274d60"))
            elif y % 13 == 0:
                img.set_pixel(x, y, fill.lightened(0.035))
            else:
                img.set_pixel(x, y, fill)
    var result := StyleBoxTexture.new()
    result.texture = ImageTexture.create_from_image(img)
    result.set_texture_margin_all(6.0)
    _panel_cache = result
    return result


static func hanging_tab_style(kind: String = "normal") -> StyleBoxTexture:
    if _tab_cache.has(kind):
        return _tab_cache[kind] as StyleBoxTexture
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    var fill := Color("#142a39")
    var rim := Color("#557482")
    var lip := Color("#628e9c")
    match kind:
        "selected":
            fill = Color("#214959")
            rim = Color("#82dae2")
            lip = Color("#9cf6f2")
        "hover":
            fill = Color("#1d394a")
            rim = Color("#79a7b4")
            lip = Color("#94d9df")
        "disabled":
            fill = Color("#101a23")
            rim = Color("#293c49")
            lip = Color("#344c59")
        _:
            pass
    for y in range(64):
        # The bottom 16px taper inwards like a metal panel hanging downward.
        var inset: int = maxi(0, mini(8, int((y - 47) / 2.0)))
        for x in range(64):
            if x < inset or x >= 64 - inset:
                image.set_pixel(x, y, Color.TRANSPARENT)
                continue
            var surface: Color = fill.lerp(Color("#0a1924"),
                0.15 * float(y) / 63.0)
            if x <= inset + 1 or x >= 62 - inset or y == 0:
                surface = rim
            if y >= 61:
                surface = lip
            if y == 2 and x > 17 and x < 52:
                surface = Color("#6db0bc") if kind != "selected" else Color("#b0fbf5")
            if x >= 54 and x <= 56 and y >= 13 and y < 30:
                surface = Color("#344f62") if kind != "selected" else Color("#75ced8")
            # Restrained cold-steel seam near the top rather than a full glow.
            if y == 4 and x >= 10 and x < 54:
                surface = Color("#304d5c") if kind != "selected" else Color("#4e7888")
            image.set_pixel(x, y, surface)
    var stylebox := StyleBoxTexture.new()
    stylebox.texture = ImageTexture.create_from_image(image)
    stylebox.set_texture_margin_all(16.0)
    _tab_cache[kind] = stylebox
    return stylebox

## All three LABO pages use the exact same chamfered card silhouette. The
## 32x32 atlas is generated once per state; no pixel work during list scroll.
static func card_style(kind: String = "normal") -> StyleBoxTexture:
    if _card_cache.has(kind):
        return _card_cache[kind] as StyleBoxTexture
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var fill := Color("#142f3b")
    var edge := Color("#466775")
    match kind:
        "hover":
            fill = Color("#214554")
            edge = Color("#75b9c4")
        "pressed", "selected":
            fill = Color("#205262")
            edge = Color("#9bf5ef")
        "disabled":
            fill = Color("#10202a")
            edge = Color("#34505e")
    for y in range(32):
        for x in range(32):
            var corner_distance: int = mini(
                mini(x + y, 31 - x + y),
                mini(x + 31 - y, 62 - x - y))
            if corner_distance < 6:
                image.set_pixel(x, y, Color.TRANSPARENT)
            elif (x <= 1 or x >= 30 or y <= 1 or y >= 30
                    or corner_distance < 8):
                image.set_pixel(x, y, edge)
            elif y == 3 and x >= 10 and x <= 21:
                image.set_pixel(x, y, edge.lightened(0.24))
            elif x == 3 and y >= 13 and y <= 23:
                image.set_pixel(x, y, edge)
            elif x >= 26 and y >= 4 and y <= 6:
                image.set_pixel(x, y, Color("#273e4d"))
            else:
                image.set_pixel(x, y, fill.lerp(Color("#09121e"),
                    0.46 * float(y) / 31.0))
    var result := StyleBoxTexture.new()
    result.texture = ImageTexture.create_from_image(image)
    result.set_texture_margin_all(10.0)
    _card_cache[kind] = result
    return result

static func common_theme() -> Theme:
    var theme := Theme.new()
    for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
        theme.set_stylebox(state, "Button", style("normal" if state == "focus" else state))
    theme.default_font = ui_font()
    theme.default_font_size = 18
    theme.set_font("font", "Button", ui_font())
    theme.set_font("font", "Label", ui_font())
    theme.set_font("font", "SpinBox", data_font())
    theme.set_font("font", "LineEdit", data_font())
    theme.set_color("font_color", "Button", Color("#e2edf3"))
    theme.set_color("font_disabled_color", "Button", Color("#bdceda"))
    theme.set_color("font_pressed_color", "Button", Color("#edf7fa"))
    theme.set_color("font_hover_color", "Button", Color("#edf7fa"))
    theme.set_color("font_color", "Label", Color("#dcebf0"))
    theme.set_color("font_color", "LineEdit", Color("#e6f0f5"))
    theme.set_stylebox("pressed", "Button", style("pressed"))
    theme.set_stylebox("hover_pressed", "Button", style("hover_pressed"))
    theme.set_color("font_hover_pressed_color", "Button", Color("#edf7fa"))
    return theme

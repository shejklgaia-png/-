extends RefCounted
## Four matching blue-grey rounded button states. Shared across all LABO pages.
static var _cache: Dictionary = {}
static var _card_cache: Dictionary = {}
static var _tab_cache: Dictionary = {}
static var _segment_cache: Dictionary = {}
static var _panel_cache: StyleBoxTexture
static var _ui_font: SystemFont
static var _title_font: SystemFont
static var _data_font: SystemFont

## Device fonts only: the first installed face is used, then Godot's
## built-in CJK fallback. No shipped font asset, network request or glyph atlas.
static func ui_font() -> SystemFont:
    if _ui_font == null:
        _ui_font = SystemFont.new()
        _ui_font.font_names = PackedStringArray([
            "Noto Sans JP", "Noto Sans CJK JP", "M PLUS 1p",
            "Hiragino Kaku Gothic ProN", "Yu Gothic", "sans-serif"])
        _ui_font.font_weight = 550
        _ui_font.allow_system_fallback = true
    return _ui_font

static func title_font() -> SystemFont:
    if _title_font == null:
        _title_font = SystemFont.new()
        _title_font.font_names = ui_font().font_names
        _title_font.font_weight = 700
        _title_font.allow_system_fallback = true
    return _title_font

static func data_font() -> SystemFont:
    if _data_font == null:
        _data_font = SystemFont.new()
        _data_font.font_names = PackedStringArray([
            "Roboto Mono", "JetBrains Mono", "Noto Sans Mono CJK JP",
            "M PLUS 1 Code", "monospace"])
        _data_font.font_weight = 550
        _data_font.allow_system_fallback = true
    return _data_font


static func style(kind: String = "normal") -> StyleBoxFlat:
    # Matte terminal controls: use a slim active underline, not a glowing
    # filled cyan rectangle. Shared by navigation, category, and Back.
    if _cache.has(kind):
        return _cache[kind] as StyleBoxFlat
    var result := StyleBoxFlat.new()
    result.bg_color = Color("#12232e")
    result.border_color = Color("#29414d")
    match kind:
        "card":
            result.bg_color = Color("#111e28")
            result.border_color = Color("#314752")
        "card_hover", "hover":
            result.bg_color = Color("#1a313c")
            result.border_color = Color("#507d88")
        "card_pressed", "pressed", "hover_pressed":
            result.bg_color = Color("#193540")
            result.border_color = Color("#62cbd6")
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
    panel.bg_color = Color("#101d27")
    panel.border_color = Color("#2b4551")
    panel.set_border_width_all(1)
    match kind:
        "selected", "pressed", "hover_pressed":
            panel.bg_color = Color("#17303c")
            panel.border_color = Color("#537d8a")
            panel.border_width_bottom = 3
            panel.border_color = Color("#72bcca")
        "hover":
            panel.bg_color = Color("#172b36")
            panel.border_color = Color("#4e7582")
        "disabled":
            panel.bg_color = Color("#0e1721")
            panel.border_color = Color("#283944")
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
    var top := Color("#102734")
    var bottom := Color("#08131e")
    var border := Color("#294653")
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
    var fill := Color("#14222d")
    var rim := Color("#425666")
    var lip := Color("#536e7b")
    match kind:
        "selected":
            fill = Color("#1d3542")
            rim = Color("#5fb7c7")
            lip = Color("#83e4ee")
        "hover":
            fill = Color("#1b303d")
            rim = Color("#698d9c")
            lip = Color("#80b8c7")
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
    var fill := Color("#101e28")
    var edge := Color("#304853")
    match kind:
        "hover":
            fill = Color("#182f3b")
            edge = Color("#4c8795")
        "pressed", "selected":
            fill = Color("#19343e")
            edge = Color("#69c1cb")
        "disabled":
            fill = Color("#111c25")
            edge = Color("#293c46")
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
            else:
                image.set_pixel(x, y, fill.lerp(Color("#09151d"),
                    0.24 * float(y) / 31.0))
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
    theme.set_color("font_color", "Button", Color("#f1faff"))
    theme.set_color("font_disabled_color", "Button", Color("#cad9e5"))
    theme.set_color("font_pressed_color", "Button", Color.WHITE)
    theme.set_color("font_hover_color", "Button", Color.WHITE)
    theme.set_color("font_color", "Label", Color("#e9f7fc"))
    theme.set_color("font_color", "LineEdit", Color("#f5fcff"))
    theme.set_stylebox("pressed", "Button", style("pressed"))
    theme.set_stylebox("hover_pressed", "Button", style("hover_pressed"))
    theme.set_color("font_hover_pressed_color", "Button", Color.WHITE)
    return theme

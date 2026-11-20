extends RefCounted
## Four matching blue-grey rounded button states. Shared across all LABO pages.
static var _cache: Dictionary = {}
static var _card_cache: Dictionary = {}
static var _tab_cache: Dictionary = {}
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
    if _cache.has(kind):
        return _cache[kind] as StyleBoxFlat
    var result := StyleBoxFlat.new()
    match kind:
        "card":
            result.bg_color = Color("#0c2737")
            result.border_color = Color("#3b8aa1")
        "card_hover", "hover":
            result.bg_color = Color("#134255")
            result.border_color = Color("#72d9e6")
        "card_pressed", "pressed":
            result.bg_color = Color("#126476")
            result.border_color = Color("#9bffff")
        "disabled":
            result.bg_color = Color("#142b39")
            result.border_color = Color("#40798a")
        _:
            result.bg_color = Color("#102a3b")
            result.border_color = Color("#4d778d")
    result.set_corner_radius_all(8)
    if kind in ["card_pressed", "pressed"]:
        result.shadow_color = Color(0.10, 0.82, 0.88, 0.32)
        result.shadow_size = 4
    result.set_border_width_all(2 if kind in ["card_pressed", "pressed"] else 1)
    result.content_margin_left = 9.0
    result.content_margin_right = 9.0
    result.content_margin_top = 6.0
    result.content_margin_bottom = 6.0
    _cache[kind] = result
    return result


## All three LABO pages use the exact same chamfered card silhouette. The
## 32x32 atlas is generated once per state; no pixel work during list scroll.
static func card_style(kind: String = "normal") -> StyleBoxTexture:
    if _card_cache.has(kind):
        return _card_cache[kind] as StyleBoxTexture
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var fill := Color("#0b2230")
    var edge := Color("#468da4")
    match kind:
        "hover":
            fill = Color("#123d4d")
            edge = Color("#73dbe8")
        "pressed", "selected":
            fill = Color("#0d5366")
            edge = Color("#a2faff")
        "disabled":
            fill = Color("#102732")
            edge = Color("#4b7b87")
    for y in range(32):
        for x in range(32):
            var corner_distance: int = mini(
                mini(x + y, 31 - x + y),
                mini(x + 31 - y, 62 - x - y))
            if corner_distance < 7:
                image.set_pixel(x, y, Color.TRANSPARENT)
            elif (x <= 1 or x >= 30 or y <= 1 or y >= 30
                    or corner_distance < 10):
                image.set_pixel(x, y, edge)
            else:
                image.set_pixel(x, y, fill)
    var result := StyleBoxTexture.new()
    result.texture = ImageTexture.create_from_image(image)
    result.set_texture_margin_all(10.0)
    _card_cache[kind] = result
    return result

static func common_theme() -> Theme:
    var theme := Theme.new()
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
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
    return theme

extends RefCounted
## Four matching blue-grey rounded button states. Shared across all LABO pages.
static var _cache: Dictionary = {}

static func style(kind: String = "normal") -> StyleBoxFlat:
    if _cache.has(kind):
        return _cache[kind] as StyleBoxFlat
    var result := StyleBoxFlat.new()
    match kind:
        "card":
            result.bg_color = Color("#293e51")
            result.border_color = Color("#729bb0")
        "card_hover", "hover":
            result.bg_color = Color("#34576a")
            result.border_color = Color("#95cadb")
        "card_pressed", "pressed":
            result.bg_color = Color("#3a667b")
            result.border_color = Color("#99d8e8")
        "disabled":
            result.bg_color = Color("#273846")
            result.border_color = Color("#74aebf")
        _:
            result.bg_color = Color("#293f52")
            result.border_color = Color("#688fa4")
    result.set_corner_radius_all(12)
    result.set_border_width_all(2 if kind in ["card_pressed", "pressed"] else 1)
    result.content_margin_left = 9.0
    result.content_margin_right = 9.0
    result.content_margin_top = 6.0
    result.content_margin_bottom = 6.0
    _cache[kind] = result
    return result

static func common_theme() -> Theme:
    var theme := Theme.new()
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        theme.set_stylebox(state, "Button", style("normal" if state == "focus" else state))
    theme.set_color("font_color", "Button", Color("#edf7ff"))
    theme.set_color("font_disabled_color", "Button", Color("#cad9e5"))
    theme.set_color("font_pressed_color", "Button", Color.WHITE)
    return theme

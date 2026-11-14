extends Control
## SERA v338: compact top-left HP/EN bars in reference vector geometry.
## user-provided 1536x512 design screenshot (no image or texture dependency).
## The reference is wide, but the geometry scales to the portrait viewport.
## main.gd remains the sole owner of actual HP/EN, exhaustion and target HP.

const DESIGN_WIDTH: float = 720.0
# The player meters occupy only the top-left of the 720-wide design space,
# leaving the top-right for NEXUS and the independent ANGLE toggle.
const PLAYER_RULE_RIGHT: float = 520.0
const PLAYER_BAR_RIGHT: float = 387.0
const PLAYER_VALUE_RIGHT: float = 520.0
const PLAYER_HP_BASELINE: float = 33.0
const PLAYER_EN_BASELINE: float = 70.0
# Place boss/part health immediately below the player meters.
const BOSS_ROW_TOP: float = 109.0
const PART_ROW_TOP: float = 151.0
const HP_TINT: Color = Color("#42feff")
const EN_TINT: Color = Color("#ffba1b")
const EMPTY_TINT: Color = Color("#ef615b")
const TEXT_TINT: Color = Color("#e2e8ef")
const RULE_TINT: Color = Color(0.74, 0.80, 0.83, 0.67)
const TRACK_TINT: Color = Color(0.22, 0.25, 0.28, 0.88)
const BOSS_TINT: Color = Color("#f6a950")
const PART_TINT: Color = Color("#9adce7")

var hp: float = 800.0
var hp_max: float = 800.0
var en: float = 100.0
var en_max: float = 100.0
var en_locked: bool = false
var boss_hp: float = 500.0
var boss_max: float = 500.0
var part_hp: float = 100.0
var part_max: float = 100.0
var part_name: String = "BODY"

# Display values are filtered; gameplay and displayed numbers remain exact.
var shown_hp: float = 1.0
var shown_en: float = 1.0
var shown_boss: float = 1.0
var shown_part: float = 1.0
var tick: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()


func set_vitals(value_hp: float, maximum_hp: float, value_en: float,
        maximum_en: float, locked: bool) -> void:
    hp_max = maxf(1.0, maximum_hp)
    en_max = maxf(1.0, maximum_en)
    hp = clampf(value_hp, 0.0, hp_max)
    en = clampf(value_en, 0.0, en_max)
    en_locked = locked
    queue_redraw()


func set_boss_health(value: float, maximum: float) -> void:
    boss_max = maxf(1.0, maximum)
    boss_hp = clampf(value, 0.0, boss_max)
    queue_redraw()


func set_locked_part(label: String, value: float, maximum: float) -> void:
    part_name = label
    part_max = maxf(1.0, maximum)
    part_hp = clampf(value, 0.0, part_max)
    queue_redraw()


func _process(delta: float) -> void:
    tick += maxf(0.0, delta)
    # Exponential easing preserves approximately identical visual timing
    # at 30/60/120 fps and does not affect the underlying resource numbers.
    var alpha: float = 1.0 - exp(-13.0 * maxf(0.0, delta))
    shown_hp = lerpf(shown_hp, hp / hp_max, alpha)
    shown_en = lerpf(shown_en, en / en_max, alpha)
    shown_boss = lerpf(shown_boss, boss_hp / boss_max, alpha)
    shown_part = lerpf(shown_part, part_hp / part_max, alpha)
    queue_redraw()


func _slanted_quad(left: float, top: float, right: float,
        height: float, slope: float = 5.5) -> PackedVector2Array:
    var cut: float = minf(slope, maxf(0.0, (right - left) * 0.35))
    return PackedVector2Array([
        Vector2(left + cut, top), Vector2(right, top),
        Vector2(right - cut, top + height), Vector2(left, top + height)
    ])


func _draw_text(value: String, pos: Vector2, size_px: int,
        tint: Color = TEXT_TINT, right_aligned: bool = false) -> void:
    var font: Font = get_theme_default_font()
    if font == null:
        return
    if right_aligned:
        pos.x -= font.get_string_size(
            value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, size_px, tint)


func _draw_instrument_row(kind: String, baseline: float,
        actual: float, maximum: float, displayed_ratio: float,
        is_exhausted: bool) -> void:
    var ratio: float = clampf(actual / maxf(1.0, maximum), 0.0, 1.0)
    # Screenshot: open angled notch at left, fine rule beneath the meter,
    # diagonally terminated strip and numeric readout on the far right.
    var rule: PackedVector2Array = PackedVector2Array([
        Vector2(25.0, baseline - 10.0),
        Vector2(45.0, baseline + 10.0),
        Vector2(PLAYER_RULE_RIGHT - 8.0, baseline + 10.0),
        Vector2(PLAYER_RULE_RIGHT, baseline + 2.0)
    ])
    draw_polyline(rule, RULE_TINT, 1.2, true)
    _draw_text("H P" if kind == "HP" else "E N",
        Vector2(56.0, baseline), 17)
    _draw_text("/", Vector2(100.0, baseline), 18)

    var bar_x: float = 113.0
    var bar_right: float = PLAYER_BAR_RIGHT
    var bar_y: float = baseline - 2.0
    var bar_height: float = 7.0
    draw_colored_polygon(_slanted_quad(bar_x, bar_y, bar_right,
        bar_height), TRACK_TINT)

    var color: Color = HP_TINT if kind == "HP" else EN_TINT
    var opacity: float = 1.0
    if kind == "EN":
        if ratio <= 0.0:
            color = EMPTY_TINT
            opacity = 0.20 + 0.80 * (
                0.5 + 0.5 * sin(TAU * 7.0 * tick))
        elif is_exhausted:
            # Exhaustion remains active until the existing 60% unlock.
            color = Color("#6e6960")
        elif ratio <= 0.25:
            opacity = 0.33 + 0.67 * (
                0.5 + 0.5 * sin(TAU * 1.25 * tick))
    elif ratio > 0.0 and ratio <= 0.25:
        opacity = 0.40 + 0.60 * (
            0.5 + 0.5 * sin(TAU * 1.25 * tick))

    var filled_right: float = lerpf(
        bar_x, bar_right, clampf(displayed_ratio, 0.0, 1.0))
    if filled_right > bar_x + 1.0:
        var glow: Color = Color(color.r, color.g, color.b, 0.16 * opacity)
        draw_colored_polygon(_slanted_quad(
            bar_x, bar_y - 2.0, filled_right, bar_height + 4.0), glow)
        color.a = opacity
        draw_colored_polygon(_slanted_quad(
            bar_x, bar_y, filled_right, bar_height), color)

    var amount_text: String = "%d / %d" % [ceili(actual), roundi(maximum)]
    var digits_color: Color = TEXT_TINT
    if kind == "EN" and ratio <= 0.0:
        digits_color = EMPTY_TINT
        digits_color.a = opacity
        # Empty bars have no fill to flash: retain a small flashing edge.
        draw_line(Vector2(bar_x, bar_y + 9.0),
            Vector2(bar_x + 38.0, bar_y + 9.0), digits_color, 1.6, true)
    _draw_text(amount_text, Vector2(PLAYER_VALUE_RIGHT, baseline),
        15, digits_color, true)


func _draw_target_row(title: String, actual: float, maximum: float,
        progress: float, top: float, height: float,
        width: float, tint: Color) -> void:
    _draw_text(title, Vector2(25.0, top), 13)
    var value: String = "%d / %d" % [ceili(actual), roundi(maximum)]
    _draw_text(value, Vector2(694.0, top), 13, TEXT_TINT, true)
    var left: float = 25.0
    var right: float = left + width
    var bar_y: float = top + 8.0
    draw_colored_polygon(_slanted_quad(
        left, bar_y, right, height), TRACK_TINT)
    if progress > 0.0001:
        draw_colored_polygon(_slanted_quad(left, bar_y,
            lerpf(left, right, clampf(progress, 0.0, 1.0)), height),
            tint)


func _draw() -> void:
    # No background rectangle or texture. The Control uses only dynamic
    # CanvasItem primitives. Fixed 720-unit geometry scales with viewport X.
    if size.x <= 0.0:
        return
    var scale_factor: float = size.x / DESIGN_WIDTH
    draw_set_transform(Vector2.ZERO, 0.0,
        Vector2(scale_factor, scale_factor))

    # The two short player meters sit at top-left; the independent
    # NEXUS (top right) and ANGLE (right, second row) never cover them.
    _draw_instrument_row("HP", PLAYER_HP_BASELINE,
        hp, hp_max, shown_hp, false)
    _draw_instrument_row("EN", PLAYER_EN_BASELINE,
        en, en_max, shown_en, en_locked)

    # Boss total and selected lock part rise along with the compact player
    # HUD; no large unused block remains between the two health groups.
    _draw_target_row("BOSS", boss_hp, boss_max,
        shown_boss, BOSS_ROW_TOP, 12.0, 670.0, BOSS_TINT)
    _draw_target_row("LOCK / " + part_name, part_hp, part_max,
        shown_part, PART_ROW_TOP, 7.0, 360.0, PART_TINT)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

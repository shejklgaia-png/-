extends Control
## Transparent resolution-aware runtime training HUD.
## Figma node 2:2 could not be read (provider plan rate limit); this shape
## implementation is a provisional vector HUD, NOT a claimed Figma match.
## Gameplay numbers are authoritative in main.gd; only display ratios animate.

const HP_COLOR: Color = Color("67cce7")
const EN_COLOR: Color = Color("5de4d1")
const BOSS_COLOR: Color = Color("ffad59")
const PART_COLOR: Color = Color("a6e4f1")
const BACK_COLOR: Color = Color(0.08, 0.14, 0.19, 0.75)
const LOW_COLOR: Color = Color("ffb35d")
const EMPTY_COLOR: Color = Color("ef615b")
const TEXT_COLOR: Color = Color("e3eef3")

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
    hp = clampf(value_hp, 0.0, maxf(maximum_hp, 1.0))
    hp_max = maxf(1.0, maximum_hp)
    en = clampf(value_en, 0.0, maxf(maximum_en, 1.0))
    en_max = maxf(1.0, maximum_en)
    en_locked = locked
    queue_redraw()

func set_boss_health(value: float, maximum: float) -> void:
    boss_max = maxf(maximum, 1.0)
    boss_hp = clampf(value, 0.0, boss_max)
    queue_redraw()

func set_locked_part(label: String, value: float, maximum: float) -> void:
    part_name = label
    part_max = maxf(maximum, 1.0)
    part_hp = clampf(value, 0.0, part_max)
    queue_redraw()

func _process(delta: float) -> void:
    tick += maxf(0.0, delta)
    var k: float = 1.0 - exp(-13.0 * maxf(0.0, delta))
    shown_hp = lerpf(shown_hp, hp / hp_max, k)
    shown_en = lerpf(shown_en, en / en_max, k)
    shown_boss = lerpf(shown_boss, boss_hp / boss_max, k)
    shown_part = lerpf(shown_part, part_hp / part_max, k)
    queue_redraw()

func _bar(at: Vector2, width: float, height: float, amount: float,
        tint: Color, flash: float = 1.0) -> void:
    draw_rect(Rect2(at, Vector2(width, height)), BACK_COLOR, true)
    if amount > 0.0:
        var color: Color = tint
        color.a = flash
        draw_rect(Rect2(at, Vector2(width * clampf(amount, 0.0, 1.0), height)),
            color, true)

func _write(at: Vector2, value: String, font_size: int,
        tint: Color = TEXT_COLOR) -> void:
    draw_string(get_theme_default_font(), at, value, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, font_size, tint)

func _draw() -> void:
    var scale_factor: float = clampf(size.x / 720.0, 0.64, 1.30)
    var gap: float = 22.0 * scale_factor
    var font_size: int = maxi(10, roundi(14.0 * scale_factor))
    var hp_ratio: float = hp / hp_max
    var en_ratio: float = en / en_max
    var player_bar_width: float = minf(250.0 * scale_factor, size.x * 0.42)
    var player_left: float = gap + 32.0 * scale_factor
    var hp_y: float = 20.0 * scale_factor
    var en_y: float = 57.0 * scale_factor
    var blink_slow: float = 0.40 + 0.60 * (0.5 + 0.5 * sin(TAU * 1.25 * tick))
    var blink_fast: float = 0.20 + 0.80 * (0.5 + 0.5 * sin(TAU * 7.0 * tick))
    var hp_color: Color = LOW_COLOR if hp_ratio <= 0.25 else HP_COLOR
    var en_color: Color = EN_COLOR
    var en_alpha: float = 1.0
    if en_ratio <= 0.0:
        en_color = EMPTY_COLOR
        en_alpha = blink_fast
    elif en_locked:
        en_color = Color("40545b")  # Preserve 60% exhaustion gate.
    elif en_ratio <= 0.25:
        en_color = LOW_COLOR
        en_alpha = blink_slow
    _write(Vector2(gap, hp_y + 13.0 * scale_factor), "HP", font_size)
    _write(Vector2(gap, en_y + 13.0 * scale_factor), "EN", font_size)
    _write(Vector2(player_left, hp_y), "%d / %d" % [ceili(hp), roundi(hp_max)],
        font_size - 1)
    _bar(Vector2(player_left, hp_y + 8.0 * scale_factor),
        player_bar_width, 9.0 * scale_factor, shown_hp, hp_color,
        blink_slow if hp_ratio > 0.0 and hp_ratio <= 0.25 else 1.0)
    var en_text: String = "RECOVER %d%%" % roundi(en_ratio * 100.0) if en_locked         else "%d%%" % roundi(en_ratio * 100.0)
    var en_label_color: Color = TEXT_COLOR
    if en_ratio <= 0.0:
        en_text = "EMPTY 0%"
        en_label_color = EMPTY_COLOR
        en_label_color.a = blink_fast
    _write(Vector2(player_left, en_y), en_text, font_size - 1, en_label_color)
    _bar(Vector2(player_left, en_y + 8.0 * scale_factor),
        player_bar_width, 9.0 * scale_factor, shown_en, en_color, en_alpha)
    # At zero no rectangle remains to blink: flash the label and warning line.
    if en_ratio <= 0.0:
        draw_line(Vector2(player_left, en_y + 18.0 * scale_factor),
            Vector2(player_left + player_bar_width, en_y + 18.0 * scale_factor),
            en_label_color, 2.0 * scale_factor, true)

    # BOSS is the wide bar; the selected lock part is always the smaller bar.
    var boss_left: float = gap
    var boss_width: float = maxf(0.0, size.x - gap * 2.0)
    var boss_top: float = 118.0 * scale_factor
    _write(Vector2(boss_left, boss_top), "BOSS  %d / %d" % [
        ceili(boss_hp), roundi(boss_max)], font_size)
    _bar(Vector2(boss_left, boss_top + 9.0 * scale_factor),
        boss_width, 14.0 * scale_factor, shown_boss, BOSS_COLOR)
    var small_top: float = 165.0 * scale_factor
    _write(Vector2(boss_left, small_top), "LOCK %s  %d / %d" % [
        part_name, ceili(part_hp), roundi(part_max)], font_size - 1)
    _bar(Vector2(boss_left, small_top + 7.0 * scale_factor),
        boss_width * 0.52, 7.0 * scale_factor, shown_part, PART_COLOR)

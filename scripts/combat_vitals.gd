extends Control
## v202: compact, non-interactive HP/EN meters for the training combat HUD.
## All borders pulse continuously through sine opacity, never by a hard toggle.

const BAR_LEFT: float = 34.0
const BAR_WIDTH: float = 150.0
const BAR_HEIGHT: float = 9.0
const SECOND_ROW_Y: float = 31.0
const FONT_SIZE: int = 12
const LOW_RATIO: float = 0.25
const NORMAL_HP: Color = Color("67cce7")
const NORMAL_EN: Color = Color("5de4d1")
const WARNING: Color = Color("ffb35d")
const EMPTY: Color = Color("ef615b")
const MUTED: Color = Color("40545b")
const BACKGROUND: Color = Color("142a35")

var hp: float = 800.0
var maximum_hp: float = 800.0
var en: float = 100.0
var maximum_en: float = 100.0
var en_locked: bool = false
var elapsed: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()

func set_vitals(next_hp: float, next_max_hp: float, next_en: float,
        next_max_en: float, locked: bool) -> void:
    hp = maxf(0.0, next_hp)
    maximum_hp = maxf(1.0, next_max_hp)
    en = maxf(0.0, next_en)
    maximum_en = maxf(1.0, next_max_en)
    en_locked = locked
    queue_redraw()

func _process(delta: float) -> void:
    # The 25% caution border breathes slowly; an empty EN border flashes
    # faster. Do not animate full, recovering, or empty-HP states.
    if (hp > 0.0 and hp / maximum_hp <= LOW_RATIO) \
            or (en > 0.0 and not en_locked and en / maximum_en <= LOW_RATIO) \
            or en <= 0.0:
        elapsed += maxf(0.0, delta)
        queue_redraw()

func _breath(hz: float) -> float:
    return 0.30 + 0.70 * (0.5 + 0.5 * sin(TAU * hz * elapsed))

func _draw_meter(top: float, title: String, detail: String, fraction: float,
        fill_color: Color, frame_color: Color) -> void:
    var font: Font = get_theme_default_font()
    draw_string(font, Vector2(0.0, top + 12.0), title,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Color("d5e7ef"))
    draw_string(font, Vector2(BAR_LEFT, top + 12.0), detail,
        HORIZONTAL_ALIGNMENT_RIGHT, BAR_WIDTH, FONT_SIZE, Color("bed4df"))
    var rect := Rect2(BAR_LEFT, top + 17.0, BAR_WIDTH, BAR_HEIGHT)
    draw_rect(rect, BACKGROUND, true)
    if fraction > 0.0:
        draw_rect(Rect2(rect.position + Vector2.ONE,
            Vector2((BAR_WIDTH - 2.0) * clampf(fraction, 0.0, 1.0),
                BAR_HEIGHT - 2.0)), fill_color, true)
    draw_rect(rect, frame_color, false, 1.6)

func _draw() -> void:
    var hp_ratio: float = clampf(hp / maximum_hp, 0.0, 1.0)
    var en_ratio: float = clampf(en / maximum_en, 0.0, 1.0)
    var hp_fill: Color = NORMAL_HP
    var hp_frame: Color = NORMAL_HP.darkened(0.22)
    if hp_ratio <= 0.0:
        hp_fill = MUTED
        hp_frame = MUTED
    elif hp_ratio <= LOW_RATIO:
        hp_fill = WARNING
        hp_frame = WARNING
        hp_frame.a = _breath(1.25)
    _draw_meter(0.0, "HP", "%d / %d" % [ceili(hp), roundi(maximum_hp)],
        hp_ratio, hp_fill, hp_frame)

    var en_fill: Color = NORMAL_EN
    var en_frame: Color = NORMAL_EN.darkened(0.22)
    var en_detail: String = "%d%%" % ceili(en_ratio * 100.0)
    if en_ratio <= 0.0:
        en_fill = MUTED
        en_frame = EMPTY
        en_frame.a = _breath(4.0)
        en_detail = "EMPTY  0%"
    elif en_locked:
        # Once regeneration begins, keep the bar dark until EN reaches 60%.
        en_fill = MUTED
        en_frame = MUTED
        en_detail = "RECOVER  %d%%" % ceili(en_ratio * 100.0)
    elif en_ratio <= LOW_RATIO:
        en_frame = WARNING
        en_frame.a = _breath(1.25)
    _draw_meter(SECOND_ROW_Y, "EN", en_detail, en_ratio, en_fill, en_frame)

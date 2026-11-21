extends RefCounted
## One presentation contract for LABO fabrication and NEXUS part/total stats.
## Underlying saved/combat numbers continue to come from their original sources.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const LaboStats = preload("res://scripts/sera_labo_stats.gd")
const LABEL_COLOR: Color = Color("#a9c2cd")
const VALUE_COLOR: Color = Color("#e4edf1")
const DIVIDER_COLOR: Color = Color("#35515f")

static func style_stat_labels(name_label: Label, value_label: Label,
        name_size: int, value_size: int) -> void:
    name_label.add_theme_font_override("font", LaboSkin.stats_font())
    name_label.add_theme_font_size_override("font_size", name_size)
    name_label.add_theme_color_override("font_color", LABEL_COLOR)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    value_label.add_theme_font_override("font", LaboSkin.stats_font())
    value_label.add_theme_font_size_override("font_size", value_size)
    value_label.add_theme_color_override("font_color", VALUE_COLOR)


# Maximize readable size without ellipsizing long Japanese or technical labels.
# Called only on layout/equipment changes, never during a game frame.
static func fit_label(label: Label, maximum_px: int, minimum_px: int) -> void:
    if label.text.is_empty() or label.size.x <= 1.0:
        return
    var font: Font = label.get_theme_font("font")
    if font == null:
        return
    var font_size: int = maximum_px
    while font_size > minimum_px and font.get_string_size(
            label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > (
            label.size.x - 2.0):
        font_size -= 1
    label.add_theme_font_size_override("font_size", font_size)


# Prefer human-readable Japanese compound boundaries over arbitrary glyph breaks.
# Entries are ordered from the most natural phrasing to narrow-lane fallbacks.
# Source labels/parameter IDs remain untouched; only UI Label.text is shaped.
const JAPANESE_STAT_BREAKS: Dictionary = {
    "ブースト速度倍率": [
        ["ブースト速度", "倍率"], ["ブースト", "速度倍率"]],
    "被弾時間倍率": [["被弾時間", "倍率"], ["被弾", "時間倍率"]],
    "被弾後退倍率": [["被弾後退", "倍率"], ["被弾", "後退倍率"]],
    "部位モデル区分": [["部位モデル", "区分"], ["部位", "モデル区分"]],
    "ダウン被弾回数": [["ダウン被弾", "回数"], ["ダウン", "被弾回数"]],
    "歩行モーション": [["歩行", "モーション"]],
    "ガードEN消費倍率": [
        ["ガードEN消費", "倍率"], ["ガードEN", "消費倍率"]],
    "近接攻撃倍率": [["近接攻撃", "倍率"], ["近接", "攻撃倍率"]],
    "ガード防御倍率": [["ガード防御", "倍率"], ["ガード", "防御倍率"]],
    "ガード速度倍率": [["ガード速度", "倍率"], ["ガード", "速度倍率"]],
    "ステップ速度倍率": [["ステップ速度", "倍率"], ["ステップ", "速度倍率"]],
    "ステップ時間倍率": [["ステップ時間", "倍率"], ["ステップ", "時間倍率"]],
    "EN消費倍率": [["EN消費", "倍率"]],
    "近接ブースト速度": [["近接", "ブースト速度"], ["近接ブースト", "速度"]],
    "近接ブースト時間": [["近接", "ブースト時間"], ["近接ブースト", "時間"]],
    "ガード移行時間": [["ガード移行", "時間"], ["ガード", "移行時間"]],
    "怯み延長秒数": [["怯み延長", "秒数"], ["怯み", "延長秒数"]],
    "攻撃威力（各段）": [["攻撃威力", "（各段）"]],
    "部位破壊威力（各段）": [
        ["部位破壊", "威力（各段）"], ["部位破壊威力", "（各段）"]],
    "怯み蓄積（各段）": [["怯み蓄積", "（各段）"]],
    "攻撃EN消費（各段）": [["攻撃EN消費", "（各段）"], ["攻撃EN", "消費（各段）"]],
    "エネルギーシールド": [["エネルギー", "シールド"]],
    "バッシュ部位破壊": [["バッシュ", "部位破壊"]],
    "溜め部位破壊": [["溜め", "部位破壊"]],
}


static func _stat_text_width(font: Font, content: String, px: int) -> float:
    return font.get_string_size(
        content, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


static func semantic_stat_lines(raw: String, font: Font,
        font_size: int, lane_width: float) -> String:
    var source: String = raw.replace("\n", "")
    if source.is_empty() or font == null or lane_width <= 0.0:
        return source
    if _stat_text_width(font, source, font_size) <= lane_width:
        return source

    var candidates: Array = JAPANESE_STAT_BREAKS.get(source, []).duplicate(true)
    if source.begins_with("特性 "):
        var effect_name: String = source.trim_prefix("特性 ")
        candidates.append(["特性", effect_name])
    # Noncatalogue stats still favor recognisable suffixes and punctuation.
    for suffix in ["（各段）", "モーション", "区分", "倍率",
            "回数", "秒数", "時間", "速度", "消費", "威力", "破壊"]:
        if source.ends_with(suffix) and source.length() >= suffix.length() + 2:
            candidates.append([
                source.substr(0, source.length() - suffix.length()), suffix])
    for candidate in candidates:
        if candidate.size() != 2:
            continue
        var first: String = str(candidate[0]).strip_edges()
        var second: String = str(candidate[1]).strip_edges()
        if first.is_empty() or second.is_empty():
            continue
        if _stat_text_width(font, first, font_size) <= lane_width and (
                _stat_text_width(font, second, font_size) <= lane_width):
            return first + "\n" + second

    # Last resort: favor balanced lines without punctuation, prolonged-sound
    # marks or a one-character orphan at either edge.
    var best: String = ""
    var best_score: float = INF
    for split_at in range(2, source.length() - 1):
        var first: String = source.substr(0, split_at)
        var second: String = source.substr(split_at)
        if second.begins_with("ー") or second.begins_with("）") or (
                first.ends_with("（")) or (
                first.ends_with("E") and second.begins_with("N")):
            continue
        var first_width: float = _stat_text_width(font, first, font_size)
        var second_width: float = _stat_text_width(font, second, font_size)
        if first_width > lane_width or second_width > lane_width:
            continue
        var score: float = absf(first_width - second_width)
        if score < best_score:
            best_score = score
            best = first + "\n" + second
    return best if not best.is_empty() else source


# A single 44px-high metric row: full-height readable text side by side.
# Long Japanese labels may wrap to 2 lines; numbers keep a generous right lane.
# Called only for layout/equipment changes and never per rendered frame.
static func layout_metric_pair(name_label: Label, value_label: Label,
        row_width: float, row_height: float, name_max: int, value_max: int,
        name_min: int, value_min: int) -> void:
    var name_font: Font = name_label.get_theme_font("font")
    var value_font: Font = value_label.get_theme_font("font")
    if name_font == null or value_font == null:
        return
    var name_px: int = name_max
    var value_px: int = value_max
    var left_pad: float = 9.0
    var right_pad: float = 9.0
    var gap: float = 6.0
    var available: float = maxf(32.0,
        row_width - left_pad - right_pad - gap)
    var source_name: String = name_label.text.replace("\n", "")
    var name_width: float = name_font.get_string_size(
        source_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
    var value_width: float = value_font.get_string_size(
        value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value_px).x
    while name_width + value_width > available and (
            name_px > name_min or value_px > value_min):
        if name_px > name_min and (
                name_width >= value_width or value_px <= value_min):
            name_px -= 1
        elif value_px > value_min:
            value_px -= 1
        else:
            break
        name_width = name_font.get_string_size(
            source_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
        value_width = value_font.get_string_size(
            value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value_px).x
    var value_lane: float = minf(
        available * 0.62, maxf(42.0, value_width + 2.0))
    var name_lane: float = maxf(24.0, available - value_lane)
    if name_width > name_lane:
        # Two shorter Japanese lines can fit within 44px at this font size.
        name_px = mini(name_px, 16)
    name_label.add_theme_font_size_override("font_size", name_px)
    value_label.add_theme_font_size_override("font_size", value_px)
    name_label.text = semantic_stat_lines(
        source_name, name_font, name_px, name_lane)
    # Explicit Japanese phrase splits own the line break. Other long,
    # unrecognised labels retain the old defensive auto-wrap fallback.
    name_label.autowrap_mode = TextServer.AUTOWRAP_OFF if (
        name_label.text.contains("\n") or (
        _stat_text_width(name_font, name_label.text, name_px) <= name_lane)
        ) else TextServer.AUTOWRAP_ARBITRARY
    name_label.max_lines_visible = 2
    name_label.position = Vector2(left_pad, 0.0)
    name_label.size = Vector2(name_lane, row_height)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value_label.position = Vector2(left_pad + name_lane + gap, 0.0)
    value_label.size = Vector2(value_lane, row_height)


## One continuous dark matte per stat window. No background on individual rows.
## Small, low-glare edge marks echo SERA's existing technical icon frames.
static func status_window_style() -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("#0c222e")
    skin.border_color = Color("#527b8b")
    skin.set_border_width_all(1)
    skin.border_width_top = 2
    skin.set_corner_radius_all(2)
    return skin


static func attach_status_marks(panel: Panel) -> Array[ColorRect]:
    var marks: Array[ColorRect] = []
    for mark_name in ["StatusTopAccent", "StatusBottomAccent", "StatusRightAccent"]:
        var mark := ColorRect.new()
        mark.name = mark_name
        mark.color = Color("#88b6c6")
        mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(mark)
        marks.append(mark)
    return marks


static func layout_status_marks(marks: Array[ColorRect],
        panel_size: Vector2) -> void:
    if marks.size() != 3:
        return
    marks[0].position = Vector2(14.0, 0.0)
    marks[0].size = Vector2(minf(84.0, maxf(0.0, panel_size.x - 28.0)), 2.0)
    marks[1].position = Vector2(maxf(8.0, panel_size.x - 57.0),
        maxf(0.0, panel_size.y - 2.0))
    marks[1].size = Vector2(43.0, 2.0)
    marks[2].position = Vector2(maxf(0.0, panel_size.x - 2.0), 14.0)
    marks[2].size = Vector2(2.0, 19.0)


static func clear_cell_background(panel: Panel) -> void:
    # The surrounding window, not each data field, owns the single matte.
    var clear := StyleBoxFlat.new()
    clear.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    clear.set_border_width_all(0)
    clear.set_corner_radius_all(0)
    panel.add_theme_stylebox_override("panel", clear)


static func new_column_rule(parent: Control, name: String) -> ColorRect:
    var rule := ColorRect.new()
    rule.name = name
    rule.color = DIVIDER_COLOR
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rule)
    return rule


static func layout_column_rules(rules: Array[ColorRect],
        area: Rect2, columns: int) -> void:
    for i in range(rules.size()):
        var rule: ColorRect = rules[i]
        rule.visible = i < columns - 1
        if rule.visible:
            rule.position = Vector2(
                area.position.x + area.size.x * float(i + 1) / float(columns) - 1.0,
                area.position.y + 9.0)
            rule.size = Vector2(2.0, maxf(2.0, area.size.y - 18.0))


static func baseline_rows(blueprint: String) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for source_line in LaboStats.baseline(blueprint).split("\n"):
        var line: String = str(source_line)
        if line.is_empty() or line == "基礎ステータス":
            continue
        var split_at: int = line.find("  ")
        if split_at <= 0:
            rows.append({"label": line, "value": "—"})
            continue
        rows.append({
            "label": line.substr(0, split_at),
            "value": line.substr(split_at + 2)
        })
    return rows

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

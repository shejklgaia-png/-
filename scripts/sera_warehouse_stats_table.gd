extends RefCounted
## Lightweight three-column warehouse stat display, built only on detail entry.
## A Panel for each cell avoids Label minimum-width expansion on portrait phones.
const LaboStats = preload("res://scripts/sera_labo_stats.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")


static func build(blueprint: String, effects: Variant, viewport_width: float) -> GridContainer:
    var table := GridContainer.new()
    table.name = "WarehouseStatsTable"
    table.columns = 3
    table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    table.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table.add_theme_constant_override("h_separation", 0)
    table.add_theme_constant_override("v_separation", 0)

    # Keep the grid within the LABO content rail, not the fullscreen viewport.
    var available: float = maxf(260.0, viewport_width * 0.87)
    var widths: Array[float] = [
        floorf(available * 0.19),
        floorf(available * 0.59),
        0.0,
    ]
    widths[2] = available - widths[0] - widths[1]
    var compact: bool = viewport_width < 520.0
    var headings: Array[String] = ["項目", "計算式", "合計"]
    for col in range(3):
        _add_cell(table, "Header_" + ["Name", "Formula", "Total"][col],
            headings[col], col, 0, widths, compact)
    var rows: Array[Dictionary] = LaboStats.total_stat_rows(blueprint, effects)
    for i in range(rows.size()):
        var stat: Dictionary = rows[i]
        var effect_id: String = str(stat["id"])
        _add_cell(table, "Stat_name_" + effect_id, str(stat["name"]),
            0, i + 1, widths, compact)
        _add_cell(table, "Stat_formula_" + effect_id, str(stat["formula"]),
            1, i + 1, widths, compact)
        _add_cell(table, "Stat_total_" + effect_id, str(stat["total"]),
            2, i + 1, widths, compact)
    return table


static func _add_cell(table: GridContainer, key: String, value: String,
        col: int, row: int, widths: Array[float], compact: bool) -> void:
    var panel := Panel.new()
    panel.name = key
    panel.clip_contents = true
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.custom_minimum_size = Vector2(widths[col], 36.0 if row == 0 else 39.0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var style := StyleBoxFlat.new()
    style.set_corner_radius_all(0)
    style.bg_color = (Color("#1b3948") if row == 0 else
        Color("#1b3541") if col == 2 else
        Color("#152e3a") if (row % 2 == 0) else Color("#112936"))
    style.border_color = Color("#3e5968")
    style.set_border_width_all(0)
    # One-pixel shared strokes give a light, non-doubled grid.
    style.border_width_top = 1 if row == 0 else 0
    style.border_width_left = 1 if col == 0 else 0
    style.border_width_bottom = 1
    style.border_width_right = 1
    panel.add_theme_stylebox_override("panel", style)
    table.add_child(panel)

    var label := Label.new()
    label.name = "Content"
    label.text = value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if col == 2 else HORIZONTAL_ALIGNMENT_LEFT
    label.add_theme_font_override("font", (LaboSkin.stats_font()
        if col == 1 else LaboSkin.equipment_font()
        if row > 0 else LaboSkin.control_font()))
    label.add_theme_font_size_override("font_size", (
        13 if compact and row == 0 else
        14 if compact and col == 1 else
        16 if compact else
        15 if row == 0 else
        17 if col == 1 else 19))
    label.add_theme_color_override("font_color", (
        Color("#a5c8d0") if row == 0 else
        Color("#f0f6f7") if col == 2 else
        Color("#d7e8ec") if col == 0 else
        Color("#a7c7d1")))
    panel.add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.offset_left = 8.0
    label.offset_top = 2.0
    label.offset_right = -8.0
    label.offset_bottom = -2.0

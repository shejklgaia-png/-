extends SceneTree
## Godot UI contract: three aligned columns, thin grid, readable emphasis.
const TableBuilder = preload("res://scripts/sera_warehouse_stats_table.gd")
const Stats = preload("res://scripts/sera_labo_stats.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_WAREHOUSE_STATUS_TABLE_FAIL: " + why)
    quit(1)

func _cell(table: GridContainer, name: String) -> Label:
    return table.get_node_or_null(name + "/Content") as Label

func _run() -> void:
    root.size = Vector2i(720, 1280)
    # A real crafted item has exactly five distinct 1..5% effects.
    # The previous two-entry/8% fixture was rejected by Affixes.sanitize,
    # so the displayed result was correctly the base value.
    var sample_effects: Array = [
        {"id": "hp", "value": 4},
        {"id": "defense", "value": 2},
        {"id": "energy_recovery", "value": 3},
        {"id": "boost", "value": 4},
        {"id": "guard", "value": 5},
    ]
    if not Affixes.valid(sample_effects):
        _fail("stat fixture must match five distinct crafted effects (1..5%)")
        return
    var rows: Array[Dictionary] = Stats.total_stat_rows("H01", sample_effects)
    if rows.size() != Affixes.EFFECT_IDS.size():
        _fail("the table must display every equipment stat, including zeros")
        return
    var table: GridContainer = TableBuilder.build("H01", sample_effects, 720.0)
    root.add_child(table)
    await process_frame
    await process_frame
    if table.columns != 3 or table.get_child_count() != (rows.size() + 1) * 3:
        _fail("three columns and a header + eight full rows required")
        return
    for heading in ["Header_Name", "Header_Formula", "Header_Total"]:
        if _cell(table, heading) == null:
            _fail("missing header: " + heading)
            return
    var width_sum: float = 0.0
    for i in range(3):
        var panel: Panel = table.get_child(i) as Panel
        var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
        if style == null or style.border_width_bottom != 1 or (
                style.border_width_right != 1):
            _fail("each table cell must have a subtle grid border")
            return
        width_sum += panel.custom_minimum_size.x
    if width_sum > 680.0:
        _fail("wide stat table exceeds the 720px LAB content region")
        return
    var formula_width: float = (table.get_child(1) as Control).custom_minimum_size.x
    if formula_width <= (table.get_child(0) as Control).custom_minimum_size.x or (
            formula_width <= (table.get_child(2) as Control).custom_minimum_size.x):
        _fail("formula column must be the widest cell")
        return
    for row: Dictionary in rows:
        var effect_id: String = str(row["id"])
        var name: Label = _cell(table, "Stat_name_" + effect_id)
        var formula: Label = _cell(table, "Stat_formula_" + effect_id)
        var total: Label = _cell(table, "Stat_total_" + effect_id)
        if name == null or formula == null or total == null:
            _fail("missing full three-cell row: " + effect_id)
            return
        if name.text != str(row["name"]) or (
                formula.text != str(row["formula"])) or (
                total.text != str(row["total"])):
            _fail("row cell contents mismatch: " + effect_id)
            return
        if total.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
            _fail("results must all be right-aligned in the last column")
            return
        if name.get_theme_font_size("font_size") <= formula.get_theme_font_size("font_size") or (
                total.get_theme_font_size("font_size") <= formula.get_theme_font_size("font_size")):
            _fail("stat label and total need stronger visual hierarchy")
            return
    if _cell(table, "Stat_total_hp").text != "20.8" or (
            _cell(table, "Stat_total_defense").text != "18.0%"):
        _fail("HP and defense calculations were changed during the UI refactor")
        return
    for node in table.get_children():
        var label: Label = (node as Panel).get_node("Content") as Label
        if label.text.contains("戦闘計算へ未接続") or label.text.contains("注:"):
            _fail("obsolete annotation must not appear in the status table")
            return
    print("SERA_WAREHOUSE_STATUS_TABLE_RUNTIME_PASS")
    quit(0)

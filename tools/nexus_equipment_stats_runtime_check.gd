extends SceneTree
## Exercise real NEXUS UI, A/B equipment changes and zero-value filtering.
const StatRows = preload("res://scripts/sera_nexus_stat_rows.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NEXUS_EQUIPMENT_STATS_RUNTIME_FAIL: " + message)
    quit(1)

func _value(rows: Array[Dictionary], label: String) -> String:
    for row in rows:
        if str(row["label"]) == label:
            return str(row["value"])
    return ""

func _run() -> void:
    var only_nonzero: Array[Dictionary] = StatRows.from_stats({
        "max_hp": 0.0, "defense": 0.0, "attack_damage": [0, 0, 0],
        "attack_energy": [0.0, 0.0, 0.0], "run_speed": 3.25
    })
    if only_nonzero.size() != 1 or str(only_nonzero[0]["label"]) != "走行速度":
        _fail("zero-valued entries must be completely hidden")
        return
    var a: Array[Dictionary] = StatRows.from_selection({
        "head": "A", "torso": "A", "arms": "A", "legs": "A",
        "booster": "A", "weapon_r": "A", "weapon_l": "A"
    })
    var b: Array[Dictionary] = StatRows.from_selection({
        "head": "B", "torso": "B", "arms": "B", "legs": "B",
        "booster": "B", "weapon_r": "B", "weapon_l": "B"
    })
    if _value(a, "耐久力") != "320.0" or _value(b, "耐久力") != "416.0":
        _fail("HP must derive from existing equipped part profiles")
        return
    if _value(a, "攻撃EN消費") != "" or _value(b, "攻撃EN消費") != "5.3EN":
        _fail("zero A weapon EN cost should hide; B cost should appear")
        return

    if _value(a, "重量") != "100.0%" or (
            _value(b, "重量").is_empty()):
        _fail("dynamic equipment weight class must appear in Japanese")
        return
    if _value(a, "ダメージ") != "16.7" or (
            _value(b, "ダメージ") != "23.3") or (
            _value(a, "破壊") != "20.0") or (
            _value(b, "怯み") != "23.7"):
        _fail("right weapon stats must average all three attacks to one decimal")
        return
    if _value(a, "バッシュダメージ") != "12.0" or (
            _value(b, "バッシュダメージ") != "16.0") or (
            _value(a, "ガード移行") != "0.1s"):
        _fail("left-hand weapon stats must reflect the actual equipped shield")
        return
    var katana: Array[Dictionary] = StatRows.from_selection({
        "head": "A", "torso": "A", "arms": "A", "legs": "A",
        "booster": "A", "weapon_r": "K", "weapon_l": "B"
    })
    if not _value(katana, "バッシュダメージ").is_empty() or (
            not _value(katana, "ガード移行").is_empty()):
        _fail("two-handed Katana must hide unavailable left-hand weapon stats")
        return
    var body_seen: bool = false
    var weapon_seen: bool = false
    for row in b:
        if str(row.get("group", "")) == "body":
            if weapon_seen:
                _fail("body stats appeared after the weapon divider")
                return
            body_seen = true
        elif str(row.get("group", "")) == "weapon":
            weapon_seen = true
    if not body_seen or not weapon_seen:
        _fail("body/weapon groups were not separated")
        return
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    var hud: Control = nexus.get("hud") as Control
    var scroll: ScrollContainer = nexus.get("customize_stats_scroll") as ScrollContainer
    var grid: GridContainer = nexus.get("customize_stats_grid") as GridContainer
    var weapon_divider: ColorRect = nexus.get("customize_weapon_divider") as ColorRect
    var cells: Array = nexus.get("customize_stat_cells")
    if hud == null or scroll == null or grid == null or cells.size() < 21 or (
            weapon_divider == null or not weapon_divider.visible):

        _fail("top-wide aggregate status or weapon divider not initialized")
        return
    if scroll.get_parent() != hud or grid.columns < 1 or grid.columns > 3:
        _fail("aggregate stats must be above model in adaptive columns")
        return
    if not scroll.visible or scroll.position.y < 0.0 or (
            scroll.position.y + scroll.size.y > hud.size.y * 0.27) or (
            scroll.position.x + scroll.size.x > hud.size.x + 1.0):
        _fail("stats must appear entirely at top of CUSTOMIZE screen")
        return
    for stat_cell in cells:
        if stat_cell["rule"] == null or not (
                stat_cell["rule"] is ColorRect):
            _fail("Blue-grey vertical column dividers absent")
            return
    var rules: Array = nexus.get("customize_total_column_rules") as Array
    if rules.size() != 2 or not (rules[0] as ColorRect).visible or (
            not (rules[1] as ColorRect).visible):
        _fail("full-height column separators are missing from total stats")
        return
    for line in rules:
        var divider: ColorRect = line as ColorRect
        if divider.size.y < 185.0 or divider.color != Color("#35515f"):
            _fail("total column dividers should be continuous dark-blue-grey rails")
            return
    var sample_panel: Panel = cells[0]["panel"] as Panel
    var sample_skin: StyleBoxFlat = sample_panel.get_theme_stylebox("panel") as StyleBoxFlat
    if sample_skin == null or sample_skin.bg_color.a > 0.01 or (
            sample_skin.border_width_bottom != 0):
        _fail("TOTAL STATUS must use one continuous matte, not per-cell boxes")
        return
    var total_panel: Panel = nexus.get("customize_stats_panel") as Panel
    var part_panel: Panel = nexus.get("customize_part_stats_panel") as Panel
    for status_window in [total_panel, part_panel]:
        if status_window == null:
            _fail("missing status window")
            return
        var matte: StyleBoxFlat = status_window.get_theme_stylebox("panel") as StyleBoxFlat
        if matte == null or matte.bg_color != Color("#0c222e") or (
                matte.border_color != Color("#527b8b")):
            _fail("aggregate and individual status must share the premium matte")
            return
        var top_mark: ColorRect = status_window.get_node_or_null(
            "StatusTopAccent") as ColorRect
        var bottom_mark: ColorRect = status_window.get_node_or_null(
            "StatusBottomAccent") as ColorRect
        if top_mark == null or bottom_mark == null or (
                top_mark.color != Color("#88b6c6") or top_mark.size.x < 45.0 or (
                bottom_mark.size.x < 25.0)):
            _fail("technical panel accents missing or mis-sized")
            return
    var typography_ok: bool = false
    for entry in cells:
        var stat_panel: Panel = entry["panel"] as Panel
        if not stat_panel.visible:
            continue
        var title: Label = entry["name"] as Label
        var amount: Label = entry["value"] as Label
        if title.get_global_rect().end.x > amount.get_global_rect().position.x + 2.0 or (
                amount.get_global_rect().end.x > stat_panel.get_global_rect().end.x + 1.0):
            _fail("enlarged full-body metric labels overlap or overflow horizontally")
            return
        if amount.position.y + amount.size.y > stat_panel.size.y + 1.0 or (
                title.position.y + title.size.y > stat_panel.size.y + 1.0):
            _fail("enlarged full-body metric text exceeds its row height")
            return
        if scroll.size.x >= 590.0 and not scroll.get_global_rect().encloses(
                stat_panel.get_global_rect()):
            _fail("720px full-body status requires no vertical scrolling")
            return
        if title.text == "耐久力":
            typography_ok = title.get_theme_font_size("font_size") >= 19 and (
                amount.get_theme_font_size("font_size") >= 24)
    if not typography_ok:
        _fail("full-body Japanese label/number type is still too small")
        return
    if weapon_divider.size.x < scroll.size.x * 0.8 or (
            weapon_divider.color != Color("#55798a")):
        _fail("weapon attack/defense status divider must span the same status window")
        return
    var seen: Dictionary = {}
    for cell in cells:
        if (cell["panel"] as Panel).visible:
            var name: String = (cell["name"] as Label).text
            var value: String = (cell["value"] as Label).text
            if name.is_empty() or value.is_empty() or value in ["0", "0.0", "0%"]:
                _fail("visible stat has missing or zero content")
                return
            seen[name] = value
    if not seen.has("耐久力") or not seen.has("防御"):
        _fail("HP/DEF were not painted in the status cells")
        return

    var rig: Node = nexus.get("sera_display_rig") as Node
    if rig == null:
        _fail("missing preview equipment rig")
        return
    var previous: String = str(rig.call("get_equipment_selection", "torso"))
    var target: String = "B" if previous != "B" else "A"
    var handler: Object = rig.get("equipment_handler")
    if not bool(handler.call("select_part", "torso", target, false)):
        _fail("unable to switch torso profile for live status test")
        return
    nexus.call("_refresh_equipment_controls")
    var next_hp: String = ""
    for cell in cells:
        if (cell["panel"] as Panel).visible and (
                (cell["name"] as Label).text == "耐久力"):
            next_hp = (cell["value"] as Label).text
    if next_hp.is_empty() or next_hp == str(seen["耐久力"]):
        _fail("HP did not update after the actual preview equipment changed")
        return
    handler.call("select_part", "torso", previous, false)
    nexus.call("_refresh_equipment_controls")

    nexus.set("focused_target", "SYSTEM")
    nexus.call("_focus_arrived", "SYSTEM")
    if scroll.visible:
        _fail("CUSTOMIZE stats leaked to unrelated pages")
        return
    print("NEXUS_EQUIPMENT_STATS_RUNTIME_PASS")
    quit(0)

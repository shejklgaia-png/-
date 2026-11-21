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
    if only_nonzero.size() != 1 or str(only_nonzero[0]["label"]) != "RUN":
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
    if _value(a, "HP") != "160" or _value(b, "HP") != "208":
        _fail("HP must derive from existing equipped part profiles")
        return
    if _value(a, "ATK EN") != "" or _value(b, "ATK EN") != "4":
        _fail("zero A weapon EN cost should hide; B cost should appear")
        return

    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    var focus: Panel = nexus.get("focus_panel") as Panel
    var scroll: ScrollContainer = nexus.get("customize_stats_scroll") as ScrollContainer
    var grid: GridContainer = nexus.get("customize_stats_grid") as GridContainer
    var cells: Array = nexus.get("customize_stat_cells")
    if focus == null or scroll == null or grid == null or cells.size() < 8:
        _fail("lower-left status UI not initialized")
        return
    if not scroll.visible or scroll.position.y < 0.0 or (
            scroll.position.y + scroll.size.y > focus.size.y + 1.0):
        _fail("stats should appear entirely inside the lower-left window")
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
    if not seen.has("HP") or not seen.has("DEF"):
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
                (cell["name"] as Label).text == "HP"):
            next_hp = (cell["value"] as Label).text
    if next_hp.is_empty() or next_hp == str(seen["HP"]):
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

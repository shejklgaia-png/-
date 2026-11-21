extends SceneTree
## Runtime: real NEXUS overlay, five destination panels, typography and controls.
const Skin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("NEXUS_LABO_VISUAL_RUNTIME_FAIL: " + why)
    quit(1)
func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    var hud: Control = nexus.get("hud") as Control
    var focus: Panel = nexus.get("focus_panel") as Panel
    var right: Panel = nexus.get("customize_right_panel") as Panel
    if hud == null or hud.theme == null or focus == null or right == null:
        _fail("NEXUS did not initialize its themed overlay")
        return
    var body: StyleBoxFlat = focus.get_theme_stylebox("panel") as StyleBoxFlat
    if body == null or body.bg_color.a < 0.90:
        _fail("3D focus menu did not get LABO's opaque matte contrast")
        return
    var title: Label = nexus.get("focus_title") as Label
    var exit_label: Label = nexus.get("explore_label") as Label
    if title.get_theme_font("font") != Skin.tracked_display_font() or (
            exit_label.get_theme_font("font") != Skin.tracked_display_font()):
        _fail("NEXUS top-level titles lack LABO's bundled display font")
        return
    var equipment: Dictionary = nexus.get("customize_equipment_rows")
    if equipment.size() != 7:
        _fail("seven existing equipment selectors must be preserved")
        return
    for slot in equipment:
        var row: Panel = equipment[slot]["panel"]
        if row.get_theme_stylebox("panel") != Skin.card_style("normal"):
            _fail("equipment row not using cached LABO chamfered card: " + str(slot))
            return
        if (equipment[slot]["value"] as Label).get_theme_font("font") != Skin.equipment_font():
            _fail("equipment row lacks LABO's item-name typeface")
            return
    for target in ["TRAINING", "DEPLOYMENT", "SYSTEM", "DATA ARCHIVE", "CUSTOMIZE"]:
        nexus.set("focused_target", target)
        nexus.call("_focus_arrived", target)
        await process_frame
        if not focus.visible or title.text != target:
            _fail("destination panel not visible: " + target)
            return
        if target == "CUSTOMIZE":
            if not right.visible:
                _fail("customization equipment panel disappeared")
                return
            for slot in equipment:
                var row: Panel = equipment[slot]["panel"]
                if row.position.y < 0 or row.position.y + row.size.y > right.size.y + 1.0:
                    _fail("equipment row falls outside the customize panel")
                    return
        elif right.visible:
            _fail("customize panel leaked into " + target)
            return
    var slots: Array = nexus.get("system_slot_rows")
    if slots.size() != 3:
        _fail("save slot count changed")
        return
    var active_index: int = int(nexus.get("system_selected_slot")) - 1
    var selected: Panel = slots[active_index]["panel"]
    if selected.get_theme_stylebox("panel") != Skin.card_style("selected"):
        _fail("selected system save must show LABO active card")
        return
    var tabs: Array = nexus.get("archive_record_tabs")
    if tabs.size() != 4 or (
            (tabs[0]["panel"] as Panel).get_theme_stylebox("panel") !=
            Skin.terminal_segment_style("selected")):
        _fail("data archive tabs are not shared LABO segments")
        return
    var start: Panel = nexus.get("action_panel") as Panel
    if start == null or start.get_theme_stylebox("panel") == null:
        _fail("training launch action was removed")
        return
    print("NEXUS_LABO_VISUAL_RUNTIME_PASS")
    quit(0)

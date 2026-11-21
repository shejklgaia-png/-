extends SceneTree
## Runtime: real NEXUS overlay, five destination panels, typography and controls.
const LaboTypeface = preload("res://scripts/sera_labo_round_skin.gd")
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
    if title.get_theme_font("font") != LaboTypeface.tracked_display_font() or (
            exit_label.get_theme_font("font") != LaboTypeface.tracked_display_font()):
        _fail("NEXUS top-level titles lack LABO's bundled display font")
        return
    var equipment: Dictionary = nexus.get("customize_equipment_rows")
    if equipment.size() != 7:
        _fail("seven existing equipment selectors must be preserved")
        return
    for slot in equipment:
        var button: Button = equipment[slot]["panel"] as Button
        if button == null or (
                button.get_theme_stylebox("normal") !=
                LaboTypeface.terminal_segment_style("normal")):
            _fail("name-only equipment button lacks the shared LABO skin: "+str(slot))
            return
        if button.get_theme_font("font") != LaboTypeface.equipment_font():
            _fail("equipment-name button lacks the item font")
            return
        if button.get_child_count() != 0:
            _fail("equipment selector must not have old icon/code columns")
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
                var button: Button = equipment[slot]["panel"] as Button
                if button.position.y < 0.0 or (
                        button.position.y + button.size.y > right.size.y + 1.0):
                    _fail("name selector outside right customize window")
                    return
                if button.text.is_empty() or button.text.contains("SET"):
                    _fail("part selector must display the actual part name only")
                    return
            var picker: Control = nexus.get("customize_part_picker") as Control
            var part_preview: Control = nexus.get("customize_single_part_preview") as Control
            if picker == null or part_preview == null:
                _fail("NEXUS missing the scrolling picker or left 3D part")
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
    if selected.get_theme_stylebox("panel") != LaboTypeface.card_style("selected"):
        _fail("selected system save must show LABO active card")
        return
    var tabs: Array = nexus.get("archive_record_tabs")
    if tabs.size() != 4 or (
            (tabs[0]["panel"] as Panel).get_theme_stylebox("panel") !=
            LaboTypeface.terminal_segment_style("selected")):
        _fail("data archive tabs are not shared LABO segments")
        return
    var start: Panel = nexus.get("action_panel") as Panel
    if start == null or start.get_theme_stylebox("panel") == null:
        _fail("training launch action was removed")
        return
    print("NEXUS_LABO_VISUAL_RUNTIME_PASS")
    quit(0)

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
        var row: Panel = equipment[slot]["panel"]
        if row.get_theme_stylebox("panel") != LaboTypeface.card_style("normal"):
            _fail("equipment row not using cached LABO chamfered card: " + str(slot))
            return
        if (equipment[slot]["value"] as Label).get_theme_font("font") != LaboTypeface.equipment_font():
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
                var icon: TextureRect = equipment[slot]["equipped_icon"] as TextureRect
                var item_name: Label = equipment[slot]["value"] as Label
                var model_code: Label = equipment[slot]["model_code"] as Label
                if icon == null or item_name == null or model_code == null:
                    _fail("equipment needs separate icon, name and model-code nodes")
                    return
                if item_name.position.x < icon.position.x + icon.size.x + 12.0:
                    _fail("equipment icon overlaps the item name")
                    return
                if item_name.position.x + item_name.size.x > row.size.x - 5.0:
                    _fail("equipment name exceeds the card right edge")
                    return
                if model_code.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT or (
                        model_code.position.x + model_code.size.x > row.size.x - 5.0 or
                        model_code.position.y + model_code.size.y > row.size.y + 1.0):
                    _fail("model code is not inside the bottom-right corner")
                    return
                if (model_code.get_theme_font_size("font_size") >=
                        item_name.get_theme_font_size("font_size")):
                    _fail("model code must use smaller type than the item name")
                    return
                var code_tint: Color = model_code.get_theme_color("font_color")
                if code_tint.r > 0.73 or code_tint.g > 0.73 or code_tint.b > 0.73:
                    _fail("model-code tint must be muted gray")
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

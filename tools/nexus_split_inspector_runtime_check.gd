extends SceneTree
## Exercise actual NEXUS input routing, separate geometry and live component profile.
const Profiles = preload("res://scripts/sera_labo_stats.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NEXUS_SPLIT_INSPECTOR_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    var total: Panel = nexus.get("customize_stats_panel") as Panel
    var single: Panel = nexus.get("customize_part_stats_panel") as Panel
    var right: Panel = nexus.get("customize_right_panel") as Panel
    var view: Panel = nexus.get("focus_panel") as Panel
    var total_scroll: ScrollContainer = nexus.get("customize_stats_scroll") as ScrollContainer
    var single_scroll: ScrollContainer = nexus.get("customize_part_stats_scroll") as ScrollContainer
    var single_name: Label = nexus.get("customize_part_stats_name") as Label
    if total == null or single == null or right == null or view == null or (
            total_scroll == null or single_scroll == null or single_name == null):
        _fail("separate total, part and preview windows were not constructed")
        return
    if not total.visible or not single.visible or not right.visible or not view.visible:
        _fail("one of the new CUSTOMIZE windows is not visible")
        return
    var hud: Control = nexus.get("hud") as Control
    var part_preview: Control = nexus.get("customize_single_part_preview") as Control
    if hud == null or part_preview == null:
        _fail("CUSTOMIZE viewport / part preview missing")
        return
    # Slightly smaller than prior 0.450x0.198 part view and 0.915-high stats.
    if absf(view.position.y - hud.size.y * 0.506) > 1.5 or (
            absf(view.size.y - hud.size.y * 0.185) > 1.5) or (
            absf(single.size.y - hud.size.y * 0.214) > 1.5) or (
            absf(single.position.x - hud.size.x * 0.040) > 1.5):
        _fail("smaller linked part view/status geometry not applied")
        return
    if part_preview.size.x >= hud.size.y * 0.189 or (
            part_preview.size.y >= hud.size.y * 0.189):
        _fail("single-part 3D preview did not shrink")
        return
    var equipment_bottom: float = right.position.y + right.size.y
    if total.position.y + total.size.y > right.position.y - 4.0 or (
            absf(view.position.y + view.size.y - single.position.y) > 1.5) or (
            equipment_bottom > single.position.y - 4.0) or (
            single.position.x > total.position.x + 1.0) or (
            single.size.x < total.size.x - 2.0) or (
            view.position.x + view.size.x > right.position.x - 4.0):
        _fail("customize windows overlap or exceed their aligned layout region")
        return
    var preview_outline: Control = nexus.get("customize_part_preview_frame") as Control
    var part_rules: Array = nexus.get("customize_part_column_rules") as Array
    if preview_outline == null or not preview_outline.visible or (
            part_rules.size() != 2 or not (part_rules[0] as ColorRect).visible or (
            not (part_rules[1] as ColorRect).visible)):
        _fail("linked chamfer preview / full-height column dividers absent")
        return
    var part_top_mark: ColorRect = single.get_node_or_null(
        "StatusTopAccent") as ColorRect
    if part_top_mark == null or part_top_mark.size.x < 45.0 or (
            part_top_mark.position.x < 8.0):
        _fail("individual part status frame lacks its restrained blue-grey accent")
        return
    if single_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("PART STATUS must be visible without scrolling")
        return
    if not total.get_global_rect().encloses(total_scroll.get_global_rect()) or (
            not single.get_global_rect().encloses(single_scroll.get_global_rect())):
        _fail("status scrolls must be contained inside their respective windows")
        return
    var items: Dictionary = nexus.get("customize_equipment_rows")
    var rig: Node = nexus.get("sera_display_rig") as Node
    var picker: Control = nexus.get("customize_part_picker") as Control
    var head_row: Button = items["head"]["panel"] as Button
    var head_expand: Button = items["head"]["expand"] as Button
    var previous_model: String = str(rig.call("get_equipment_selection", "head"))
    nexus.call("_tap_equipment_control", head_row.get_global_rect().position + Vector2(28.0, head_row.size.y * 0.5))
    if picker.visible:
        _fail("tapping the equipment NAME must not open equipment selection")
        return
    if str(nexus.get("customize_part_preview_slot")) != "head" or (
            single_name.text != head_row.text) or (
            not (nexus.get("customize_single_part_preview") as Control).visible):
        _fail("name tap must show equipped head name, stat and 3D preview")
        return
    if str(rig.call("get_equipment_selection", "head")) != previous_model:
        _fail("inspecting the name must never change equipment")
        return
    var entries: Array = nexus.get("customize_part_stat_cells") as Array
    var found_hp: bool = false
    for entry in entries:
        if (entry["panel"] as Panel).visible and (
                (entry["name"] as Label).text == "HP"):
            found_hp = not (entry["value"] as Label).text.is_empty()
    await process_frame
    for entry in entries:
        var row: Panel = entry["panel"] as Panel
        var cell_skin: StyleBoxFlat = row.get_theme_stylebox("panel") as StyleBoxFlat
        if cell_skin == null or cell_skin.bg_color.a > 0.01 or (
                cell_skin.border_width_bottom != 0):
            _fail("PART STATUS must be one matte, not a grid of outlined tiles")
            return
        if row.visible and not single_scroll.get_global_rect().encloses(row.get_global_rect()):
            _fail("visible PART STATUS row clipped from non-scroll grid")
            return
        if row.visible:
            var key: Label = entry["name"] as Label
            var num: Label = entry["value"] as Label
            if key.get_global_rect().end.x > num.get_global_rect().position.x + 2.0 or (
                    num.get_global_rect().end.x > row.get_global_rect().end.x + 1.0):
                _fail("large PART STATUS text overlaps or clips across columns")
                return
    if (entries[0]["name"] as Label).get_theme_font_size("font_size") < 18 or (
            (entries[0]["value"] as Label).get_theme_font_size("font_size") < 23):
        _fail("PART STATUS uses undersized typography")
        return
    if not found_hp:
        _fail("single part statistics must contain the equipped head HP")
        return
    # Largest real part profile has 10 nonzero fields; crafted items may have
    # five independent affixes. Simulate all fifteen populated cells.
    for i in range(entries.size()):
        (entries[i]["panel"] as Panel).visible = i < 15
    await process_frame
    for i in range(15):
        var stat_cell: Panel = entries[i]["panel"] as Panel
        if not single_scroll.get_global_rect().encloses(stat_cell.get_global_rect()):
            _fail("15-part-field grid clipped a value without scroll")
            return
    nexus.call("_refresh_customization_part_stats", "head")
    nexus.call("_tap_equipment_control", head_expand.get_global_rect().get_center())
    if not picker.visible:
        _fail("right-side thumbnail button must still open equipment selector")
        return
    nexus.call("_close_customization_part_picker")
    nexus.call("_tap_equipment_control", (items["torso"]["panel"] as Button).get_global_rect().position + Vector2(28.0, 28.0))
    if picker.visible or str(nexus.get("customize_part_preview_slot")) != "torso":
        _fail("switching inspected part must update viewer without selector")
        return
    nexus.set("focused_target", "SYSTEM")
    nexus.call("_focus_arrived", "SYSTEM")
    if total.visible or single.visible:
        _fail("customize-only statistic windows leaked onto other pages")
        return
    print("NEXUS_SPLIT_INSPECTOR_RUNTIME_PASS")
    quit(0)

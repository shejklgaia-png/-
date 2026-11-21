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
    var equipment_bottom: float = right.position.y + right.size.y
    if total.position.y + total.size.y > right.position.y - 4.0 or (
            view.position.y + view.size.y > single.position.y - 4.0) or (
            equipment_bottom > single.position.y - 4.0) or (
            single.position.x > total.position.x + 1.0) or (
            single.size.x < total.size.x - 2.0) or (
            view.position.x + view.size.x > right.position.x - 4.0):
        _fail("customize windows overlap or exceed their aligned layout region")
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
        if row.visible and not single_scroll.get_global_rect().encloses(row.get_global_rect()):
            _fail("visible PART STATUS row clipped from non-scroll grid")
            return
    if not found_hp:
        _fail("single part statistics must contain the equipped head HP")
        return
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

extends SceneTree
## Render-independent structural validation; final composition still needs Android screenshot review.
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("NEXUS_PART_PICKER_DESIGN_RUNTIME_FAIL: " + why)
    quit(1)
func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    nexus.call("_show_customization_part_picker", "head")
    await process_frame
    await process_frame
    var picker: Control = nexus.get("customize_part_picker") as Control
    var window: Panel = nexus.get("customize_part_picker_window") as Panel
    var scroll: ScrollContainer = nexus.get("customize_part_picker_scroll") as ScrollContainer
    var grid: GridContainer = nexus.get("customize_part_grid") as GridContainer
    if picker == null or not picker.visible or window == null or scroll == null or grid == null:
        _fail("head selection modal did not open")
        return
    if grid.columns != 3 or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("picker must be three fixed columns with only vertical scrolling")
        return
    if window.get_node_or_null("CustomizePartPickerHeaderRule") == null or (
            window.get_node_or_null("CustomizePartPickerClose") == null):
        _fail("matte header must have its separated close control and accent rule")
        return
    var title: Label = nexus.get("customize_part_picker_title") as Label
    if title == null or title.text.find("SELECT PART") < 0 or title.text.contains("×"):
        _fail("title and close control should be separate")
        return
    var cells: Array = nexus.get("customize_part_picker_cells") as Array
    if cells.is_empty():
        _fail("no equipment choices")
        return
    var selected_count: int = 0
    for entry in cells:
        var card: Button = entry["button"] as Button
        var art: TextureRect = entry["art"] as TextureRect
        if card == null or art == null or art.texture == null:
            _fail("equipment card missing real thumbnail")
            return
        if card.size.x > scroll.size.x / 3.0:
            _fail("card exceeds a three-column slot")
            return
        var title_node: Label = card.find_child("ChoiceName", true, false) as Label
        var uid_node: Label = card.find_child("ChoiceUID", true, false) as Label
        if title_node == null or uid_node == null or (
                title_node.get_node_or_null("NameUnderline") == null):
            _fail("card lacks name-only underline or instance-code row")
            return
        if title_node.get_theme_font("font") != LaboSkin.equipment_font():
            _fail("item names must use UDEV equipment type")
            return
        if uid_node.get_theme_font("font") != LaboSkin.tracked_data_font():
            _fail("instance codes must use Moralerspace type")
            return
        if card.get_theme_stylebox("normal") == LaboSkin.card_style("selected"):
            selected_count += 1
    if selected_count != 1:
        _fail("exactly one installed item should have the selected outline")
        return
    var point: Vector2 = window.position + Vector2(window.size.x - 24, 24)
    nexus.call("_tap_customization_part_picker", point)
    if picker.visible:
        _fail("header close tap failed")
        return
    print("NEXUS_PART_PICKER_DESIGN_RUNTIME_PASS")
    quit(0)

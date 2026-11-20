extends SceneTree
## Verify direct VBox flow and strict single-selected tabs, not merely button nodes.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V524_LAYOUT_TABS_FAIL: " + why)
    quit(1)
func _selected_count(tabs: HBoxContainer) -> int:
    var total: int = 0
    for child in tabs.get_children():
        if child is Button and (child as Button).button_pressed:
            total += 1
    return total
func _check_flow(fac: Node3D, page_name: String, first_card: String, expected: int) -> bool:
    var layer: VBoxContainer = fac.get("item_layer") as VBoxContainer
    var content: VBoxContainer = layer.get_parent() as VBoxContainer
    var actions: Control = fac.get("actions_area") as Control
    var body_label: Label = fac.get("modal_body") as Label
    if layer == null or content == null or content.name != "FacilityContent":
        _fail("item layer is not directly inside known-working FacilityContent")
        return false
    if not (content.get_child(content.get_child_count()-1) is Button):
        _fail("close button must follow cards and expandable spacer")
        return false
    if actions.get_index() >= layer.get_index():
        _fail("control actions must be before the visible item list")
        return false
    if layer.get_child_count() != 1:
        _fail("one expected card grid is missing")
        return false
    var grid: VBoxContainer = layer.get_child(0) as VBoxContainer
    if grid.name != page_name or grid.get_child_count() != ceili(float(expected)/3.0):
        _fail("missing card rows for " + page_name)
        return false
    var card: Button = grid.find_child(first_card, true, false) as Button
    if card == null or not card.is_visible_in_tree() or card.icon == null:
        _fail("first item missing from live layout: " + first_card)
        return false
    var back: Button = content.find_child("CloseFacility", false, false) as Button
    if back == null:
        _fail("back control not present in body")
        return false
    var rect: Rect2 = card.get_global_rect()
    var label_rect: Rect2 = body_label.get_global_rect()
    if rect.size.x < 80.0 or rect.size.y < 80.0 or rect.position.y <= label_rect.end.y:
        _fail("item rect collapsed or overlaps body label")
        return false
    if grid.get_global_rect().end.y > back.get_global_rect().position.y + 1.5:
        _fail("card list overlaps close button")
        return false
    return true
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var craft: Button = tabs.get_node("TabCraft") as Button
    var materials: Button = tabs.get_node("TabMaterials") as Button
    var warehouse: Button = tabs.get_node("TabWarehouse") as Button
    if craft.button_group == null or craft.button_group != materials.button_group or craft.button_group != warehouse.button_group:
        _fail("section tabs are not a single exclusive ButtonGroup")
        return
    if _selected_count(tabs) != 1 or not craft.button_pressed:
        _fail("craft is not the only selected tab")
        return
    if not _check_flow(fac, "PrototypeGrid", "PrototypeIcon_H01", 7):
        return
    materials.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not materials.button_pressed or str(fac.get("page")) != "families":
        _fail("material section tap left more than one selected tab")
        return
    if not _check_flow(fac, "MaterialFamilyGrid", "MaterialIcon_scrap_low", 12):
        return
    warehouse.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not warehouse.button_pressed:
        _fail("warehouse section tab is not exclusive")
        return
    if not _check_flow(fac, "WarehouseMaterials", "MaterialIcon_scrap_low", 12):
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var mat_tab: Button = actions.find_child("WarehouseMaterialsTab", true, false) as Button
    var gear_tab: Button = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    if mat_tab.button_group == null or mat_tab.button_group != gear_tab.button_group:
        _fail("warehouse category buttons do not share a ButtonGroup")
        return
    gear_tab.pressed.emit()
    await process_frame
    # _show_inventory destroys/rebuilds category buttons every switch.
    # Re-query the newly created controls before checking their state.
    mat_tab = actions.find_child("WarehouseMaterialsTab", true, false) as Button
    gear_tab = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    if mat_tab == null or gear_tab == null or (
            mat_tab.button_pressed or not gear_tab.button_pressed):
        _fail("warehouse category tabs are both selected")
        return
    if not _check_flow(fac, "WarehouseEquipment", "WarehouseBlueprint_H01", 7):
        return
    craft.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not craft.button_pressed:
        _fail("switching back to craft leaves two tabs highlighted")
        return
    print("SERA_V524_LAYOUT_TABS_RUNTIME_PASS: exclusive tabs, body-native card rows, proper top and bottom")
    quit(0)

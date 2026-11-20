extends SceneTree
## SERA v540: live Godot checks for 20 craft slots, 999 virtual slots and visual states.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V540_LABO_VISUAL_SLOTS_FAIL: " + message)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var panel: PanelContainer = fac.get("modal_panel") as PanelContainer
    if not panel.get_theme_stylebox("panel") is StyleBoxTexture:
        _fail("main menu has no cached gradient texture")
        return
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var selected: ColorRect = tabs.get_node("TabCraft/SelectedTabMark") as ColorRect
    var inactive: ColorRect = tabs.get_node("TabMaterials/SelectedTabMark") as ColorRect
    if not selected.visible or inactive.visible:
        _fail("cyan square is missing from the selected section")
        return
    var catalog: Control = (fac.get("item_layer") as Control).find_child(
        "PrototypeGrid", true, false) as Control
    if catalog == null or int(catalog.get_meta("card_count", 0)) != 20:
        _fail("craft must have twenty positions per part")
        return
    var locked: Button = catalog.find_child("LockedCraftSlot_20", true, false) as Button
    if locked == null or not locked.disabled or (
            (locked.find_child("ItemTitle", true, false) as Label).text.find("LOCKED SLOT") < 0):
        _fail("locked manufacturing position has no English annotation")
        return
    var head: Button = catalog.find_child("PrototypeIcon_H01", true, false) as Button
    if head == null or head.custom_minimum_size.y != 160.0 or (
            (head.find_child("ItemInfo", true, false) as Label
            ).get_theme_font_size("font_size") != 17):
        _fail("manufacturing card or stat font differs from the contract")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var hanger: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if hanger == null or int(hanger.get("virtual_slots")) != 999 or (
            (hanger.get("pool") as Array).size() > 32):
        _fail("hanger lacks 999 positions or has unbounded native buttons")
        return
    if hanger.get_v_scroll_bar().max_value < 90000.0:
        _fail("full-capacity virtual hanger cannot be scrolled")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    var note: Label = fac.get("modal_body") as Label
    if not note.visible or note.text.find("精製") < 0:
        _fail("refinery has no material-refinement description")
        return
    var catalog_items: Control = (fac.get("item_layer") as Control).find_child(
        "MaterialFamilyGrid", true, false) as Control
    var low: Button = catalog_items.find_child("MaterialIcon_scrap_low", true, false) as Button
    var high: Button = catalog_items.find_child("MaterialIcon_scrap_high", true, false) as Button
    if low == null or high == null:
        _fail("refinery material selections disappeared")
        return
    var low_mark: ColorRect = low.get_node("TierRail") as ColorRect
    var high_mark: ColorRect = high.get_node("TierRail") as ColorRect
    if low_mark.color != high_mark.color:
        _fail("refinery material rails differ in luminance")
        return
    fac.call("_show_inventory", "materials")
    await process_frame
    var shelf: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    var cells: Array = shelf.get("pool")
    if cells.size() < 2:
        _fail("warehouse material pool is missing")
        return
    var rail0: ColorRect = (cells[0] as Button).get_node("TierMarker") as ColorRect
    var rail1: ColorRect = (cells[1] as Button).get_node("TierMarker") as ColorRect
    if rail0.color != rail1.color:
        _fail("warehouse material rails differ in luminance")
        return
    print("SERA_V540_LABO_VISUAL_SLOTS_RUNTIME_PASS")
    quit(0)

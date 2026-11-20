extends SceneTree
## Native Android GUI smoke for the compact segmented LABO screens.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V539_TERMINAL_LOWER_FAIL: " + why)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "STORAGE")
    await process_frame
    await process_frame
    if str(fac.get("warehouse_section")) != "equipment" or (
            (fac.get("modal_body") as Label).visible):
        _fail("STORAGE must land on equipment without gray description")
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var materials_tab: Button = actions.find_child(
        "WarehouseMaterialsTab", true, false) as Button
    var equipment_tab: Button = actions.find_child(
        "WarehouseEquipmentTab", true, false) as Button
    var hanger: HBoxContainer = actions.find_child(
        "WarehouseHangerTabs", true, false) as HBoxContainer
    if materials_tab == null or equipment_tab == null or hanger == null or (
            not equipment_tab.button_pressed) or materials_tab.button_pressed:
        _fail("the equipment archive is not the initial selected view")
        return
    if equipment_tab.get_theme_stylebox("pressed") is not StyleBoxFlat:
        _fail("warehouse segment has no technical selected underline")
        return
    if hanger.get_child_count() != 7:
        _fail("equipment hanger lost its fixed seven slots")
        return
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if list == null or (list.get("pool") as Array).is_empty() or (
            (list.get("pool") as Array).size() > 32):
        _fail("equipment virtual list missing or not bounded")
        return
    var blank: Button = (list.get("pool") as Array)[0] as Button
    if blank.get_node_or_null("EmptySlotLabel") == null:
        _fail("empty hanger missing passive slot annotation")
        return
    materials_tab.pressed.emit()
    await process_frame
    list = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if list == null or (list.get("entries") as Array).size() != 12 or (
            int(list.get("columns")) != 2):
        _fail("material archive did not survive equipment-first navigation")
        return
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    if (fac.get("modal_body") as Label).visible:
        _fail("gray explanation reappeared on equipment screen")
        return
    actions = fac.get("modal_actions") as VBoxContainer
    var slots: HBoxContainer = actions.find_child(
        "CraftSlotTabs", true, false) as HBoxContainer
    if slots == null or slots.get_child_count() != 7:
        _fail("the segmented manufacturing slots disappeared")
        return
    var head: Button = slots.get_node("CraftSlot_head") as Button
    if head.get_theme_stylebox("pressed") is not StyleBoxFlat:
        _fail("manufacturing slot is still an old filled button")
        return
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if card == null or card.find_child("UnitSerial", true, false) == null or (
            (card.find_child("ItemArt", true, false) as TextureRect).texture == null):
        _fail("manufacturing card lacks its technical identity or art")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    var refinery_note: Label = fac.get("modal_body") as Label
    if not refinery_note.visible or refinery_note.text.find("精製") < 0:
        _fail("refinery description does not explain material refining")
        return
    card = (fac.get("item_layer") as Control).find_child(
        "MaterialIcon_scrap_low", true, false) as Button
    if card == null or card.find_child("TierRail", true, false) == null or (
            card.find_child("ItemArt", true, false) == null):
        _fail("refinery catalog lost native material cards")
        return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    var bar: Button = (fac.get("modal_actions") as Control).find_child(
        "ConvertRank_0", true, false) as Button
    if bar == null or bar.get_theme_stylebox("normal") is not StyleBoxTexture or (
            bar.find_child("ConvertOutputIcon_0", true, false) == null):
        _fail("conversion action no longer has its native technical card")
        return
    print("SERA_V539_TERMINAL_LOWER_RUNTIME_PASS")
    quit(0)

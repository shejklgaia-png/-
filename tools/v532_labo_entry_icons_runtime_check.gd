extends SceneTree
## Real Godot test for direct craft entry, hanger tabs, icon sizing & no legacy reward.
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Materials = preload("res://scripts/sera_base_materials.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V532_LABO_ENTRY_ICONS_FAIL: " + message)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "LABO")
    await process_frame
    await process_frame
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    if str(fac.get("page")) != "prototypes" or (
            not (tabs.get_node("TabCraft") as Button).button_pressed):
        _fail("LABO must land on the already-selected equipment crafting tab")
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var craft_tabs: HBoxContainer = actions.find_child(
        "CraftSlotTabs", true, false) as HBoxContainer
    if craft_tabs == null or craft_tabs.get_child_count() != 7 or (
            actions.find_child("CraftSlotScroll", true, false) != null) or (
            craft_tabs.size.x > actions.size.x + 1.0):
        _fail("all seven equipment craft tabs must fit one row, no scroll")
        return
    for slot in ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]:
        var tab: Button = craft_tabs.get_node_or_null("CraftSlot_" + slot) as Button
        if tab == null or not tab.is_visible_in_tree() or (
                tab.size_flags_horizontal != Control.SIZE_EXPAND_FILL):
            _fail("missing/responsive craft tab: " + slot)
            return
        if tab.get_global_rect().end.x > craft_tabs.get_global_rect().end.x + 1.0:
            _fail("craft tab exceeds row boundary: " + slot)
            return
    var unwanted: Array[String] = [
        "OpenPrototypeCatalog", "ClaimTrialMaterials", "ClaimTrialMaterialsCatalog"]
    for name in unwanted:
        if actions.find_child(name, true, false) != null:
            _fail("obsolete intermediate button is still shown: " + name)
            return
    if (fac.get("item_layer") as Control).find_child(
            "PrototypeIcon_H01", true, false) == null:
        _fail("first craft bar missing on LABO entry")
        return
    # Even an existing save with unclaimed trial reward must never expose it.
    var save: Node = root.get_node("SeraSave")
    var old_slot: int = int(save.get("active_slot"))
    var old_data: Dictionary = save.get("active_data").duplicate(true)
    save.set("active_slot", 1)
    save.set("active_data", {"trial_materials_claimed": false,
        "crafted_items": [], "materials": {}})
    fac.call("open_facility", "LABO")
    actions = fac.get("modal_actions") as VBoxContainer
    if actions.find_child("ClaimTrialMaterialsCatalog", true, false) != null:
        _fail("legacy trial reward appears for an old unclaimed save")
        return
    save.set("active_slot", old_slot)
    save.set("active_data", old_data)
    fac.call("_switch_section", "warehouse")
    fac.call("_show_inventory", "equipment")
    await process_frame
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    var hanger: HBoxContainer = actions.find_child(
        "WarehouseHangerTabs", true, false) as HBoxContainer
    if hanger == null or hanger.get_child_count() != 7 or (
            actions.find_child("WarehouseHangerScroll", true, false) != null):
        _fail("seven hanger tabs must fit one row with no horizontal scrolling")
        return
    if hanger.size.x > actions.size.x + 1.0:
        _fail("hanger tabs overflow available width")
        return
    var group: ButtonGroup = null
    for slot in ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]:
        var button: Button = hanger.get_node_or_null("HangerSlot_" + str(slot)) as Button
        if button == null or not button.toggle_mode or button.button_group == null:
            _fail("hanger category missing / not selectable: " + str(slot))
            return
        if group == null:
            group = button.button_group
        elif group != button.button_group:
            _fail("hanger tabs do not select exclusively")
            return
    fac.call("_select_warehouse_slot", 1)
    await process_frame
    if str(fac.get("warehouse_slot")) != "torso":
        _fail("horizontal hanger selection did not change the equipment category")
        return
    actions = fac.get("modal_actions") as VBoxContainer
    var torso: Button = actions.find_child("HangerSlot_torso", true, false) as Button
    if torso == null or not torso.button_pressed:
        _fail("recreated hanger must retain selected category")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    var grid: VBoxContainer = (fac.get("item_layer") as Control).find_child(
        "MaterialFamilyGrid", true, false) as VBoxContainer
    if grid == null:
        _fail("material grid missing")
        return
    for material_id in Materials.all_ids():
        var card: Button = grid.find_child(
            "MaterialIcon_" + str(material_id), true, false) as Button
        if card == null or not card.is_visible_in_tree() or (
                (card.find_child("ItemArt", true, false) as TextureRect).texture == null):
            _fail("material icon missing: " + str(material_id))
            return
        var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
        if card.custom_minimum_size.y > 116.0 or (
                card.custom_minimum_size.y < 102.0) or art.size.x > 57.0 or (
                art.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED):
            _fail("material icon is not bounded/centered in shorter card")
            return
    print("SERA_V532_LABO_ENTRY_ICONS_RUNTIME_PASS")
    quit(0)

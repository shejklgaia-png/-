extends SceneTree
## Buttons must be large enough for Android touch, while 7 slots fit one row.
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V534_LABO_BIG_BUTTONS_FAIL: " + reason)
    quit(1)
func _size_ok(control: Control, min_height: float, label: String) -> bool:
    if control == null or not control.is_visible_in_tree() or (
            control.size.y + 0.5 < min_height):
        _fail(label + " hidden or smaller than " + str(min_height))
        return false
    return true
func _slot_row(actions: VBoxContainer, row_name: String,
        prefix: String) -> bool:
    var row: HBoxContainer = actions.find_child(row_name, true, false) as HBoxContainer
    if row == null or row.get_child_count() != 7 or (
            row.size.x > actions.size.x + 1.0):
        _fail(row_name + " must fit 7 tabs without horizontal scrolling")
        return false
    for slot in ["head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"]:
        var tab: Button = row.get_node_or_null(prefix + slot) as Button
        if not _size_ok(tab, 55.0, prefix + slot):
            return false
        if tab.get_global_rect().end.x > row.get_global_rect().end.x + 1.5:
            _fail("slot tab exceeds the row: " + slot)
            return false
    return true
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
    for name in ["TabCraft", "TabMaterials", "TabWarehouse"]:
        if not _size_ok(tabs.get_node(name) as Button, 60.0, name):
            return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    if not _slot_row(actions, "CraftSlotTabs", "CraftSlot_"):
        return
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if not _size_ok(card, 100.0, "craft card"):
        return
    var close: Button = (fac.get("modal") as Control).find_child(
        "CloseFacility", true, false) as Button
    if not _size_ok(close, 64.0, "Back"):
        return
    fac.call("_select_prototype", "H01")
    var dialog: Control = fac.get("confirmation_overlay") as Control
    for name in ["LaboConfirmAccept", "LaboConfirmCancel"]:
        if not _size_ok(dialog.find_child(name, true, false) as Button, 66.0, name):
            return
    fac.call("_dismiss_confirmation")
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    card = (fac.get("item_layer") as Control).find_child(
        "MaterialIcon_scrap_low", true, false) as Button
    if not _size_ok(card, 103.0, "material choice"):
        return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    if not _size_ok(actions.find_child("ConvertRank_0", true, false) as Button,
            78.0, "conversion action"):
        return
    if not _size_ok(actions.find_child("ConversionCount_0", true, false) as SpinBox,
            68.0, "conversion amount"):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    if not _size_ok(actions.find_child("WarehouseMaterialsTab", true, false)
            as Button, 57.0, "warehouse materials tab"):
        return
    fac.call("_show_inventory", "materials")
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if list == null or list.get("pool").is_empty():
        _fail("warehouse material virtual list missing")
        return
    if not _size_ok(list.get("pool")[0] as Button, 119.0, "warehouse material card"):
        return
    fac.call("_show_inventory", "equipment")
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    if not _slot_row(actions, "WarehouseHangerTabs", "HangerSlot_"):
        return
    print("SERA_V534_LABO_BIG_BUTTONS_RUNTIME_PASS")
    quit(0)

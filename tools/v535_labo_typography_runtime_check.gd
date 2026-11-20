extends SceneTree
const Skin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V535_LABO_TYPOGRAPHY_FAIL: " + message)
    quit(1)
func _need_font(control: Control, size: int, label: String) -> bool:
    if control == null or control.get_theme_font_size("font_size") < size:
        _fail(label + " text is smaller than " + str(size))
        return false
    return true
func _run() -> void:
    var theme: Theme = Skin.common_theme()
    if theme.default_font == null or theme.default_font_size < 18 or (
            not Skin.ui_font() is Font) or (
            not Skin.data_font() is Font):
        _fail("lightweight Japanese UI / digital-data font is not configured")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "LABO")
    await process_frame
    await process_frame
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var title: Label = fac.get("modal_title") as Label
    var body: VBoxContainer = tabs.get_parent() as VBoxContainer
    var header: HBoxContainer = title.get_parent() as HBoxContainer
    if tabs.get_index() >= header.get_index() or (
            header.find_child("SectionHeaderAccent", true, false) == null):
        _fail("reference layout must show tabs before accented section heading")
        return
    if not _need_font(title, 26, "section title"):
        return
    var preview: PanelContainer = (fac.get("item_layer") as Control).find_child(
        "PrototypeBasePreview", true, false) as PanelContainer
    if preview == null or preview.custom_minimum_size.y < 130.0 or (
            preview.find_child("PrototypeBaseArt", true, false) == null):
        _fail("reference-style equipment preview missing")
        return
    for name in ["TabCraft", "TabMaterials", "TabWarehouse"]:
        if not _need_font(tabs.get_node(name) as Button, 19, name):
            return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var part_tabs: HBoxContainer = actions.find_child(
        "CraftSlotTabs", true, false) as HBoxContainer
    if part_tabs == null or part_tabs.get_child_count() != 7 or (
            part_tabs.size.x > actions.size.x + 1.0):
        _fail("part tabs must remain seven-wide without scrolling")
        return
    for slot in ["head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"]:
        var tab: Button = part_tabs.get_node("CraftSlot_" + slot) as Button
        if not _need_font(tab, 18, slot):
            return
        if tab.get_global_rect().end.x > part_tabs.get_global_rect().end.x + 1.5:
            _fail("slot label sizing caused overflow: " + slot)
            return
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if card == null or not _need_font(card.find_child(
            "ItemTitle", true, false) as Label, 21, "craft card title"):
        return
    if not _need_font(card.find_child(
            "ItemInfo", true, false) as Label, 16, "craft card stats"):
        return
    var back: Button = (fac.get("modal") as Control).find_child(
        "CloseFacility", true, false) as Button
    if not _need_font(back, 22, "back"):
        return
    fac.call("_select_prototype", "H01")
    var overlay: Control = fac.get("confirmation_overlay") as Control
    if not _need_font(overlay.find_child(
            "LaboConfirmAccept", true, false) as Button, 21, "confirm accept"):
        return
    fac.call("_dismiss_confirmation")
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    var material: Button = (fac.get("item_layer") as Control).find_child(
        "MaterialIcon_scrap_low", true, false) as Button
    if not _need_font(material.find_child(
            "ItemTitle", true, false) as Label, 17, "material card title"):
        return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    var label: Label = (fac.get("modal_actions") as Control).find_child(
        "ConvertRank_0", true, false).find_child(
            "ItemTitle", true, false) as Label
    if not _need_font(label, 17, "conversion label"):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if list == null or list.get("pool").is_empty():
        _fail("warehouse virtual pool missing")
        return
    var first: Button = (list.get("pool") as Array)[0] as Button
    if not _need_font(first.get_node("ItemTitle") as Label, 15, "warehouse material"):
        return
    print("SERA_V535_LABO_TYPOGRAPHY_RUNTIME_PASS")
    quit(0)

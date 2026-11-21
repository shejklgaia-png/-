extends SceneTree
## v544: distinguish actual font sizes, tracking and selection hierarchy.
const LaboTypeSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V544_LABO_TYPE_HIERARCHY_FAIL: " + reason)
    quit(1)
func _run() -> void:
    var display: FontVariation = LaboTypeSkin.tracked_display_font()
    var mono: FontVariation = LaboTypeSkin.tracked_data_font()
    if display != LaboTypeSkin.tracked_display_font() or (
            mono != LaboTypeSkin.tracked_data_font()) or (
            display.spacing_glyph != 1 or mono.spacing_glyph != 1):
        _fail("tracking fonts are not cached or spaced")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var heading: Label = fac.get("modal_title") as Label
    var caption: Label = fac.get("module_caption") as Label
    var tab: Button = (fac.get("section_tabs") as Control).get_node("TabCraft") as Button
    if heading.get_theme_font_size("font_size") < 32 or (
            caption.get_theme_font_size("font_size") < 14) or (
            tab.get_theme_font_size("font_size") < 20) or (
            tab.get_theme_font("font") != display) or (
            caption.get_theme_font("font") != mono):
        _fail("primary heading, navigation or tracking too weak")
        return
    var actions: Control = fac.get("modal_actions") as Control
    var selected: Button = actions.find_child("CraftSlot_head", true, false) as Button
    var idle: Button = actions.find_child("CraftSlot_torso", true, false) as Button
    if selected == null or idle == null or (
            selected.get_theme_font_size("font_size") <= idle.get_theme_font_size("font_size")):
        _fail("selected part tab is not typographically prominent")
        return
    var layer: Control = fac.get("item_layer") as Control
    var card: Button = layer.find_child("PrototypeIcon_H01", true, false) as Button
    var locked: Button = layer.find_child("LockedCraftSlot_20", true, false) as Button
    if card == null or locked == null:
        _fail("craft cards or twenty locked positions missing")
        return
    var name: Label = card.find_child("ItemTitle", true, false) as Label
    var status: Label = card.find_child("ItemInfo", true, false) as Label
    if name.get_theme_font_size("font_size") < 24 or (
            status.get_theme_font_size("font_size") != 20) or (
            locked.find_child("ItemTitle", true, false).get_theme_font("font") != display):
        _fail("craft name, stats and LOCKED SLOT not differentiated")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    layer = fac.get("item_layer") as Control
    var material: Button = layer.find_child("MaterialIcon_scrap_low", true, false) as Button
    var item_title: Label = material.find_child("ItemTitle", true, false) as Label
    var item_count: Label = material.find_child("ItemInfo", true, false) as Label
    if item_title.get_theme_font_size("font_size") <= (
            item_count.get_theme_font_size("font_size")) or (
            (material.get_node("MaterialGradeTag") as Label).get_theme_font("font") != mono):
        _fail("refinery material type hierarchy is missing")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var store: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if store == null or int(store.get("virtual_slots")) != 999 or (
            (store.get("pool") as Array).size() > 32):
        _fail("storage virtualization was changed")
        return
    var cards: Array = store.get("pool")
    if cards.is_empty() or (
            (cards[0] as Button).get_node("EmptySlotLabel").get_theme_font("font") != display):
        _fail("empty hanger typography was not applied")
        return
    fac.call("_show_inventory", "materials")
    await process_frame
    await process_frame
    store = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    cards = store.get("pool")
    if cards.is_empty() or (
            (cards[0] as Button).get_node("ItemMeta").get_theme_font("font") != mono):
        _fail("material metadata tracking is missing")
        return
    print("SERA_V544_LABO_TYPE_HIERARCHY_RUNTIME_PASS")
    quit(0)

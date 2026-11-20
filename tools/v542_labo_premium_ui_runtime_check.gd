extends SceneTree
## SERA v542: all three pages preserve native controls and technical accents.
const LaboVisualSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V542_LABO_PREMIUM_UI_FAIL: " + why)
    quit(1)
func _run() -> void:
    if LaboVisualSkin.panel_style() != LaboVisualSkin.panel_style() or (
            LaboVisualSkin.card_style("normal") != LaboVisualSkin.card_style("normal")):
        _fail("shared gradients are not cached")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var caption: Label = fac.get("module_caption") as Label
    if caption == null or caption.text.find("SHELL FABRICATION") < 0:
        _fail("craft lacks the persistent instrument header")
        return
    var strip: HBoxContainer = (fac.get("modal") as Control).find_child(
        "FacilityModuleStrip", true, false) as HBoxContainer
    if strip == null or strip.get_node_or_null("ModuleSignalRail") == null:
        _fail("industrial telemetry strip is missing")
        return
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var selected: Button = tabs.get_node("TabCraft") as Button
    if selected.get_theme_stylebox("pressed") == (
            selected.get_theme_stylebox("normal")):
        _fail("active hanging-tab silhouette lost its emphasis")
        return
    var layer: Control = fac.get("item_layer") as Control
    var card: Button = layer.find_child("PrototypeIcon_H01", true, false) as Button
    if card == null or card.get_node_or_null("CardSignalRail") == null or (
            card.get_node_or_null("CardSystemState") == null):
        _fail("craft active item lost its equipment-ready indicators")
        return
    var locked: Button = layer.find_child("LockedCraftSlot_20", true, false) as Button
    if locked == null or not locked.disabled or (
            (locked.get_node("CardSystemState") as Label).text.find("LOCKED") < 0):
        _fail("locked item is indistinguishable from an available blueprint")
        return
    var back: Button = (fac.get("modal") as Control).find_child(
        "CloseFacility", true, false) as Button
    if back == null or back.get_node_or_null("ExitKey") == null:
        _fail("back control is missing the system key legend")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    if caption.text.find("MATERIAL REFINERY") < 0:
        _fail("material module title did not switch")
        return
    layer = fac.get("item_layer") as Control
    var material: Button = layer.find_child("MaterialIcon_scrap_low", true, false) as Button
    if material == null or material.get_node_or_null("MaterialGradeTag") == null:
        _fail("refinery cards lack grade identification")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var warehouse: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if warehouse == null or int(warehouse.get("virtual_slots")) != 999:
        _fail("storage lost the 999-capacity virtual hanger")
        return
    var pool: Array = warehouse.get("pool")
    if pool.size() < 1 or pool.size() > 32 or (
            (pool[0] as Button).get_node_or_null("SlotAddress") == null) or (
            (pool[0] as Button).get_node_or_null("EmptyBeacon") == null):
        _fail("hanger index overlays cannot be recycled")
        return
    fac.call("_show_inventory", "materials")
    await process_frame
    if caption.text.find("MATERIAL MANIFEST") < 0:
        _fail("material warehouse view lost its own instrument title")
        return
    print("SERA_V542_LABO_PREMIUM_UI_RUNTIME_PASS")
    quit(0)

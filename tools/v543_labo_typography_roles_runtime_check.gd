extends SceneTree
## v543: verify real Godot font overrides across every LAB module.
const LaboTypefaceRoles = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V543_LABO_TYPOGRAPHY_ROLES_FAIL: " + why)
    quit(1)
func _has_font(control: Control, expected: Font, description: String) -> bool:
    if control == null or control.get_theme_font("font") != expected:
        _fail("font role mismatch: " + description)
        return false
    return true
func _run() -> void:
    var reading: SystemFont = LaboTypefaceRoles.ui_font()
    var title_font: SystemFont = LaboTypefaceRoles.title_font()
    var control_font: SystemFont = LaboTypefaceRoles.control_font()
    var stats_font: SystemFont = LaboTypefaceRoles.stats_font()
    var condensed: SystemFont = LaboTypefaceRoles.display_font()
    var mono: SystemFont = LaboTypefaceRoles.data_font()
    if reading == title_font or title_font == control_font or (
            control_font == stats_font) or stats_font == mono or (
            condensed == mono) or condensed == title_font:
        _fail("cached font roles must remain distinct")
        return
    if LaboTypefaceRoles.display_font() != condensed or (
            LaboTypefaceRoles.stats_font() != stats_font) or (
            LaboTypefaceRoles.control_font() != control_font):
        _fail("font construction runs again instead of caching")
        return
    if not condensed.font_names.has("Roboto Condensed") or (
            not mono.font_names.has("Roboto Mono")) or (
            not reading.font_names.has("Noto Sans JP")) or (
            condensed.font_weight < title_font.font_weight) or (
            control_font.font_weight <= stats_font.font_weight):
        _fail("typeface family/weight specification was changed")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    if not _has_font(tabs.get_node("TabCraft") as Button, condensed,
            "EQUIPMENT upper tab"):
        return
    if not _has_font(tabs.get_node("TabMaterials/TabSerial") as Label, mono,
            "section number"):
        return
    if not _has_font(fac.get("modal_title") as Label, title_font,
            "Japanese page heading"):
        return
    if not _has_font(fac.get("module_caption") as Label, mono,
            "instrument caption"):
        return
    if not _has_font((fac.get("modal") as Control).find_child(
            "CloseFacility", true, false) as Button, control_font, "back button"):
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    if not _has_font(actions.find_child("CraftSlot_head", true, false) as Button,
            control_font, "Japanese equipment category"):
        return
    var layer: Control = fac.get("item_layer") as Control
    var standard: Button = layer.find_child("PrototypeIcon_H01", true, false) as Button
    var locked: Button = layer.find_child("LockedCraftSlot_20", true, false) as Button
    if standard == null or locked == null:
        _fail("craft has no equipment card or locked position")
        return
    if not _has_font(standard.find_child("ItemTitle", true, false) as Label,
            title_font, "equipment name"):
        return
    if not _has_font(standard.find_child("ItemInfo", true, false) as Label,
            stats_font, "mixed Japanese status line"):
        return
    if not _has_font(locked.find_child("ItemTitle", true, false) as Label,
            condensed, "LOCKED SLOT heading"):
        return
    if not _has_font(locked.find_child("ItemInfo", true, false) as Label,
            mono, "locked position code"):
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    layer = fac.get("item_layer") as Control
    var material: Button = layer.find_child("MaterialIcon_scrap_low", true, false) as Button
    if not _has_font(material.find_child("ItemTitle", true, false) as Label,
            control_font, "material name"):
        return
    if not _has_font(material.find_child("ItemInfo", true, false) as Label,
            stats_font, "material quantity"):
        return
    if not _has_font(material.get_node("MaterialGradeTag") as Label, mono,
            "material grade"):
        return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    var conversion: Button = actions.find_child("ConvertRank_0", true, false) as Button
    if conversion == null or not _has_font(conversion.find_child(
            "ItemInfo", true, false) as Label, stats_font, "refinery output"):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var storage: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    var cards: Array = storage.get("pool")
    if cards.is_empty() or not _has_font(
            (cards[0] as Button).get_node("EmptySlotLabel") as Label,
            condensed, "empty hanger"):
        return
    fac.call("_show_inventory", "materials")
    await process_frame
    storage = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    cards = storage.get("pool")
    if cards.is_empty() or not _has_font(
            (cards[0] as Button).get_node("ItemTitle") as Label,
            control_font, "stored material title") or not _has_font(
            (cards[0] as Button).get_node("ItemEffects") as Label,
            stats_font, "stored quantity"):
        return
    print("SERA_V543_LABO_TYPOGRAPHY_ROLES_RUNTIME_PASS")
    quit(0)

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
    var reading: FontVariation = LaboTypefaceRoles.ui_font()
    var title_font: FontVariation = LaboTypefaceRoles.title_font()
    var control_font: FontVariation = LaboTypefaceRoles.control_font()
    var stats_font: FontVariation = LaboTypefaceRoles.stats_font()
    var condensed: FontFile = LaboTypefaceRoles.display_font()
    var mono: FontFile = LaboTypefaceRoles.data_font()
    var condensed_spaced: FontVariation = LaboTypefaceRoles.tracked_display_font()
    var mono_spaced: FontVariation = LaboTypefaceRoles.tracked_data_font()
    if reading == title_font or title_font == control_font or (
            control_font == stats_font) or stats_font == mono or (
            condensed == mono) or condensed == title_font:
        _fail("cached font roles must remain distinct")
        return
    if (LaboTypefaceRoles.display_font() != condensed or
            condensed_spaced.base_font != condensed or
            mono_spaced.base_font != mono or
            condensed_spaced.spacing_glyph != 1 or
            mono_spaced.spacing_glyph != 1 or
            LaboTypefaceRoles.stats_font() != stats_font or
            LaboTypefaceRoles.control_font() != control_font):
        _fail("font construction runs again instead of caching")
        return
    var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
    if (not reading.base_font is FontFile or
            title_font.base_font == reading.base_font or
            control_font.base_font == reading.base_font or
            stats_font.base_font == reading.base_font or
            int(title_font.variation_opentype.get(tag, 0)) != 800 or
            int(LaboTypefaceRoles.equipment_font().variation_opentype.get(tag, 0)) != 700 or
            int(stats_font.variation_opentype.get(tag, 0)) != 550 or
            not reading.has_char(0x65E5) or
            not reading.has_char(0x6F22) or
            not condensed.has_char(0x41) or
            not mono.has_char(0x41)):
        _fail("bundled font faces or OpenType role weights are invalid")
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
    if not _has_font(tabs.get_node("TabCraft") as Button, condensed_spaced,
            "EQUIPMENT upper tab"):
        return
    if not _has_font(tabs.get_node("TabMaterials/TabSerial") as Label, mono_spaced,
            "section number"):
        return
    if not _has_font(fac.get("modal_title") as Label, title_font,
            "Japanese page heading"):
        return
    if not _has_font(fac.get("module_caption") as Label, mono_spaced,
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
            LaboTypefaceRoles.equipment_font(), "equipment name"):
        return
    if not _has_font(standard.find_child("ItemInfo", true, false) as Label,
            stats_font, "mixed Japanese status line"):
        return
    if not _has_font(locked.find_child("ItemTitle", true, false) as Label,
            condensed_spaced, "LOCKED SLOT heading"):
        return
    if not _has_font(locked.find_child("ItemInfo", true, false) as Label,
            mono_spaced, "locked position code"):
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    layer = fac.get("item_layer") as Control
    var material: Button = layer.find_child("MaterialIcon_scrap_low", true, false) as Button
    if not _has_font(material.find_child("ItemTitle", true, false) as Label,
            reading, "material name"):
        return
    if not _has_font(material.find_child("ItemInfo", true, false) as Label,
            stats_font, "material quantity"):
        return
    if not _has_font(material.get_node("MaterialGradeTag") as Label, mono_spaced,
            "material grade"):
        return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    actions = fac.get("modal_actions") as VBoxContainer
    var conversion: Button = actions.find_child("ConvertRank_0", true, false) as Button
    if conversion == null or not _has_font(conversion.find_child(
            "ItemInfo", true, false) as Label, reading, "refinery output"):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var storage: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    var cards: Array = storage.get("pool")
    if cards.is_empty() or not _has_font(
            (cards[0] as Button).get_node("EmptySlotLabel") as Label,
            condensed_spaced, "empty hanger"):
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

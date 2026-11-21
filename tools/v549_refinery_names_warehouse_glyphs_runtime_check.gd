extends SceneTree
## v551: two-line grade/family names, equal padding, JP warehouse formulas.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Typeface = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V549_REFINERY_GLYPHS_FAIL: " + why)
    quit(1)
func _run() -> void:
    # Simulate the 720px Android layout shown in the bug report.
    root.size = Vector2i(720, 1280)
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    await process_frame
    var catalog: Control = (fac.get("item_layer") as Control).find_child(
        "MaterialFamilyGrid", true, false) as Control
    if catalog == null or int(catalog.get_meta("card_count", 0)) != 12:
        _fail("refinery must retain 12 three-column material cards")
        return
    var shared_size: int = -1
    for id in Materials.all_ids():
        var card: Button = catalog.find_child(
            "MaterialIcon_" + str(id), true, false) as Button
        if card == null:
            _fail("missing card: " + str(id))
            return
        var title: Label = card.find_child("ItemTitle", true, false) as Label
        var dock: MarginContainer = card.find_child(
            "MaterialArtOffset", true, false) as MarginContainer
        var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
        if title == null or dock == null or art == null:
            _fail("icon and text hierarchy missing: " + str(id))
            return
        if title.autowrap_mode != TextServer.AUTOWRAP_OFF or (
                title.max_lines_visible != 2) or title.text != Materials.display_lines(id):
            _fail("Japanese material grade/family title is not two lines: " + str(id))
            return
        if title.get_theme_font("font") != Typeface.ui_font():
            _fail("refinery material name is not IBM Plex Sans JP Medium: " + str(id))
            return
        var current_size: int = title.get_theme_font_size("font_size")
        if shared_size < 0:
            shared_size = current_size
        elif current_size != shared_size:
            _fail("refinery material names use different sizes: " + str(id))
            return
        var face: Font = title.get_theme_font("font")
        for line_text in title.text.split("\n"):
            var text_width: float = face.get_string_size(
                line_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
                title.get_theme_font_size("font_size")).x
            if text_width > title.size.x + 1.0:
                _fail("material name clipped at 720px: " + str(id) +
                    " need=" + str(text_width) + " available=" + str(title.size.x))
                return
        var row: HBoxContainer = dock.get_parent() as HBoxContainer
        var padding: MarginContainer = row.get_parent() as MarginContainer
        if padding.get_theme_constant("margin_left") != 12 or (
                row.get_theme_constant("separation") != 12):
            _fail("left margin and icon-to-text gap are not equal")
            return
        if dock.get_theme_constant("margin_top") != 7 or (
                art.custom_minimum_size.x > 46.0) or (
                not card.get_global_rect().grow(1).encloses(art.get_global_rect())):
            _fail("material thumbnail position or proportions changed: " + str(id))
            return
        if art.texture == null or art.size.x <= 0.0 or (
                absf(art.size.x - art.size.y) > 0.01):
            _fail("material icon is missing or not square: " + str(id))
            return
    fac.call("_select_conversion_family", "organic")
    await process_frame
    var actions: Control = fac.get("modal_actions") as Control
    for rank in [0, 1]:
        var bar: Button = actions.find_child(
            "ConvertRank_" + str(rank), true, false) as Button
        if bar == null:
            _fail("refinery conversion bar missing")
            return
        var source: Label = bar.find_child("ItemTitle", true, false) as Label
        var target: Label = bar.find_child("ItemInfo", true, false) as Label
        if source == null or target == null or (
                source.get_theme_font("font") != Typeface.ui_font()) or (
                target.get_theme_font("font") != Typeface.ui_font()) or (
                source.get_theme_font_size("font_size") != shared_size) or (
                target.get_theme_font_size("font_size") != shared_size):
            _fail("conversion source/target names do not use uniform medium font")
            return
    var save: Node = root.get_node_or_null("SeraSave")
    if save == null:
        _fail("SeraSave missing")
        return
    var prev_slot: int = int(save.get("active_slot"))
    var prev_data: Dictionary = (save.get("active_data") as Dictionary).duplicate(true)
    # Read-only in-memory fixture; do not touch user:// save files.
    save.set("active_slot", 1)
    save.set("active_data", {
        "crafted_items": [{
            "uid": "H01-0004", "blueprint": "H01", "slot": "head",
            "affixes": [{"id": "hp", "value": 2}, {"id": "defense", "value": 4}]
        }],
        "craft_serials": {"H01": 4}, "materials": {}
    })
    fac.call("_switch_section", "warehouse")
    fac.call("_show_warehouse_item_detail", "H01-0004")
    await process_frame
    var summary: Label = (fac.get("modal_actions") as Control).find_child(
        "WarehouseStatsBreakdown", true, false) as Label
    if summary == null or summary.text.is_empty():
        save.set("active_slot", prev_slot)
        save.set("active_data", prev_data)
        _fail("warehouse breakdown not displayed")
        return
    var font: Font = summary.get_theme_font("font")
    var readable: bool = font == Typeface.stats_font()
    for codepoint: int in [0x6700, 0x5927, 0x9632, 0x5FA1]:
        readable = readable and font.has_char(codepoint)
    var detail_controls: Control = fac.get("modal_actions") as Control
    var favorite: Button = detail_controls.find_child(
        "WarehouseFavoriteToggle", true, false) as Button
    var junk: Button = detail_controls.find_child("WarehouseJunkToggle", true, false) as Button
    readable = readable and favorite != null and junk != null
    save.set("active_slot", prev_slot)
    save.set("active_data", prev_data)
    if not readable:
        _fail("warehouse breakdown still uses Latin-only font or actions are missing")
        return
    print("SERA_V549_REFINERY_GLYPHS_RUNTIME_PASS")
    quit(0)

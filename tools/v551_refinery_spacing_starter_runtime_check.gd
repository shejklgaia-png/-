extends SceneTree
## SERA v551: check material inventory, 2-line layout, spacing and mute states.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Typeface = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V551_REFINERY_SPACING_STARTER_FAIL: " + message)
    quit(1)
func _run() -> void:
    var starter: Dictionary = Materials.starter_inventory()
    var blank: Dictionary = Materials.empty_inventory()
    if starter.size() != 12 or int(starter.get("scrap_low", -1)) != 5:
        _fail("new profiles must begin with exactly five low-tier scraps")
        return
    for id in Materials.all_ids():
        if int(blank.get(id, -1)) != 0 or (
                id != "scrap_low" and int(starter.get(id, -1)) != 0):
            _fail("old zero-inventory contract or other starter amounts changed")
            return
        var grade_family: String = Materials.display_lines(str(id))
        if grade_family.split("\n").size() != 2 or (
                grade_family.replace("\n", "") != Materials.display_name(str(id))):
            _fail("two-line grade/family label mismatches original name: " + str(id))
            return
    var save: Node = root.get_node_or_null("SeraSave")
    if save == null:
        _fail("SeraSave autoload missing")
        return
    var doc: Dictionary = save.call("_new_document", 1)
    if doc.get("materials", {}) != starter or (
            Materials.sanitize_inventory({}) != blank):
        _fail("starter inventory not isolated from old/empty saves")
        return
    # Run in memory only. Do not mutate user:// save files.
    var prev_slot: int = int(save.get("active_slot"))
    var prev_data: Dictionary = (save.get("active_data") as Dictionary).duplicate(true)
    save.set("active_slot", 1)
    save.set("active_data", doc)
    root.size = Vector2i(720, 1280)
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "materials")
    for i in range(4):
        await process_frame
    var grid: Control = (fac.get("item_layer") as Control).find_child(
        "MaterialFamilyGrid", true, false) as Control
    if grid == null or int(grid.get_meta("card_count", 0)) != 12:
        _fail("refinery 3-column grid lost the twelve material entries")
        return
    var common_size: int = -1
    for item_id in Materials.all_ids():
        var id: String = str(item_id)
        var card: Button = grid.find_child("MaterialIcon_" + id, true, false) as Button
        if card == null:
            _fail("missing material button " + id)
            return
        var title: Label = card.find_child("ItemTitle", true, false) as Label
        var count: Label = card.find_child("ItemInfo", true, false) as Label
        var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
        var dock: MarginContainer = card.find_child("MaterialArtOffset", true, false)
        if title == null or count == null or art == null or dock == null:
            _fail("required card UI missing: " + id)
            return
        var row: HBoxContainer = dock.get_parent() as HBoxContainer
        var pad: MarginContainer = row.get_parent() as MarginContainer
        if pad.get_theme_constant("margin_left") != 12 or (
                row.get_theme_constant("separation") != 12):
            _fail("left margin and icon-to-label gap must both be 12px: " + id)
            return
        if title.text != Materials.display_lines(id) or (
                title.max_lines_visible != 2) or (
                title.autowrap_mode != TextServer.AUTOWRAP_OFF):
            _fail("grade/type label not split into exactly two lines: " + id)
            return
        if title.get_theme_font("font") != Typeface.ui_font():
            _fail("material titles no longer use medium Japanese font")
            return
        var size: int = title.get_theme_font_size("font_size")
        if common_size < 0:
            common_size = size
        if common_size != size:
            _fail("material names do not share one size")
            return
        var font: Font = title.get_theme_font("font")
        for one_line in title.text.split("\n"):
            if font.get_string_size(one_line, HORIZONTAL_ALIGNMENT_LEFT,
                    -1.0, size).x > title.size.x + 1.0:
                _fail("grade/type line exceeds card width: " + id)
                return
        var owned: bool = id == "scrap_low"
        var is_muted: bool = card.modulate.r < 0.8
        if card.disabled or bool(card.get_meta("out_of_stock", false)) == owned or (
                is_muted == owned):
            _fail("ownership shading or tap access incorrect: " + id)
            return
        if count.text != ("所持 5" if owned else "所持 0"):
            _fail("wrong initial inventory count shown: " + id)
            return
    fac.call("_select_conversion_family", "scrap")
    await process_frame
    await process_frame
    var controls: Control = fac.get("modal_actions") as Control
    var low: Button = controls.find_child("ConvertRank_0", true, false) as Button
    var mid: Button = controls.find_child("ConvertRank_1", true, false) as Button
    if low == null or mid == null or low.disabled or not mid.disabled or (
            low.modulate.r < 0.8) or (mid.modulate.r >= 0.8) or (
            not bool(mid.get_meta("out_of_stock", false))):
        _fail("refinement must enable five owned scraps, grey unavailable source")
        return
    # Ensure no save-data side effects from a UI-only regression test.
    save.set("active_slot", prev_slot)
    save.set("active_data", prev_data)
    print("SERA_V551_REFINERY_SPACING_STARTER_RUNTIME_PASS")
    quit(0)

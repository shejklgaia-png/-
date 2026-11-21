extends SceneTree
## v552: all 12 material names propagate through refinery, recipe and storage.
## This test never writes user:// and preserves the original in-memory save.
const Materials = preload("res://scripts/sera_base_materials.gd")
const EXPECTED_NAMES: Dictionary = {
    "scrap_low": "汎用スクラップ",
    "scrap_mid": "応用スクラップ",
    "scrap_high": "高度スクラップ",
    "alloy_low": "基礎金属複合材",
    "alloy_mid": "精密金属複合材",
    "alloy_high": "高次金属複合材",
    "electronics_low": "汎用電子部品",
    "electronics_mid": "精密電子部品",
    "electronics_high": "高度電子部品",
    "organic_low": "微弱有機素材",
    "organic_mid": "活性有機素材",
    "organic_high": "旺盛有機素材"
}
const EXPECTED_FAMILIES: Dictionary = {
    "scrap": "スクラップ",
    "alloy": "金属複合材",
    "electronics": "電子部品",
    "organic": "有機素材"
}
const EXPECTED_GRADES: Dictionary = {
    "scrap": ["汎用", "応用", "高度"],
    "alloy": ["基礎", "精密", "高次"],
    "electronics": ["汎用", "精密", "高度"],
    "organic": ["微弱", "活性", "旺盛"]
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_V552_MATERIAL_NAMES_FAIL: " + why)
    quit(1)

func _run() -> void:
    if Materials.all_ids().size() != 12 or Materials.MATERIAL_NAMES.size() != 12:
        _fail("the 12 stable material IDs changed")
        return
    for family in Materials.FAMILY_IDS:
        var family_id: String = str(family)
        if Materials.FAMILY_NAMES.get(family_id, "") != EXPECTED_FAMILIES[family_id]:
            _fail("family name mismatch: " + family_id)
            return
        for index in range(3):
            var rank: String = str(Materials.TIERS[index])
            var id: String = family_id + "_" + rank
            var grade: String = str(EXPECTED_GRADES[family_id][index])
            if Materials.display_name(id) != EXPECTED_NAMES[id] or (
                    Materials.GRADE_NAMES[family_id][rank] != grade) or (
                    Materials.display_lines(id) != grade + "\n" + EXPECTED_FAMILIES[family_id]):
                _fail("material name or line break mismatch: " + id)
                return
    var starter: Dictionary = Materials.starter_inventory()
    if int(starter.get("scrap_low", -1)) != 5 or (
            int(starter.get("alloy_low", -1)) != 0):
        _fail("renaming changed the five starter scraps")
        return
    var converted: Dictionary = Materials.convert(starter, "scrap", 0, 1, 1)
    if not bool(converted.get("ok", false)) or (
            int(converted["inventory"]["scrap_low"]) != 3) or (
            int(converted["inventory"]["scrap_mid"]) != 1):
        _fail("existing resource IDs or conversion costs were changed")
        return
    var save: Node = root.get_node_or_null("SeraSave")
    if save == null:
        _fail("save autoload missing")
        return
    var original_slot: int = int(save.get("active_slot"))
    var original_data: Dictionary = (save.get("active_data") as Dictionary).duplicate(true)
    var profile: Dictionary = save.call("_new_document", 1)
    save.set("active_slot", 1)
    save.set("active_data", profile)
    if save.call("get_material_inventory") != starter:
        _fail("fresh save material count changed after renaming")
        return
    root.size = Vector2i(720, 1280)
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "materials")
    for frame in range(4):
        await process_frame
    var grid: Control = (fac.get("item_layer") as Control).find_child(
        "MaterialFamilyGrid", true, false) as Control
    if grid == null:
        _fail("refinery grid missing")
        return
    for material_id in Materials.all_ids():
        var id: String = str(material_id)
        var card: Button = grid.find_child("MaterialIcon_" + id, true, false) as Button
        if card == null:
            _fail("missing material card: " + id)
            return
        var title: Label = card.find_child("ItemTitle", true, false) as Label
        if title == null or title.text != Materials.display_lines(id) or (
                not card.tooltip_text.begins_with(Materials.display_name(id))):
            _fail("refinery label or tooltip uses an obsolete name: " + id)
            return
        var font: Font = title.get_theme_font("font")
        for name_line in title.text.split("\n"):
            if font.get_string_size(name_line, HORIZONTAL_ALIGNMENT_LEFT, -1,
                    title.get_theme_font_size("font_size")).x > title.size.x + 1:
                _fail("renamed grade or family label is clipped: " + id)
                return
    # Confirm both conversion directions display names generated from stable
    # IDs, including the longer metal-composite names.
    for family in Materials.FAMILY_IDS:
        var family_id: String = str(family)
        for direction in [1, -1]:
            fac.call("_show_conversion", direction)
            fac.call("_select_conversion_family", family_id)
            await process_frame
            var title: Label = fac.get("modal_title") as Label
            var expected_heading: String = (
                "精製 " if direction == 1 else "分解 ") + EXPECTED_FAMILIES[family_id]
            if title.text != expected_heading:
                _fail("conversion heading not renamed: " + family_id)
                return
            var actions: Control = fac.get("modal_actions") as Control
            var ranks: Array = [0, 1] if direction == 1 else [2, 1]
            for index in range(2):
                var rank: int = ranks[index]
                var plan: Dictionary = Materials.recipe(family_id, rank, direction)
                var bar: Button = actions.find_child(
                    "ConvertRank_" + str(rank), true, false) as Button
                if bar == null:
                    _fail("missing conversion bar: " + family_id)
                    return
                var source: Label = bar.find_child("ItemTitle", true, false) as Label
                var target: Label = bar.find_child("ItemInfo", true, false) as Label
                var expected_source: String = Materials.display_name(
                    str(plan["input_id"])) + " ×" + str(plan["input_count"])
                var expected_target: String = "≫ " + Materials.display_name(
                    str(plan["output_id"])) + " ×" + str(plan["output_count"])
                if source == null or target == null or (
                        source.text != expected_source) or target.text != expected_target:
                    _fail("conversion recipe still shows an obsolete name: " + family_id)
                    return
    # Storage uses the same full names (not the refinery's two-line labels).
    fac.call("_switch_section", "warehouse")
    fac.call("_show_inventory", "materials")
    await process_frame
    await process_frame
    var storage: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if storage == null:
        _fail("material warehouse missing")
        return
    var entries: Array = storage.get("entries")
    if entries.size() != 12:
        _fail("material warehouse lost an entry")
        return
    for entry in entries:
        var id: String = str(entry.get("id", ""))
        if entry.get("name", "") != EXPECTED_NAMES.get(id, ""):
            _fail("warehouse still shows an obsolete material name: " + id)
            return
    if save.call("get_material_inventory") != starter:
        _fail("opening menus mutated save inventory")
        return
    save.set("active_slot", original_slot)
    save.set("active_data", original_data)
    print("SERA_V552_MATERIAL_NAMES_RUNTIME_PASS")
    quit(0)

extends SceneTree
## SERA LABO: actual native modal, marks, and 99-step conversion controls.
const Materials = preload("res://scripts/sera_base_materials.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_V553_LABO_CONTROLS_FAIL: " + reason)
    quit(1)

func _run() -> void:
    if Materials.MAX_BATCHES != 99 or (
            not Materials.recipe("scrap", 0, 1, 100).is_empty()):
        _fail("material conversion still permits more than 99 batches")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    fac.call("_select_prototype", "T01")
    var overlay: Control = fac.get("confirmation_overlay") as Control
    if overlay == null or not overlay.visible:
        _fail("craft confirmation overlay is not visible")
        return
    var craft_card: PanelContainer = overlay.find_child(
        "LaboConfirmCraftCard", true, false) as PanelContainer
    var picture: TextureRect = overlay.find_child(
        "LaboConfirmItemIcon", true, false) as TextureRect
    var nameplate: Label = overlay.find_child(
        "LaboConfirmItemName", true, false) as Label
    var details: Label = overlay.find_child(
        "LaboConfirmItemStats", true, false) as Label
    if craft_card == null or not craft_card.visible or picture == null or (
            picture.texture == null or nameplate == null or (
            nameplate.text != "コアシャーシ") or details == null or (
            details.text.find("基礎ステータス") < 0)):
        _fail("item preview/stats missing from the creation modal")
        return
    fac.call("_dismiss_confirmation")
    if overlay.visible:
        _fail("cancel did not hide confirmation")
        return
    fac.call("_switch_section", "materials")
    fac.call("_select_conversion_family", "scrap")
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var current: Label = actions.find_child(
        "ConversionCount_0", true, false) as Label
    var minus: Button = actions.find_child(
        "ConversionMinus_0", true, false) as Button
    var plus: Button = actions.find_child(
        "ConversionPlus_0", true, false) as Button
    if current == null or current.text != "01" or (
            current.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER) or (
            current.vertical_alignment != VERTICAL_ALIGNMENT_CENTER) or (
            minus == null or plus == null or not minus.disabled):
        _fail("centered count and +/- buttons missing")
        return
    fac.call("_conversion_batches_changed", 98)
    actions = fac.get("modal_actions") as VBoxContainer
    current = actions.find_child("ConversionCount_0", true, false) as Label
    plus = actions.find_child("ConversionPlus_0", true, false) as Button
    if current == null or current.text != "99" or plus == null or not plus.disabled:
        _fail("count not clamped at 99")
        return
    fac.call("_conversion_batches_changed", 1)
    if int(fac.get("conversion_batches")) != 99:
        _fail("count can overflow 99")
        return
    fac.call("_switch_section", "warehouse")
    var layer: Control = fac.get("item_layer") as Control
    var disposal: Button = layer.find_child(
        "BulkDeleteJunk", true, false) as Button
    var grid: ScrollContainer = layer.find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if disposal == null or disposal.get_node_or_null("JunkMarkIcon") == null or (
            grid == null):
        _fail("bulk purge is not linked to red unwanted pictogram")
        return
    var pool: Array = grid.get("pool")
    if pool.is_empty():
        _fail("virtualized warehouse cards are missing")
        return
    var card: Button = pool[0] as Button
    if card.get_node_or_null("FavoriteMarkIcon") == null or (
            card.get_node_or_null("JunkMarkIcon") == null):
        _fail("warehouse cards lack distinct vector markers")
        return
    # Both list markers follow the actual item-name end, never a fixed
    # right-side overlay. Marked states are applied to pooled native cards.
    var sample: Dictionary = {
        "uid": "H01-0001", "blueprint": "H01",
        "name": "スカウトバイザー", "affixes": [],
        "favorite": true, "junk": false
    }
    grid.call("configure", [sample], 2, "equipment")
    await process_frame
    card = (grid.get("pool") as Array)[0] as Button
    var name: Label = card.get_node("ItemTitle") as Label
    var favorite_icon: Control = card.get_node("FavoriteMarkIcon") as Control
    var junk_icon: Control = card.get_node("JunkMarkIcon") as Control
    if not favorite_icon.visible or junk_icon.visible or favorite_icon.size.x < 23.0:
        _fail("favorite list icon is not enlarged and visible")
        return
    var actual_gap: float = favorite_icon.position.x - (name.position.x + name.size.x)
    if actual_gap < 5.0 or actual_gap > 12.0 or (
            favorite_icon.position.x + favorite_icon.size.x > card.size.x - 5.0):
        _fail("favorite must be just to the right of the item name")
        return
    sample["favorite"] = false
    sample["junk"] = true
    grid.call("configure", [sample], 2, "equipment")
    await process_frame
    if favorite_icon.visible or not junk_icon.visible or (
            junk_icon.size.x < 23.0) or (
            absf(junk_icon.position.x - favorite_icon.position.x) > 0.5):
        _fail("junk icon must reuse enlarged inline name position")
        return
    grid.call("configure", [], 2, "equipment")
    await process_frame
    if favorite_icon.visible or junk_icon.visible:
        _fail("empty recycled cards retained classification markers")
        return
    # The detail-header indicators share the button's vector assets.
    var detail_marks: HBoxContainer = fac.get("warehouse_header_marks") as HBoxContainer
    if detail_marks == null or detail_marks.visible:
        _fail("detail header marker rail not hidden by default")
        return
    fac.call("_set_warehouse_header_marks", true, false)
    await process_frame
    var header_favorite: Control = detail_marks.get_node(
        "WarehouseHeaderFavoriteMarkIcon") as Control
    var header_junk: Control = detail_marks.get_node(
        "WarehouseHeaderJunkMarkIcon") as Control
    if not detail_marks.visible or not header_favorite.visible or (
            header_junk.visible) or header_favorite.size.y < 30.0:
        _fail("favorite detail icon must appear at header-name height")
        return
    fac.call("_set_warehouse_header_marks", false, true)
    await process_frame
    if header_favorite.visible or not header_junk.visible or (
            header_junk.size.y < 30.0):
        _fail("red junk detail icon not shown in the header")
        return
    fac.call("_clear_actions")
    if detail_marks.visible:
        _fail("warehouse detail icons leaked into another page")
        return
    print("SERA_V553_LABO_CONTROLS_RUNTIME_PASS")
    quit(0)

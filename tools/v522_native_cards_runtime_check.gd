extends SceneTree
## Cards must be native visible Godot buttons, not nested custom PanelContainers.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RoundSkinResource = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V522_NATIVE_CARD_FAIL: " + reason)
    quit(1)
func _actual_row_count(grid: VBoxContainer) -> int:
    # Craft cards and the passive preview now share one scrollable grid.
    # Count only interactive native HBox rows, not the preview panel.
    if grid == null:
        return 0
    var total: int = 0
    for child in grid.get_children():
        if child is HBoxContainer:
            total += 1
    return total

func _verify_grid(cards: Control, name: String, ids: Array, prefix: String, clickable: bool) -> bool:
    var grid: VBoxContainer = cards.find_child(name, true, false) as VBoxContainer
    if grid == null:
        _fail("missing VBox grid: " + name)
        return false
    var shown: Array = [ids[0]] if name == "PrototypeGrid" else ids
    var cols: int = 1 if name == "PrototypeGrid" else 3
    var expected_rows: int = 20 if name == "PrototypeGrid" else ceili(float(shown.size()) / float(cols))
    if _actual_row_count(grid) != expected_rows:
        _fail("native row count does not match current slot-bar grid: " + name)
        return false
    for row in grid.get_children():
        if name == "PrototypeGrid" and row.name == "PrototypeBasePreview":
            continue
        if not row is HBoxContainer:
            _fail("grid row is not a known-working native HBoxContainer")
            return false
    for id in shown:
        var card: Button = grid.find_child(prefix + str(id), true, false) as Button
        if card == null or not card.is_visible_in_tree() or (
                (card.find_child("ItemArt", true, false) as TextureRect).texture == null):
            _fail("native visible icon-bearing card is missing: " + prefix + str(id))
            return false
        if card.disabled == clickable or card.get_parent() is not HBoxContainer:
            _fail("wrong disabled/input status or row placement: " + card.name)
            return false
        if card.get_global_rect().size.x < 100.0 or card.get_global_rect().size.y < 78.0:
            _fail("native button size collapsed: " + card.name)
            return false
        if card.get_theme_stylebox("normal") is not StyleBoxTexture:
            _fail("the normal button style is not a rounded blue-grey StyleBoxFlat")
            return false
        if not card.text.contains("\n") or (name == "PrototypeGrid" and (
                not card.text.contains("基礎ステータス"))) or (name != "PrototypeGrid" and (
                not card.text.contains("0"))):
            _fail("native card must show a craft title or material quantity")
            return false
    return true
func _tap_card(card: Button) -> void:
    var point := card.get_global_rect().get_center()
    var down := InputEventScreenTouch.new()
    down.index=0
    down.pressed=true
    down.position=point
    root.push_input(down, true)
    await process_frame
    var up := InputEventScreenTouch.new()
    up.index=0
    up.pressed=false
    up.position=point
    root.push_input(up, true)
    await process_frame
func _verify_warehouse(fac: Node3D, grid_name: String, count: int, cols: int) -> bool:
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(grid_name, true, false) as ScrollContainer
    if list == null or not list.is_visible_in_tree() or (
            int(list.get("columns")) != cols or (list.get("entries") as Array).size() != count):
        _fail("virtual warehouse has wrong structure: " + grid_name)
        return false
    var pool: Array = list.get("pool")
    if pool.is_empty() or pool.size() > 32 or (
            (pool[0] as Button).get_theme_stylebox("normal") is not StyleBoxTexture):
        _fail("virtual warehouse must reuse visible native chamfer buttons")
        return false
    if count > 0 and ((pool[0] as Button).get_node("ItemArt") as TextureRect).texture == null:
        _fail("first warehouse image not ready")
        return false
    if count == 0 and int(list.get("virtual_slots")) != 999:
        _fail("empty hanger must expose 999 virtual boxes")
        return false
    return true
func _run() -> void:
    var style: StyleBoxFlat = RoundSkinResource.style("card")
    if style.corner_radius_top_left < 4 or style.corner_radius_bottom_right < 4 or style.bg_color.b <= style.bg_color.r:
        _fail("shared rounded blue-grey surface has wrong shape or hue")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    fac.call("_switch_section", "craft")
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "PrototypeGrid", Catalog.ORDER, "PrototypeIcon_", true):
        return
    var card: Button = (fac.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "prototypes" or (
            not (fac.get("confirmation_overlay") as Control).visible):
        _fail("tapping native prototype must open confirmation, not craft")
        return
    fac.call("_dismiss_confirmation")
    fac.call("_switch_section", "materials")
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "MaterialFamilyGrid", Materials.all_ids(), "MaterialIcon_", true):
        return
    card = (fac.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "conversion":
        _fail("tapping a native material button did not open conversion")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    fac.call("_show_inventory", "materials")
    await process_frame
    if not _verify_warehouse(fac, "WarehouseMaterials", 12, 2):
        return
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    if not _verify_warehouse(fac, "WarehouseEquipment", 0, 2):
        return
    var save: Node = root.get_node("SeraSave")
    var original_slot: int = int(save.get("active_slot"))
    var original_data: Dictionary = save.get("active_data").duplicate(true)
    save.set("active_slot", 1)
    save.set("active_data", {"crafted_items": [
        {"uid": "H01-0001", "blueprint": "H01", "slot": "head"}],
        "craft_serials": {"H01": 1}, "materials": {}})
    fac.call("_show_inventory", "equipment")
    await process_frame
    if not _verify_warehouse(fac, "WarehouseEquipment", 1, 2):
        return
    card = (fac.get("item_layer") as Control).find_child("WarehouseItem_H01-0001", true, false) as Button
    if card == null or card.disabled or card.get_node("ItemArt") == null:
        _fail("crafted instance not present in warehouse")
        return
    await _tap_card(card)
    if str(fac.get("page")) != "warehouse_item":
        _fail("warehouse item touch did not open UID-specific details")
        return
    save.set("active_slot", original_slot)
    save.set("active_data", original_data)
    print("SERA_V522_NATIVE_CARDS_RUNTIME_PASS: native icons/text, rounded blue-grey skins, four sections and real touches")
    quit(0)

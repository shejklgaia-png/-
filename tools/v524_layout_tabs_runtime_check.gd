extends SceneTree
## Verify direct VBox flow and strict single-selected tabs, not merely button nodes.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V524_LAYOUT_TABS_FAIL: " + why)
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

func _selected_count(tabs: HBoxContainer) -> int:
    var total: int = 0
    for child in tabs.get_children():
        if child is Button and (child as Button).button_pressed:
            total += 1
    return total
func _check_flow(fac: Node3D, page_name: String, first_card: String, expected: int) -> bool:
    var layer: VBoxContainer = fac.get("item_layer") as VBoxContainer
    var content: VBoxContainer = layer.get_parent() as VBoxContainer
    var actions: Control = fac.get("actions_area") as Control
    var body_label: Label = fac.get("modal_body") as Label
    if layer == null or content == null or content.name != "FacilityContent":
        _fail("item layer is not directly inside known-working FacilityContent")
        return false
    if not (content.get_child(content.get_child_count()-1) is Button):
        _fail("close button must follow cards and expandable spacer")
        return false
    if actions.get_index() >= layer.get_index():
        _fail("control actions must be before the visible item list")
        return false
    if layer.get_child_count() < 1:
        _fail("one expected card grid is missing")
        return false
    var grid: VBoxContainer = layer.find_child(page_name, true, false) as VBoxContainer
    var columns: int = 1 if page_name == "PrototypeGrid" else 3
    if grid == null or _actual_row_count(grid) != ceili(float(expected)/float(columns)):
        _fail("missing card rows for " + page_name)
        return false
    var card: Button = grid.find_child(first_card, true, false) as Button
    if card == null or not card.is_visible_in_tree() or (
            (card.find_child("ItemArt", true, false) as TextureRect).texture == null):
        _fail("first item missing from live layout: " + first_card)
        return false
    var back: Button = content.find_child("CloseFacility", false, false) as Button
    if back == null:
        _fail("back control not present in body")
        return false
    var rect: Rect2 = card.get_global_rect()
    var label_rect: Rect2 = body_label.get_global_rect()
    if rect.size.x < 80.0 or rect.size.y < 80.0 or rect.position.y <= label_rect.end.y:
        _fail("item rect collapsed or overlaps body label")
        return false
    var scroll: Control = grid.get_parent() as Control
    if scroll.get_global_rect().end.y > back.get_global_rect().position.y + 1.5:
        _fail("scroll viewport overlaps close button")
        return false
    return true
func _check_virtual(fac: Node3D, title: String, count: int, cols: int) -> bool:
    var w: ScrollContainer = (fac.get("item_layer") as Control).find_child(title, true, false) as ScrollContainer
    if w == null or not w.is_visible_in_tree() or int(w.get("columns")) != cols:
        _fail("missing visible warehouse virtual list: " + title)
        return false
    var entries: Array = w.get("entries")
    var pool: Array = w.get("pool")
    if entries.size() != count or pool.is_empty() or pool.size() > 32:
        _fail("wrong virtual warehouse entries/pool: " + title)
        return false
    var card: Button = pool[0] as Button
    if card == null or not card.is_visible_in_tree() or (
            card.get_theme_stylebox("normal") is not StyleBoxTexture):
        _fail("warehouse native button/chamfer style missing: " + title)
        return false
    var art: TextureRect = card.get_node("ItemArt") as TextureRect
    if count > 0 and (art == null or art.texture == null):
        _fail("warehouse first icon is not drawable: " + title)
        return false
    if count == 0 and int(w.get("virtual_slots")) != 2:
        _fail("empty hanger must show a pair of slots")
        return false
    return true
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var craft: Button = tabs.get_node("TabCraft") as Button
    var materials: Button = tabs.get_node("TabMaterials") as Button
    var warehouse: Button = tabs.get_node("TabWarehouse") as Button
    if craft.button_group == null or craft.button_group != materials.button_group or craft.button_group != warehouse.button_group:
        _fail("section tabs are not a single exclusive ButtonGroup")
        return
    if _selected_count(tabs) != 1 or not craft.button_pressed:
        _fail("craft is not the only selected tab")
        return
    if not _check_flow(fac, "PrototypeGrid", "PrototypeIcon_H01", 1):
        return
    materials.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not materials.button_pressed or str(fac.get("page")) != "families":
        _fail("material section tap left more than one selected tab")
        return
    if not _check_flow(fac, "MaterialFamilyGrid", "MaterialIcon_scrap_low", 12):
        return
    warehouse.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not warehouse.button_pressed:
        _fail("warehouse section tab is not exclusive")
        return
    if not _check_virtual(fac, "WarehouseMaterials", 12, 2):
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var mat_tab: Button = actions.find_child("WarehouseMaterialsTab", true, false) as Button
    var gear_tab: Button = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    if mat_tab.button_group == null or mat_tab.button_group != gear_tab.button_group:
        _fail("warehouse category buttons do not share a ButtonGroup")
        return
    gear_tab.pressed.emit()
    await process_frame
    # _show_inventory destroys/rebuilds category buttons every switch.
    # Re-query the newly created controls before checking their state.
    mat_tab = actions.find_child("WarehouseMaterialsTab", true, false) as Button
    gear_tab = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    if mat_tab == null or gear_tab == null or (
            mat_tab.button_pressed or not gear_tab.button_pressed):
        _fail("warehouse category tabs are both selected")
        return
    if not _check_virtual(fac, "WarehouseEquipment", 0, 2):
        return
    craft.pressed.emit()
    await process_frame
    if _selected_count(tabs) != 1 or not craft.button_pressed:
        _fail("switching back to craft leaves two tabs highlighted")
        return
    # Existing Android saves, unlike CI fresh profiles, skip the save-create
    # action entirely. Verify that exact branch: already claimed materials,
    # a valid crafted item, and an active save slot.
    # Scripts run with SceneTree rather than a project main scene:
    # access project autoload by its actual root node, not a GDScript global.
    var store: Node = root.get_node_or_null("SeraSave")
    if store == null:
        _fail("SeraSave autoload is missing in Godot test process")
        return
    var original_slot: int = int(store.get("active_slot"))
    var original_data: Dictionary = store.call("get_active_data")
    store.set("active_slot", 1)
    store.set("active_data", {
        "trial_materials_claimed": true,
        "crafted_items": [{"uid": "H01-0001", "blueprint": "H01", "slot": "head"}],
        "materials": {}, "craft_serials": {"H01": 1}
    })
    fac.call("_switch_section", "craft")
    await process_frame
    if not _check_flow(fac, "PrototypeGrid", "PrototypeIcon_H01", 1):
        return
    var owned: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if owned == null or owned.text.contains("所持"):
        _fail("craft catalog must not aggregate counts of existing items")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    if not _check_flow(fac, "MaterialFamilyGrid", "MaterialIcon_scrap_low", 12):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    if not _check_virtual(fac, "WarehouseMaterials", 12, 2):
        return
    store.set("active_slot", original_slot)
    store.set("active_data", original_data)
    print("SERA_V524_LAYOUT_TABS_RUNTIME_PASS: exclusive tabs and native flow, both empty and existing saves")
    quit(0)

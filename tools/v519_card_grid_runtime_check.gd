extends SceneTree
## Real on-screen viewport and parent clip tests for visible item grids.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const ChamferSlot = preload("res://scripts/sera_chamfer_slot.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V519_GRID_FAIL: " + msg)
    quit(1)
func _check_grid(actions: VBoxContainer, area: Control, name: String, ids: Array, prefix: String) -> bool:
    var grid: GridContainer = actions.find_child(name, true, false) as GridContainer
    if grid == null or grid.columns != 3:
        _fail("grid missing or not three columns: " + name)
        return false
    for id in ids:
        var card: Control = grid.find_child(prefix + str(id), true, false) as Control
        if card == null or not (card is ChamferSlot) or not card.is_visible_in_tree():
            _fail("unrendered slot: " + prefix + str(id))
            return false
        var rect: Rect2 = card.get_global_rect()
        if rect.size.x < 45.0 or rect.size.y < 42.0 or (
                not area.get_global_rect().has_point(rect.get_center())):
            _fail("slot is clipped or has zero area: " + prefix + str(id))
            return false
        var picture: TextureRect = card.find_child("Icon", true, false) as TextureRect
        if picture == null or picture.texture == null:
            _fail("missing icon on slot: " + str(id))
            return false
        var corners: PackedVector2Array = card.call("_border_points", Vector2(100, 100))
        if corners.size() != 9 or corners[0].x <= 0.0 or corners[0].y != 0.0:
            _fail("frame corners are not chamfered")
            return false
    return true
func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    if hub.has_node("BaseHUDLayer/BaseHUD/BaseQuickActions"):
        _fail("redundant bottom buttons still shown")
        return
    var facility: Node3D = hub.get_node("BaseFacilities") as Node3D
    var area: Control = facility.get("actions_area") as Control
    if area == null:
        _fail("persistent content area missing")
        return
    var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
    facility.call("_switch_section", "craft")
    await process_frame
    if not _check_grid(actions, area, "PrototypeGrid", Catalog.ORDER, "PrototypeIcon_"):
        return
    facility.call("_switch_section", "materials")
    await process_frame
    if not _check_grid(actions, area, "MaterialFamilyGrid", Materials.all_ids(), "MaterialIcon_"):
        return
    facility.call("_switch_section", "warehouse")
    await process_frame
    if not _check_grid(actions, area, "WarehouseMaterials", Materials.all_ids(), "MaterialIcon_"):
        return
    var tab: Button = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    if tab == null:
        _fail("warehouse equipment section not available")
        return
    tab.pressed.emit()
    await process_frame
    if not _check_grid(actions, area, "WarehouseEquipment", Catalog.ORDER, "WarehouseBlueprint_"):
        return
    for bp in Catalog.ORDER:
        var card: Control = actions.find_child("WarehouseBlueprint_" + str(bp), true, false) as Control
        var label: Label = card.find_child("SlotQuantity", true, false) as Label
        if label == null or not label.text.contains("0"):
            _fail("empty equipment slot must show count zero")
            return
    print("SERA_V519_CARD_GRID_RUNTIME_PASS: three visible grids, icons, notched empty slots, no bottom bar")
    quit(0)

extends SceneTree
## v519 frame+icons contract, rendered as native HBox/Button rows since v522.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const ChamferSkinResource = preload("res://scripts/sera_chamfer_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V519_GRID_FAIL: " + msg)
    quit(1)
func _check_grid(actions: VBoxContainer, area: Control, name: String, ids: Array, prefix: String) -> bool:
    var grid: VBoxContainer = actions.find_child(name, true, false) as VBoxContainer
    if grid == null or grid.get_child_count() != ceili(float(ids.size()) / 3.0):
        _fail("missing three-wide row grid: " + name)
        return false
    for id in ids:
        var card: Button = grid.find_child(prefix + str(id), true, false) as Button
        if card == null or not card.is_visible_in_tree() or card.icon == null:
            _fail("missing native card and real icon: " + prefix + str(id))
            return false
        var rect: Rect2 = card.get_global_rect()
        if rect.size.x < 45.0 or rect.size.y < 42.0 or (
                not area.get_global_rect().has_point(rect.get_center())):
            _fail("card is clipped or not laid out: " + card.name)
            return false
        if not card.get_theme_stylebox("normal") is StyleBoxTexture:
            _fail("corner-cut style missing: " + card.name)
            return false
    var frame: StyleBoxTexture = ChamferSkinResource.style(Color("#203747"), Color("#59c6da"))
    var img: Image = frame.texture.get_image()
    if img == null or img.get_pixel(0, 0).a > 0.05:
        _fail("four corner cuts have become opaque")
        return false
    return true
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    if hub.has_node("BaseHUDLayer/BaseHUD/BaseQuickActions"):
        _fail("redundant base menu returned")
        return
    var facility: Node3D = hub.get_node("BaseFacilities") as Node3D
    var area: Control = facility.get("actions_area") as Control
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
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    if not _check_grid(actions, area, "WarehouseEquipment", Catalog.ORDER, "WarehouseBlueprint_"):
        return
    for bp in Catalog.ORDER:
        var card: Button = actions.find_child("WarehouseBlueprint_" + str(bp), true, false) as Button
        if not card.text.contains("0"):
            _fail("empty category must show owned count zero")
            return
    print("SERA_V519_CARD_GRID_RUNTIME_PASS: 7/12/12/7 native cards with notched frames")
    quit(0)

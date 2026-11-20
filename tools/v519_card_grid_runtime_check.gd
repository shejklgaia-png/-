extends SceneTree
## v519 frame+icons contract, rendered as native HBox/Button rows since v522.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RoundSkinResource = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V519_GRID_FAIL: " + msg)
    quit(1)
func _check_grid(cards: Control, area: Control, name: String, ids: Array, prefix: String) -> bool:
    var grid: VBoxContainer = cards.find_child(name, true, false) as VBoxContainer
    var shown: Array = [ids[0]] if name == "PrototypeGrid" else ids
    var columns: int = 1 if name == "PrototypeGrid" else 3
    if grid == null or grid.get_child_count() != ceili(float(shown.size()) / float(columns)):
        _fail("missing expected bar/card rows: " + name)
        return false
    for id in shown:
        var card: Button = grid.find_child(prefix + str(id), true, false) as Button
        if card == null or not card.is_visible_in_tree() or (
                (card.find_child("ItemArt", true, false) as TextureRect).texture == null):
            _fail("missing native card and real icon: " + prefix + str(id))
            return false
        var rect: Rect2 = card.get_global_rect()
        if rect.size.x < 45.0 or rect.size.y < 42.0 or (
                id == shown[0] and not area.get_global_rect().has_point(rect.get_center())):
            _fail("card is clipped or not laid out: " + card.name)
            return false
        if not card.get_theme_stylebox("normal") is StyleBoxTexture:
            _fail("rounded blue-grey style missing: " + card.name)
            return false
    var frame: StyleBoxFlat = RoundSkinResource.style("card")
    if frame.corner_radius_top_left < 4 or frame.corner_radius_bottom_right < 4 or frame.bg_color.b <= frame.bg_color.r:
        _fail("rounded blue-grey card surface lost its specified radius or hue")
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
    if hub.has_node("BaseHUDLayer/BaseHUD/BaseQuickActions"):
        _fail("redundant base menu returned")
        return
    var facility: Node3D = hub.get_node("BaseFacilities") as Node3D
    var area: Control = facility.get("modal_panel") as Control
    var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
    facility.call("_switch_section", "craft")
    await process_frame
    if not _check_grid((facility.get("item_layer") as Control), area, "PrototypeGrid", Catalog.ORDER, "PrototypeIcon_"):
        return
    facility.call("_switch_section", "materials")
    await process_frame
    if not _check_grid((facility.get("item_layer") as Control), area, "MaterialFamilyGrid", Materials.all_ids(), "MaterialIcon_"):
        return
    facility.call("_switch_section", "warehouse")
    await process_frame
    if not _check_virtual(facility, "WarehouseMaterials", 12, 2):
        return
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    if not _check_virtual(facility, "WarehouseEquipment", 0, 2):
        return
    print("SERA_V519_CARD_GRID_RUNTIME_PASS: 7/12/12/7 native cards with rounded blue-grey frames")
    quit(0)

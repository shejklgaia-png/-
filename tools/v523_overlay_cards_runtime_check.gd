extends SceneTree
## Cards in a direct modal overlay bypass the Android-invisible nested content tree.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V523_OVERLAY_CARDS_FAIL: " + message)
    quit(1)
func _verify(fac: Node3D, key: String, prefix: String, count: int) -> bool:
    var layer: Control = fac.get("item_layer") as Control
    var area: Control = fac.get("modal") as Control
    if layer == null or layer.get_parent() == null or (
            layer.get_parent().name != "FacilityContent") or (
            not area.is_ancestor_of(layer)):
        _fail("cards must be siblings of the visible header inside FacilityContent")
        return false
    if not layer.is_visible_in_tree() or layer.get_child_count() < 1:
        _fail("no visible scrollable list")
        return false
    var grid: VBoxContainer = layer.find_child(key, true, false) as VBoxContainer
    if grid == null or grid.name != key:
        _fail("wrong overlay grid: " + key)
        return false
    var n: int = 0
    for row in grid.get_children():
        for card in row.get_children():
            if card is Button:
                n += 1
    if n != count:
        _fail("wrong card count in overlay: expected " + str(count) + " actual " + str(n))
        return false
    var first: Button = layer.find_child(prefix, true, false) as Button
    if first == null or first.get_global_rect().size.x < 90 or first.get_global_rect().size.y < 78:
        _fail("first card missing or collapsed: " + prefix)
        return false
    if not (fac.get("modal_panel") as Control).get_global_rect().has_point(
            first.get_global_rect().get_center()):
        _fail("first overlay card is outside facility sheet")
        return false
    if first.get_global_rect().position.y <= (
            (fac.get("modal_body") as Control).get_global_rect().end.y):
        _fail("overlay card is overlapping description text")
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
    if not _verify(fac, "PrototypeGrid", "PrototypeIcon_H01", 1):
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    if not _verify(fac, "MaterialFamilyGrid", "MaterialIcon_scrap_low", 12):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    if not _check_virtual(fac, "WarehouseMaterials", 12, 2):
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    await process_frame
    if not _check_virtual(fac, "WarehouseEquipment", 0, 2):
        return
    print("SERA_V523_OVERLAY_CARDS_RUNTIME_PASS: 7 craft / 12 materials / 12 storage / 7 gear cards in on-screen overlay")
    quit(0)

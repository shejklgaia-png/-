extends SceneTree
## v521 requirement: whole native card responds to touch at multiple coordinates.
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V521_FULL_CARD_TOUCH_FAIL: " + msg)
    quit(1)
func _tap(point: Vector2) -> void:
    var down := InputEventScreenTouch.new()
    down.pressed = true
    down.index = 0
    down.position = point
    root.push_input(down, true)
    await process_frame
    var up := InputEventScreenTouch.new()
    up.pressed = false
    up.index = 0
    up.position = point
    root.push_input(up, true)
    await process_frame
func _check_card(card: Button) -> bool:
    if card == null or not card.is_visible_in_tree() or card.disabled:
        _fail("card must be an enabled native Button")
        return false
    if card.icon == null or not card.text.contains("\n"):
        _fail("card must natively render art, name and quantity")
        return false
    var rect: Rect2 = card.get_global_rect()
    if rect.size.x < 100 or rect.size.y < 90 or card.mouse_filter != Control.MOUSE_FILTER_STOP:
        _fail("native hit rectangle is not the whole card")
        return false
    return true
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    for anchor in [Vector2(0.18,0.25), Vector2(0.54,0.57), Vector2(0.81,0.81)]:
        fac.call("_switch_section", "craft")
        await process_frame
        var card: Button = (fac.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
        if not _check_card(card):
            return
        var rect: Rect2 = card.get_global_rect()
        await _tap(rect.position + rect.size * anchor)
        if str(fac.get("page")) != "prototype_detail":
            _fail("card art/text/empty location did not open equipment details")
            return
    fac.call("_switch_section", "materials")
    await process_frame
    var material: Button = (fac.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    if not _check_card(material):
        return
    await _tap(material.get_global_rect().get_center())
    if str(fac.get("page")) != "conversion":
        _fail("material full-card touch failed")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    var read_only: Button = (fac.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    if read_only == null or not read_only.disabled:
        _fail("warehouse materials must remain read-only")
        return
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    var item: Button = (fac.get("item_layer") as Control).find_child("WarehouseBlueprint_H01", true, false) as Button
    if not _check_card(item):
        return
    await _tap(item.get_global_rect().get_center())
    if str(fac.get("page")) != "warehouse_owned":
        _fail("warehouse equipment card touch failed")
        return
    print("SERA_V521_FULL_CARD_TOUCH_RUNTIME_PASS: full native card touch at artwork, text, padding")
    quit(0)

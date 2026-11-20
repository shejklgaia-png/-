extends SceneTree
## The actual touch point is on the artwork, visible name and free card space.
## Never substitute pressed.emit(): it conceals hit-test and z-order bugs.
const ChamferSlot = preload("res://scripts/sera_chamfer_slot.gd")
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_V521_FULL_CARD_TOUCH_FAIL: " + why)
    quit(1)

func _touch(point: Vector2) -> void:
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

func _card_ok(card: Control, target_name: String) -> bool:
    if card == null or not (card is ChamferSlot) or not card.is_visible_in_tree():
        _fail("slot missing or hidden: " + target_name)
        return false
    var target: Button = card.get_node_or_null(target_name) as Button
    var icon: TextureRect = card.get_node_or_null("SlotPadding/SlotContent/Icon") as TextureRect
    var title: Label = card.get_node_or_null("SlotPadding/SlotContent/SlotTitle") as Label
    if target == null or icon == null or icon.texture == null or title == null:
        _fail("full-card target or source art/label is missing: " + target_name)
        return false
    var rect: Rect2 = card.get_global_rect()
    var touch_rect: Rect2 = target.get_global_rect()
    if not target.is_visible_in_tree() or target.disabled or (
            target.mouse_filter != Control.MOUSE_FILTER_STOP) or (
            not touch_rect.has_point(rect.get_center())) or (
            absf(rect.size.x - touch_rect.size.x) > 2.0) or (
            absf(rect.size.y - touch_rect.size.y) > 2.0) or (
            target.get_parent() != card):
        _fail("touch target does not cover full slot rectangle: " + target_name)
        return false
    var count: int = 0
    for child in card.find_children("*", "Button", true, false):
        count += 1
    if count != 1:
        _fail("more than one button inside card: " + target_name)
        return false
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer

    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var card: Control = actions.find_child("PrototypeIcon_H01", true, false) as Control
    if not _card_ok(card, "Choose_H01"):
        return
    var icon: TextureRect = card.find_child("Icon", true, false) as TextureRect
    var name_label: Label = card.find_child("SlotTitle", true, false) as Label
    await _touch(icon.get_global_rect().get_center())
    if str(fac.get("page")) != "prototype_detail":
        _fail("touch on icon did not open equipment details")
        return
    fac.call("navigate_back")
    await process_frame
    card = actions.find_child("PrototypeIcon_H01", true, false) as Control
    if not _card_ok(card, "Choose_H01"):
        return
    name_label = card.find_child("SlotTitle", true, false) as Label
    await _touch(name_label.get_global_rect().get_center())
    if str(fac.get("page")) != "prototype_detail":
        _fail("touch on equipment name did not open details")
        return
    fac.call("navigate_back")
    await process_frame
    card = actions.find_child("PrototypeIcon_H01", true, false) as Control
    if not _card_ok(card, "Choose_H01"):
        return
    var empty_area := card.get_global_rect()
    await _touch(empty_area.position + Vector2(empty_area.size.x - 13.0, empty_area.size.y - 13.0))
    if str(fac.get("page")) != "prototype_detail":
        _fail("touch on padding/unused card area did not open details")
        return

    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    card = actions.find_child("MaterialIcon_scrap_low", true, false) as Control
    if not _card_ok(card, "Open_scrap"):
        return
    icon = card.find_child("Icon", true, false) as TextureRect
    await _touch(icon.get_global_rect().get_center())
    if str(fac.get("page")) != "conversion":
        _fail("material icon area is not a working full-card action")
        return

    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var material: Control = actions.find_child("MaterialIcon_scrap_low", true, false) as Control
    if material == null or material.find_child("Select", true, false) != null:
        _fail("read-only warehouse materials must not become action buttons")
        return
    var warehouse_tab: Button = actions.find_child("WarehouseEquipmentTab", true, false) as Button
    warehouse_tab.pressed.emit()
    await process_frame
    await process_frame
    card = actions.find_child("WarehouseBlueprint_H01", true, false) as Control
    if not _card_ok(card, "ShowOwned_H01"):
        return
    icon = card.find_child("Icon", true, false) as TextureRect
    await _touch(icon.get_global_rect().get_center())
    if str(fac.get("page")) != "warehouse_owned":
        _fail("warehouse equipment icon does not open owned instance list")
        return
    print("SERA_V521_FULL_CARD_TOUCH_RUNTIME_PASS: art, label, padding, converter, warehouse use full cards")
    quit(0)

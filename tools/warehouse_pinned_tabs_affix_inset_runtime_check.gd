extends SceneTree
## Fixed warehouse action tabs and horizontally inset five-effect card rows.
const Affixes = preload("res://scripts/sera_craft_affixes.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_WAREHOUSE_PINNED_TABS_AFFIX_INSET_FAIL: " + reason)
    quit(1)

func _check_tabs(fac: Node3D, equipment: bool) -> bool:
    var scroll: ScrollContainer = fac.get("actions_scroll") as ScrollContainer
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var layer: Control = fac.get("item_layer") as Control
    if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("warehouse action controls must never require vertical scrolling")
        return false
    var categories: HBoxContainer = actions.find_child(
        "WarehouseCategoryTabs", true, false) as HBoxContainer
    if categories == null or categories.get_child_count() != 2:
        _fail("equipment/material category controls were removed")
        return false
    var hanger: HBoxContainer = actions.find_child(
        "WarehouseHangerTabs", true, false) as HBoxContainer
    if equipment:
        if hanger == null or hanger.get_child_count() != 7:
            _fail("seven equipment category controls must remain visible")
            return false
        var purge: Button = layer.find_child(
            "BulkDeleteJunk", false, false) as Button
        if purge == null or purge.get_parent() != layer:
            _fail("purge action must be outside the action-tab ScrollContainer")
            return false
        var grid: ScrollContainer = layer.find_child(
            "WarehouseEquipment", false, false) as ScrollContainer
        if grid == null or grid.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
            _fail("only warehouse cards may scroll vertically")
            return false
    elif hanger != null:
        _fail("material warehouse must not display equipment-only tabs")
        return false
    return true

func _run() -> void:
    root.size = Vector2i(720, 1280)
    var base: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(base)
    await process_frame
    await process_frame
    var fac: Node3D = base.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    if not _check_tabs(fac, true):
        return
    var cards: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", false, false) as ScrollContainer
    var example: Array = [
        {"id": "guard", "value": 5},
        {"id": "energy_recovery", "value": 4},
        {"id": "attack", "value": 5},
        {"id": "stagger", "value": 2},
        {"id": "defense", "value": 3},
    ]
    if not Affixes.valid(example):
        _fail("five-effect fixture invalid")
        return
    cards.call("configure", [{
        "uid": "H01-0001", "blueprint": "H01", "name": "スカウトバイザー",
        "affixes": example, "favorite": false, "junk": false,
    }], 2, "equipment")
    await process_frame
    var pool: Array = cards.get("pool")
    if pool.is_empty():
        _fail("no pooled equipment card")
        return
    var card: Button = pool[0] as Button
    var left: Label = card.get_node("ItemEffects") as Label
    var right: Label = card.get_node("ItemEffectsRight") as Label
    var center: ColorRect = card.get_node("EffectCenterDivider") as ColorRect
    var midway: float = card.size.x * 0.5
    if not is_equal_approx(left.position.x, 22.0) or (
            not is_equal_approx(right.position.x, midway + 14.0)) or (
            left.position.x + left.size.x >= center.position.x) or (
            right.position.x <= center.position.x + center.size.x):
        _fail("effect text has not been inset on both sides of the center line")
        return
    if left.text.split("\n").size() != 3 or right.text.split("\n").size() != 2:
        _fail("five effect labels must retain three and two visible rows")
        return
    cards.call("configure", [], 2, "equipment")
    await process_frame
    if right.visible or center.visible:
        _fail("empty pooled cards must hide second column and separator")
        return
    fac.call("_show_inventory", "materials")
    await process_frame
    await process_frame
    if not _check_tabs(fac, false):
        return
    fac.call("_show_inventory", "equipment")
    await process_frame
    if not _check_tabs(fac, true):
        return
    fac.call("_switch_section", "craft")
    await process_frame
    if (fac.get("actions_scroll") as ScrollContainer).vertical_scroll_mode != (
            ScrollContainer.SCROLL_MODE_AUTO):
        _fail("other LABO pages must restore their native scroll behavior")
        return
    print("SERA_WAREHOUSE_PINNED_TABS_AFFIX_INSET_RUNTIME_PASS")
    quit(0)

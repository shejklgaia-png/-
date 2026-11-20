extends SceneTree
## v541: the duplicate BASE SPECIFICATION block must not occupy any craft slot.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V541_CRAFT_DETAIL_REMOVED_FAIL: " + message)
    quit(1)
func _verify(fac: Node3D, prototype_id: String) -> bool:
    var layer: Control = fac.get("item_layer") as Control
    var grid: VBoxContainer = layer.find_child("PrototypeGrid", true, false) as VBoxContainer
    if grid == null or grid.get_child_count() != 20 or (
            int(grid.get_meta("card_count", 0)) != 20):
        _fail("craft grid must have exactly twenty equipment positions")
        return false
    for child in grid.get_children():
        if not child is HBoxContainer:
            _fail("a non-card element appeared between equipment slots")
            return false
    if layer.find_child("PrototypeBasePreview", true, false) != null or (
            layer.find_child("PrototypeBaseStats", true, false) != null):
        _fail("retired equipment-detail panel is still present")
        return false
    var card: Button = grid.find_child("PrototypeIcon_" + prototype_id,
        true, false) as Button
    if card == null:
        _fail("original equipment selection card disappeared")
        return false
    var summary: Label = card.find_child("ItemInfo", true, false) as Label
    if summary == null or summary.text.is_empty():
        _fail("short equipment summary must remain in the selection card")
        return false
    var locked: Button = grid.find_child("LockedCraftSlot_20", true, false) as Button
    if locked == null or not locked.disabled:
        _fail("the twenty-slot LOCKED SLOT contract changed")
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
    if not _verify(fac, "H01"):
        return
    fac.call("_select_craft_slot", "torso")
    await process_frame
    await process_frame
    if not _verify(fac, "T01"):
        return
    print("SERA_V541_CRAFT_DETAIL_REMOVED_RUNTIME_PASS")
    quit(0)

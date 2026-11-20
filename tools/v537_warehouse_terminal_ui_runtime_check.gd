extends SceneTree
## v537: verify live warehouse readability without abandoning native cards.
const TerminalSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V537_TERMINAL_UI_FAIL: " + why)
    quit(1)
func _run() -> void:
    var style: StyleBoxFlat = TerminalSkin.style("pressed")
    if style == null or style.border_width_bottom < 3 or style.shadow_size != 0:
        _fail("navigation still relies on a glowing filled selection")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "STORAGE")
    await process_frame
    await process_frame
    # Equipment is the default; material archive remains reachable by tab.
    if str(fac.get("warehouse_section")) != "equipment":
        _fail("storage must land on equipment")
        return
    fac.call("_show_inventory", "materials")
    var grid: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if grid == null or int(grid.get("columns")) != 2 or (
            (grid.get("entries") as Array).size() != 12):
        _fail("twelve materials must use two readable columns")
        return
    var pool: Array = grid.get("pool")
    if pool.is_empty() or pool.size() > 32:
        _fail("warehouse pool missing or unbounded")
        return
    for element in pool:
        var card: Button = element as Button
        if card == null or not card.visible or card.name.begins_with("WarehouseEmpty"):
            continue
        var art: TextureRect = card.get_node("ItemArt") as TextureRect
        var title: Label = card.get_node("ItemTitle") as Label
        var meta: Label = card.get_node("ItemMeta") as Label
        var marker: ColorRect = card.get_node("TierMarker") as ColorRect
        var count: Label = card.get_node("ItemEffects") as Label
        if art == null or art.texture == null or title == null or (
                title.text.is_empty()) or meta == null or marker == null or count == null:
            _fail("material card is missing artwork or typography")
            return
        if not card.clip_contents or not art.clip_contents or (
                art.size.x != art.size.y) or (
                title.autowrap_mode != TextServer.AUTOWRAP_OFF):
            _fail("material artwork is distorted or title wraps")
            return
        if title.position.x + title.size.x > card.size.x + 1.0 or (
                title.position.y + title.size.y > card.size.y + 1.0):
            _fail("material title exceeds its card")
            return
        if count.text.find("所持") < 0:
            _fail("inventory count is not independently legible")
            return
        if card.size.x >= 244.0 and (
                art.position.x + art.size.x + 2.0 > title.position.x):
            _fail("wide-layout artwork overlaps material name")
            return
    grid.scroll_vertical = 250
    await process_frame
    if (grid.get("pool") as Array).size() > 32:
        _fail("scrolling allocated an unbounded number of native cards")
        return
    fac.call("_show_inventory", "equipment")
    await process_frame
    var equipment: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if equipment == null or int(equipment.get("columns")) != 2:
        _fail("equipment hanger lost two-column layout")
        return
    print("SERA_V537_TERMINAL_UI_RUNTIME_PASS")
    quit(0)

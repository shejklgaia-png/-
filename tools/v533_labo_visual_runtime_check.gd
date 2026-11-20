extends SceneTree
## Reference-layout smoke test: actual rendered native cards have clipped art
## while all original selection/hanger actions remain reachable.
const Materials = preload("res://scripts/sera_base_materials.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_V533_LABO_VISUAL_FAIL: " + message)
    quit(1)
func _assert_card(card: Button, need_art: bool = true) -> bool:
    if card == null or not card.is_visible_in_tree():
        _fail("card missing from actual interface")
        return false
    if card.icon != null:
        _fail("native Button.icon remains responsible for rendering sprite")
        return false
    var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
    var heading: Label = card.find_child("ItemTitle", true, false) as Label
    if art == null or heading == null or heading.text.is_empty():
        _fail("card has no internal image/text layout")
        return false
    if need_art and art.texture == null:
        _fail("card has no image after deferred load")
        return false
    if art.mouse_filter != Control.MOUSE_FILTER_IGNORE or (
            not card.get_global_rect().grow(1).encloses(art.get_global_rect())):
        _fail("sprite can intercept touch or bleed outside card")
        return false
    if card.get_theme_stylebox("normal") is not StyleBoxTexture:
        _fail("card lost shared chamfered navy-cyan background")
        return false
    return true
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "LABO")
    await process_frame
    await process_frame
    var layer: Control = fac.get("item_layer") as Control
    if not _assert_card(layer.find_child("PrototypeIcon_H01", true, false) as Button):
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    layer = fac.get("item_layer") as Control
    for material_id in Materials.all_ids():
        var card: Button = layer.find_child(
            "MaterialIcon_" + str(material_id), true, false) as Button
        if not _assert_card(card):
            return
        var art: TextureRect = card.find_child("ItemArt", true, false) as TextureRect
        if art.size.x > 68.0 or card.size.y > 117.0:
            _fail("material cards exceed the reference density")
            return
    fac.call("_select_conversion_family", "alloy")
    await process_frame
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var bar: Button = actions.find_child("ConvertRank_0", true, false) as Button
    if bar == null or bar.icon != null or not (
            (bar.find_child("ConvertInputIcon_0", true, false) as TextureRect).texture != null
            and (bar.find_child("ConvertOutputIcon_0", true, false) as TextureRect).texture != null):
        _fail("conversion does not show two independent bounded thumbnails")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    layer = fac.get("item_layer") as Control
    var list: ScrollContainer = layer.find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if list == null:
        _fail("virtual warehouse materials list vanished")
        return
    var cards: Array = list.get("pool")
    if cards.is_empty() or cards.size() > 32:
        _fail("warehouse pooling contract broken")
        return
    var first: Button = cards[0] as Button
    if (first.get_node("ItemArt") as TextureRect).texture == null or (
            first.get_theme_stylebox("normal") is not StyleBoxTexture):
        _fail("warehouse card lacks reference art or shared chamfer style")
        return
    print("SERA_V533_LABO_VISUAL_RUNTIME_PASS")
    quit(0)

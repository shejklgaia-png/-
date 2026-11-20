extends SceneTree
## Cards must be native visible Godot buttons, not nested custom PanelContainers.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RoundSkinResource = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V522_NATIVE_CARD_FAIL: " + reason)
    quit(1)
func _verify_grid(cards: Control, name: String, ids: Array, prefix: String, clickable: bool) -> bool:
    var grid: VBoxContainer = cards.find_child(name, true, false) as VBoxContainer
    if grid == null:
        _fail("missing VBox grid: " + name)
        return false
    if grid.get_child_count() != ceili(float(ids.size()) / 3.0):
        _fail("grid needs an HBox row per three native buttons: " + name)
        return false
    for row in grid.get_children():
        if not row is HBoxContainer:
            _fail("grid row is not a known-working native HBoxContainer")
            return false
    for id in ids:
        var card: Button = grid.find_child(prefix + str(id), true, false) as Button
        if card == null or not card.is_visible_in_tree() or card.icon == null:
            _fail("native visible icon-bearing card is missing: " + prefix + str(id))
            return false
        if card.disabled == clickable or card.get_parent() is not HBoxContainer:
            _fail("wrong disabled/input status or row placement: " + card.name)
            return false
        if card.get_global_rect().size.x < 100.0 or card.get_global_rect().size.y < 90.0:
            _fail("native button size collapsed: " + card.name)
            return false
        if card.get_theme_stylebox("normal") is not StyleBoxFlat:
            _fail("the normal button style is not a rounded blue-grey StyleBoxFlat")
            return false
        if not card.text.contains("\n") or not card.text.contains("0"):
            _fail("native card must render title/count without child labels")
            return false
    return true
func _tap_card(card: Button) -> void:
    var point := card.get_global_rect().get_center()
    var down := InputEventScreenTouch.new()
    down.index=0
    down.pressed=true
    down.position=point
    root.push_input(down, true)
    await process_frame
    var up := InputEventScreenTouch.new()
    up.index=0
    up.pressed=false
    up.position=point
    root.push_input(up, true)
    await process_frame
func _run() -> void:
    var style: StyleBoxFlat = RoundSkinResource.style("card")
    if style.corner_radius_top_left < 8 or style.corner_radius_bottom_right < 8 or style.bg_color.b <= style.bg_color.r:
        _fail("shared rounded blue-grey surface has wrong shape or hue")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    fac.call("_switch_section", "craft")
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "PrototypeGrid", Catalog.ORDER, "PrototypeIcon_", true):
        return
    var card: Button = (fac.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "prototype_detail":
        _fail("tapping native prototype button did not open its detail")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "MaterialFamilyGrid", Materials.all_ids(), "MaterialIcon_", true):
        return
    card = (fac.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "conversion":
        _fail("tapping a native material button did not open conversion")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "WarehouseMaterials", Materials.all_ids(), "MaterialIcon_", false):
        return
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    if not _verify_grid((fac.get("item_layer") as Control), "WarehouseEquipment", Catalog.ORDER, "WarehouseBlueprint_", true):
        return
    card = (fac.get("item_layer") as Control).find_child("WarehouseBlueprint_H01", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "warehouse_owned":
        _fail("native warehouse card did not open instance list")
        return
    print("SERA_V522_NATIVE_CARDS_RUNTIME_PASS: native icons/text, rounded blue-grey skins, four sections and real touches")
    quit(0)

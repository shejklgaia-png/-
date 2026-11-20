extends SceneTree
## Cards must be native visible Godot buttons, not nested custom PanelContainers.
const Materials = preload("res://scripts/sera_base_materials.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Skin = preload("res://scripts/sera_chamfer_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V522_NATIVE_CARD_FAIL: " + reason)
    quit(1)
func _verify_grid(actions: VBoxContainer, name: String, ids: Array, prefix: String, clickable: bool) -> bool:
    var grid: VBoxContainer = actions.find_child(name, true, false) as VBoxContainer
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
        if card.get_theme_stylebox("normal") is not StyleBoxTexture:
            _fail("the normal button style is not a chamfered StyleBoxTexture")
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
    var style: StyleBoxTexture = Skin.style(Color("#203747"), Color("#59c6da"))
    var pixels: Image = (style.texture as Texture2D).get_image()
    if pixels == null or pixels.get_pixel(0,0).a > 0.05 or (
            pixels.get_pixel(24,0).a < 0.9) or (
            pixels.get_pixel(24,24).a < 0.9):
        _fail("the StyleBoxTexture lacks transparent four cut corners")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    fac.call("_switch_section", "craft")
    await process_frame
    if not _verify_grid(actions, "PrototypeGrid", Catalog.ORDER, "PrototypeIcon_", true):
        return
    var card: Button = actions.find_child("PrototypeIcon_H01", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "prototype_detail":
        _fail("tapping native prototype button did not open its detail")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    if not _verify_grid(actions, "MaterialFamilyGrid", Materials.all_ids(), "MaterialIcon_", true):
        return
    card = actions.find_child("MaterialIcon_scrap_low", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "conversion":
        _fail("tapping a native material button did not open conversion")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    if not _verify_grid(actions, "WarehouseMaterials", Materials.all_ids(), "MaterialIcon_", false):
        return
    (actions.find_child("WarehouseEquipmentTab", true, false) as Button).pressed.emit()
    await process_frame
    if not _verify_grid(actions, "WarehouseEquipment", Catalog.ORDER, "WarehouseBlueprint_", true):
        return
    card = actions.find_child("WarehouseBlueprint_H01", true, false) as Button
    await _tap_card(card)
    if str(fac.get("page")) != "warehouse_owned":
        _fail("native warehouse card did not open instance list")
        return
    print("SERA_V522_NATIVE_CARDS_RUNTIME_PASS: native icons/text, chamfered skins, four sections and real touches")
    quit(0)

extends SceneTree
## v509 screen navigation: no dropdown, one back step per gesture/key.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_PAGED_BACK_RUNTIME_FAIL: " + why)
    quit(1)

func _back_key() -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = KEY_BACK
    event.pressed = true
    return event

func _outer_tap() -> InputEventMouseButton:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = Vector2(5, 5)
    return event

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    current_scene = hub
    await process_frame
    var facility: Node3D = hub.get_node("BaseFacilities") as Node3D
    for facility_id in ["SMELTER", "RECYCLER"]:
        facility.call("open_facility", facility_id)
        if str(facility.get("page")) != "families":
            _fail("opening converter must show full-page material family choices")
            return
        var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
        if actions.get_node_or_null("MaterialFamily") != null:
            _fail("dropdown returned in converter main page")
            return
        for family in ["scrap", "alloy", "electronics", "organic"]:
            if (facility.get("item_layer") as Control).find_child("MaterialIcon_" + family + "_low", true, false) == null:
                _fail("family choice absent: " + family)
                return
        facility.call("_select_conversion_family", "alloy")
        if str(facility.get("page")) != "conversion":
            _fail("family choice did not open the dedicated recipe page")
            return
        actions = facility.get("modal_actions") as VBoxContainer
        if actions.get_node_or_null("MaterialFamily") != null or (
                actions.find_child("ConvertRank_1", true, false) == null):
            _fail("dedicated recipe page did not show its batch/rank buttons")
            return
        facility.call("_input", _back_key())
        if str(facility.get("page")) != "families" or (
                not bool(facility.call("is_menu_open"))):
            _fail("Android back must go from recipe page to family list")
            return
        facility.call("_select_conversion_family", "organic")
        hub.get_window().go_back_requested.emit()
        if str(facility.get("page")) != "families":
            _fail("window back did not return from converter recipe")
            return
        facility.call("_select_conversion_family", "organic")
        facility.call("_on_shade_input", _outer_tap())
        if str(facility.get("page")) != "families" or (
                not bool(facility.call("is_menu_open"))):
            _fail("outside tap must step back one page, not close all")
            return
        facility.call("_on_shade_input", _outer_tap())
        if bool(facility.call("is_menu_open")):
            _fail("outside tap on top-level facility should close the modal")
            return
    facility.call("open_facility", "LABO")
    var actions: VBoxContainer = facility.get("modal_actions") as VBoxContainer
    if actions.get_node_or_null("OpenPrototypeCatalog") != null:
        _fail("LABO must not open a redundant home menu")
        return
    # LABO opens the equipment catalog directly; Back closes it.
    if str(facility.get("page")) != "prototypes":
        _fail("LABO Shell development must open the independent prototype catalog")
        return
    actions = facility.get("modal_actions") as VBoxContainer
    const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
    for bp in ["H01", "T01", "A01", "L01", "B01", "WR01", "WL01"]:
        var spec: Dictionary = Catalog.spec(bp)
        facility.call("_select_craft_slot", str(spec["slot"]))
        if (facility.get("item_layer") as Control).find_child(
                "PrototypeIcon_" + bp, true, false) == null:
            _fail("LABO slot catalog has missing entry: " + bp)
            return
    facility.call("_select_craft_slot", "head")
    var choose: Button = (facility.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
    if choose == null:
        _fail("LABO prototype item must be selectable")
        return
    choose.pressed.emit()
    if str(facility.get("page")) != "prototypes" or (
            not (facility.get("confirmation_overlay") as Control).visible):
        _fail("LABO prototype must open confirmation, not mint immediately")
        return
    facility.call("navigate_back")
    if (facility.get("confirmation_overlay") as Control).visible or (
            str(facility.get("page")) != "prototypes"):
        _fail("LABO confirmation Back must return to catalog without crafting")
        return
    facility.call("navigate_back")
    if bool(facility.call("is_menu_open")):
        _fail("LABO catalog Back must close without returning to a home page")
        return

    hub.call("_enter_nexus")
    await process_frame
    await process_frame
    var nexus: Node = current_scene
    if nexus == null or nexus.name != "CommandNexus":
        _fail("failed to enter NEXUS")
        return
    nexus.call("_select_target", "SYSTEM")
    await create_timer(0.26).timeout
    if str(nexus.get("focused_target")) != "SYSTEM":
        _fail("SYSTEM submenu did not open")
        return
    var hud: Control = nexus.get("hud") as Control
    var outside := Vector2(hud.size.x * 0.04, hud.size.y * 0.14)
    nexus.call("_tap_at", outside)
    await create_timer(0.26).timeout
    if not str(nexus.get("focused_target")).is_empty():
        _fail("outside tap did not return NEXUS to overview")
        return
    nexus.call("_select_target", "SYSTEM")
    await create_timer(0.26).timeout
    nexus.call("_input", _back_key())
    await create_timer(0.26).timeout
    if not str(nexus.get("focused_target")).is_empty():
        _fail("Android back did not return NEXUS to overview")
        return
    nexus.get_window().go_back_requested.emit()
    await process_frame
    await process_frame
    if current_scene == null or current_scene.name != "BaseExploration":
        _fail("Android back from NEXUS overview did not return to base")
        return
    print("SERA_PAGED_BACK_RUNTIME_PASS")
    quit(0)

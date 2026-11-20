extends SceneTree
## Portrait UI visibility and section switching, not mere scene-level node existence.
func _initialize() -> void:
    call_deferred("_run")
func _fail(msg: String) -> void:
    push_error("SERA_V518_MENU_VISIBILITY_FAIL: " + msg)
    quit(1)
func _visible_button(button: Button, view: Rect2) -> bool:
    if button == null or not button.is_visible_in_tree():
        return false
    var rect: Rect2 = button.get_global_rect()
    return not button.disabled and rect.size.x >= 80.0 and (
        rect.size.y >= 42.0 and view.has_point(rect.get_center()))
func _tap_button(button: Button) -> void:
    # Send native touchscreen events. Headless synthetic mouse clicks have a
    # known Godot 4.4+ native-Window hover regression; Android uses touch.
    var center: Vector2 = button.get_global_rect().get_center()
    var down := InputEventScreenTouch.new()
    down.index = 0
    down.pressed = true
    down.position = center
    root.push_input(down, true)
    await process_frame
    var up := InputEventScreenTouch.new()
    up.index = 0
    up.pressed = false
    up.position = center
    root.push_input(up, true)
    await process_frame

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var viewport: Rect2 = Rect2(Vector2.ZERO, hub.get_viewport().get_visible_rect().size)
    var hud: Control = hub.get_node("BaseHUDLayer/BaseHUD") as Control
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    if hud.size.x < viewport.size.x - 1.0 or hud.size.y < viewport.size.y - 1.0:
        _fail("HUD size is not tied to actual viewport")
        return
    if hud.has_node("BaseQuickActions"):
        _fail("old bottom bar is still present")
        return
    facilities.call("open_facility", "LABO")
    # Wait for Control sorting after opening a formerly hidden modal.
    # A touch at the pre-layout rect does not represent a user-visible tap.
    await process_frame
    await process_frame
    var craft_tab: Button = (facilities.get("section_tabs") as HBoxContainer).get_node("TabCraft") as Button
    if not _visible_button(craft_tab, viewport):
        _fail("craft section tab has not been laid out on screen")
        return
    await _tap_button(craft_tab)
    await process_frame
    if str(facilities.get("page")) != "prototypes":
        _fail("craft tab tap must open the slot-based catalog")
        return
    var tabs: HBoxContainer = facilities.get("section_tabs") as HBoxContainer
    if tabs == null or tabs.name != "FacilitySectionTabs":
        _fail("persistent section navigation missing")
        return
    for id in ["TabCraft", "TabMaterials", "TabWarehouse"]:
        var nav: Button = tabs.get_node_or_null(id) as Button
        if not _visible_button(nav, viewport):
            _fail("section tab hidden or too small: " + id)
            return
    var actions: VBoxContainer = facilities.get("modal_actions") as VBoxContainer
    var first: Button = (facilities.get("item_layer") as Control).find_child("PrototypeIcon_H01", true, false) as Button
    if not _visible_button(first, viewport):
        _fail("first equipment item cannot be selected on screen")
        return
    await _tap_button(first)
    await process_frame
    var overlay: Control = facilities.get("confirmation_overlay") as Control
    if str(facilities.get("page")) != "prototypes" or not overlay.visible:
        _fail("craft tap must open a confirmation before minting")
        return
    var craft: Button = overlay.find_child("LaboConfirmAccept", true, false) as Button
    if not craft.is_visible_in_tree() or not viewport.has_point(craft.get_global_rect().get_center()):
        _fail("confirm action is outside visible portrait dialog")
        return
    facilities.call("_dismiss_confirmation")
    await _tap_button(tabs.get_node("TabMaterials") as Button)
    await process_frame
    if str(facilities.get("page")) != "families":
        _fail("materials tab did not open material family choices")
        return
    var family: Button = (facilities.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    if not _visible_button(family, viewport):
        _fail("first material family cannot be picked")
        return
    await _tap_button(family)
    await process_frame
    if str(facilities.get("page")) != "conversion":
        _fail("material family did not open conversion actions")
        return
    var converter: Button = (facilities.get("modal_actions") as VBoxContainer).find_child("ConvertRank_0", true, false) as Button
    if converter == null or not converter.is_visible_in_tree() or not viewport.has_point(converter.get_global_rect().get_center()):
        _fail("first conversion action is not in initial view")
        return
    await _tap_button(tabs.get_node("TabWarehouse") as Button)
    await process_frame
    if str(facilities.get("page")) != "inventory":
        _fail("warehouse tab did not open inventory")
        return
    facilities.call("_show_inventory", "materials")
    await process_frame
    var first_material: Button = (facilities.get("item_layer") as Control).find_child("MaterialIcon_scrap_low", true, false) as Button
    if first_material == null or (
            (first_material.get_node("ItemArt") as TextureRect).texture == null) or (
            not first_material.is_visible_in_tree() or (
            not viewport.has_point(first_material.get_global_rect().get_center()))):
        _fail("first warehouse material icon not visible")
        return
    await _tap_button(tabs.get_node("TabCraft") as Button)
    if str(facilities.get("page")) != "prototypes":
        _fail("catalog cannot be reopened from warehouse")
        return
    print("SERA_V518_MENU_VISIBILITY_RUNTIME_PASS")
    quit(0)

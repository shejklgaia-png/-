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
func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var viewport: Rect2 = Rect2(Vector2.ZERO, hub.get_viewport().get_visible_rect().size)
    var hud: Control = hub.get_node("BaseHUDLayer/BaseHUD") as Control
    var quick: HBoxContainer = hud.get_node("BaseQuickActions") as HBoxContainer
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    if hud.size.x < viewport.size.x - 1.0 or hud.size.y < viewport.size.y - 1.0:
        _fail("HUD size is not tied to actual viewport")
        return
    for id in ["QuickCraft", "QuickMaterials", "QuickWarehouse"]:
        var shortcut: Button = quick.get_node_or_null(id) as Button
        if not _visible_button(shortcut, viewport):
            _fail("base navigation is not visible/clickable: " + id)
            return
    (quick.get_node("QuickCraft") as Button).pressed.emit()
    await process_frame
    if str(facilities.get("page")) != "prototypes":
        _fail("craft shortcut must open actual seven-item catalog")
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
    var first: Button = actions.get_node("PrototypeIcon_H01/Choose_H01") as Button
    if not _visible_button(first, viewport):
        _fail("first equipment item cannot be selected on screen")
        return
    first.pressed.emit()
    await process_frame
    var craft: Button = (facilities.get("modal_actions") as VBoxContainer).get_node("CraftPrototype") as Button
    if not craft.is_visible_in_tree() or not viewport.has_point(craft.get_global_rect().get_center()):
        _fail("craft action is outside visible portrait dialog")
        return
    (tabs.get_node("TabMaterials") as Button).pressed.emit()
    await process_frame
    if str(facilities.get("page")) != "families":
        _fail("materials tab did not open material family choices")
        return
    var family: Button = (facilities.get("modal_actions") as VBoxContainer).get_node("FamilyChoice_scrap/Open_scrap") as Button
    if not _visible_button(family, viewport):
        _fail("first material family cannot be picked")
        return
    family.pressed.emit()
    await process_frame
    if str(facilities.get("page")) != "conversion":
        _fail("material family did not open conversion actions")
        return
    var converter: Button = (facilities.get("modal_actions") as VBoxContainer).get_node_or_null("ConvertRank_0") as Button
    if converter == null or not converter.is_visible_in_tree() or not viewport.has_point(converter.get_global_rect().get_center()):
        _fail("first conversion action is not in initial view")
        return
    (tabs.get_node("TabWarehouse") as Button).pressed.emit()
    await process_frame
    if str(facilities.get("page")) != "inventory":
        _fail("warehouse tab did not open inventory")
        return
    var first_material: TextureRect = (facilities.get("modal_actions") as VBoxContainer).get_node_or_null("MaterialIcon_scrap_low/Icon") as TextureRect
    if first_material == null or first_material.texture == null or (
            not first_material.is_visible_in_tree() or (
            not viewport.has_point(first_material.get_global_rect().get_center()))):
        _fail("first warehouse material icon not visible")
        return
    (tabs.get_node("TabCraft") as Button).pressed.emit()
    if str(facilities.get("page")) != "prototypes":
        _fail("catalog cannot be reopened from warehouse")
        return
    print("SERA_V518_MENU_VISIBILITY_RUNTIME_PASS")
    quit(0)

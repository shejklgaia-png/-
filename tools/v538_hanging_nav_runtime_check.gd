extends SceneTree
## v538: the actual live UI must use left-edge hanging tabs with readable English.
const TabSkin = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V538_HANGING_NAV_FAIL: " + why)
    quit(1)
func _check_tabs(fac: Node3D, selected: String, title: String) -> bool:
    var modal: Control = fac.get("modal") as Control
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    if tabs == null or tabs.get_parent() != modal or not tabs.is_visible_in_tree():
        _fail("navigation must be an always-visible screen overlay")
        return false
    if tabs.get_child_count() != 3 or absf(tabs.global_position.x - modal.global_position.x) > 1.0 or (
            absf(tabs.global_position.y - modal.global_position.y) > 1.0):
        _fail("three tabs must attach to the viewport upper-left edge")
        return false
    if tabs.get_global_rect().end.x > modal.get_global_rect().end.x + 1.0:
        _fail("English tabs spill outside the narrow viewport")
        return false
    var expected: Array[String] = ["EQUIPMENT", "REFINERY", "STORAGE"]
    var selected_count: int = 0
    for i in range(3):
        var button: Button = tabs.get_child(i) as Button
        if button == null or button.text != expected[i] or button.button_group == null:
            _fail("tab missing its exact English label or exclusive group")
            return false
        if button.button_pressed:
            selected_count += 1
        if button.button_pressed != (button.name == selected):
            _fail("wrong selected tab for " + title)
            return false
        if button.size.y < 60.0 or button.get_global_rect().end.x > (
                modal.get_global_rect().end.x + 1.0):
            _fail("hanging tab collapsed or overflowed")
            return false
        var style: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
        if style == null or style.texture == null:
            _fail("native tab lost the alpha-backed suspended frame")
            return false
        var serial: Label = button.get_node_or_null("TabSerial") as Label
        if serial == null or serial.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            _fail("terminal index must not intercept tapping")
            return false
    if selected_count != 1:
        _fail("more than one category is selected")
        return false
    var active: Button = tabs.get_node(selected) as Button
    var ordinary: Button = tabs.get_child(0) as Button
    if ordinary == active:
        ordinary = tabs.get_child(1) as Button
    if active.size.y < ordinary.size.y + 10.0:
        _fail("selected tab must protrude further down than its siblings")
        return false
    if (fac.get("hero_host") as SubViewportContainer).custom_minimum_size.y < (
            fac.get_viewport().get_visible_rect().size.y * 0.29):
        _fail("navigation stole the 3D scene's reserved height")
        return false
    return true

func _run() -> void:
    if TabSkin.hanging_tab_style("selected") == TabSkin.hanging_tab_style("normal"):
        _fail("selected and inactive tabs share the same artwork")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    if not _check_tabs(fac, "TabCraft", "craft"):
        return
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var original_id: int = tabs.get_instance_id()
    (tabs.get_node("TabMaterials") as Button).pressed.emit()
    await process_frame
    if not _check_tabs(fac, "TabMaterials", "refinery"):
        return
    (tabs.get_node("TabWarehouse") as Button).pressed.emit()
    await process_frame
    if not _check_tabs(fac, "TabWarehouse", "warehouse"):
        return
    (tabs.get_node("TabCraft") as Button).pressed.emit()
    await process_frame
    if not _check_tabs(fac, "TabCraft", "return"):
        return
    if (fac.get("section_tabs") as HBoxContainer).get_instance_id() != original_id:
        _fail("switching sections rebuilt the top-left tabs")
        return
    print("SERA_V538_HANGING_NAV_RUNTIME_PASS")
    quit(0)

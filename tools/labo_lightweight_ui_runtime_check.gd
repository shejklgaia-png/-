extends SceneTree
## Only page/button state changes. The v527 rendering, item nodes and save stay.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_LABO_LIGHTWEIGHT_UI_FAIL: " + why)
    quit(1)

func _selected(tabs: HBoxContainer) -> int:
    var count: int = 0
    for item in tabs.get_children():
        if item is Button and item.button_pressed:
            count += 1
    return count

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "LABO")
    var tabs: HBoxContainer = fac.get("section_tabs") as HBoxContainer
    var craft: Button = tabs.get_node("TabCraft") as Button
    var debug: Button = fac.get("diagnostic_button") as Button
    var readout: Label = fac.get("diagnostic_readout") as Label
    var title: Label = fac.get("modal_title") as Label
    if debug.visible or readout.visible or str(fac.get("page")) != "home":
        _fail("normal LABO home must have no diagnostic UI")
        return
    if _selected(tabs) != 0:
        _fail("LABO research home must not falsely select the craft tab")
        return
    var mouse := InputEventMouseButton.new()
    mouse.pressed = true
    mouse.button_index = MOUSE_BUTTON_LEFT
    for i in range(5):
        title.gui_input.emit(mouse)
    if not debug.visible or readout.visible:
        _fail("five header taps must reveal only the developer button")
        return
    debug.pressed.emit()
    if not readout.is_visible_in_tree():
        _fail("developer diagnostics cannot be opened")
        return
    for i in range(5):
        title.gui_input.emit(mouse)
    if debug.visible or readout.visible:
        _fail("developer mode did not hide all diagnostic UI")
        return
    fac.call("_switch_section", "craft")
    await process_frame
    if str(fac.get("page")) != "prototypes" or _selected(tabs) != 1 or not craft.button_pressed:
        _fail("craft section must show seven recipes and select its own tab")
        return
    var layer: Control = fac.get("item_layer") as Control
    if layer.find_child("PrototypeIcon_H01", true, false) == null:
        _fail("existing recipe grid was removed")
        return
    fac.call("_select_prototype", "H01")
    if not craft.button_pressed or (
            not (fac.get("confirmation_overlay") as Control).visible):
        _fail("craft confirmation should preserve the craft tab")
        return
    fac.call("navigate_back") # cancel confirmation without executing craft
    if (fac.get("confirmation_overlay") as Control).visible or (
            str(fac.get("page")) != "prototypes"):
        _fail("Back must dismiss confirmation and keep the recipe list")
        return
    fac.call("navigate_back")
    if str(fac.get("page")) != "home" or _selected(tabs) != 0:
        _fail("return to LABO home must clear the craft tab selection")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    if _selected(tabs) != 1 or not (tabs.get_node("TabMaterials") as Button).button_pressed:
        _fail("materials must select only their own tab")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    if _selected(tabs) != 1 or not (tabs.get_node("TabWarehouse") as Button).button_pressed:
        _fail("warehouse must select only its own tab")
        return
    print("SERA_LABO_LIGHTWEIGHT_UI_RUNTIME_PASS: hidden diagnostics, five-tap access, accurate tabs and native cards")
    quit(0)

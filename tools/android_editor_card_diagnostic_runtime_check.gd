extends SceneTree
## This test checks that a screen readout survives a normal card selection,
## reports real engine/atlas/grid status and does not alter item/save data.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_ANDROID_EDITOR_CARD_DIAG_FAIL: " + message)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    var diag_toggle: Button = fac.get("diagnostic_button") as Button
    var diag_label: Label = fac.get("diagnostic_readout") as Label
    if diag_toggle == null or diag_label == null or diag_label.visible:
        _fail("screen diagnostic control must exist and be collapsed by default")
        return
    diag_toggle.pressed.emit()
    await process_frame
    fac.call("_diag_update")
    if not diag_label.is_visible_in_tree():
        _fail("diagnostic readout is not on the visible menu")
        return
    var text_value: String = diag_label.text
    for marker in ["Godot", "stage: ", "slots: ", "atlas:", "viewport:", "created 7/7"]:
        if not text_value.contains(marker):
            _fail("diagnostic missing " + marker + ": " + text_value)
            return
    var cards: Control = fac.get("item_layer") as Control
    var first: Button = cards.find_child("PrototypeIcon_H01", true, false) as Button
    if first == null or not first.is_visible_in_tree():
        _fail("diagnostic modified normal craft card")
        return
    diag_toggle.pressed.emit()
    if diag_label.visible:
        _fail("diagnostic toggle must hide the readout again")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    diag_toggle.pressed.emit()
    fac.call("_diag_update")
    if not diag_label.text.contains("created 12/12"):
        _fail("material screen diagnostics did not track 12 cards")
        return
    diag_toggle.pressed.emit()
    fac.call("_switch_section", "warehouse")
    await process_frame
    diag_toggle.pressed.emit()
    fac.call("_diag_update")
    if not diag_label.text.contains("created 12/12"):
        _fail("warehouse diagnostic card count wrong")
        return
    print("SERA_ANDROID_EDITOR_CARD_DIAG_RUNTIME_PASS: live renderer/engine and counts in the actual menu")
    quit(0)

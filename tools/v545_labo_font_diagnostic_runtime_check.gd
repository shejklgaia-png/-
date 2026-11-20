extends SceneTree
## v545: real Godot font probing is explicit, on demand and non-destructive.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_V545_FONT_DIAGNOSTIC_FAIL: " + why)
    quit(1)
func _run() -> void:
    var scene: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var fac: Node3D = scene.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var hidden: Button = fac.get("font_diag_button") as Button
    if hidden == null or hidden.visible or fac.get("font_diag_overlay") != null:
        _fail("font diagnostic must remain invisible and unallocated by default")
        return
    # The same five-tap gesture that unlocks the existing UI diagnostics.
    for n in range(5):
        var tap := InputEventScreenTouch.new()
        tap.pressed = true
        fac.call("_on_modal_title_input", tap)
    if not hidden.visible:
        _fail("five-tap gesture did not reveal FONT diagnostic")
        return
    hidden.pressed.emit()
    await process_frame
    await process_frame
    var panel: Control = fac.get("font_diag_overlay") as Control
    var output: Label = fac.get("font_diag_report") as Label
    if panel == null or not panel.is_visible_in_tree() or output == null:
        _fail("font diagnostic panel could not be opened")
        return
    var report: String = output.text
    for token in ["SERA FONT DIAG v547", "Platform:", "Locale:", "Display:",
            "System font families:", "embedded:", "JAPANESE FONT: PASS",
            "available: RAW=", "load route: RAW_BYTES",
            "TextServer primary RID:", "glyph A/JPN/kanji/kana:",
            "JP TITLE", "LATIN NAV", "MONO ID"]:
        if not report.contains(token):
            _fail("diagnostic report missing " + token)
            return
    var samples: Control = panel.find_child("FontDiagRows", true, false) as Control
    if samples == null or samples.find_child(
            "FontSample_JP_TITLE", true, false) == null or (
            samples.find_child("FontSample_MONO_ID", true, false) == null):
        _fail("side-by-side Japanese, Latin and mono samples disappeared")
        return
    var sample_count: int = 0
    for item: Node in samples.get_children():
        if item.name.begins_with("FontSample_"):
            sample_count += 1
    if sample_count != 6:
        _fail("expected six on-device typography sample rows")
        return
    var refresh: Button = panel.find_child("FontDiagRefresh", true, false) as Button
    var copy: Button = panel.find_child("FontDiagCopy", true, false) as Button
    var close: Button = panel.find_child("FontDiagClose", true, false) as Button
    if refresh == null or copy == null or close == null:
        _fail("font refresh/copy/close controls missing")
        return
    refresh.pressed.emit()
    if output.text.is_empty():
        _fail("RESCAN cleared the output")
        return
    close.pressed.emit()
    if panel.visible:
        _fail("CLOSE did not dismiss font diagnostics")
        return
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if card == null or not card.is_visible_in_tree():
        _fail("font inspection modified the underlying equipment controls")
        return
    hidden.pressed.emit()
    if not panel.visible:
        _fail("font diagnostics could not be reopened")
        return
    fac.call("_font_diag_close")
    print("SERA_V545_FONT_DIAGNOSTIC_RUNTIME_PASS")
    quit(0)

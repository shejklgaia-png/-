extends SceneTree
## Headless smoke contract for the standalone IRIS material editor.
## A real Android viewport/frame inspection remains mandatory.
const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("IRIS_MATERIAL_EDITOR_RUNTIME_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var container := Control.new()
    container.size = Vector2(720, 1280)
    root.add_child(container)
    var preview: Control = PartViewer.new()
    preview.size = container.size
    container.add_child(preview)
    await process_frame

    preview.set("enable_nexus_iris_id_contour", true)
    preview.set("current_blueprint", "H02")
    var toggle: Button = preview.get("_material_toggle") as Button
    var panel: Panel = preview.get("_material_panel") as Panel
    if toggle == null or panel == null or toggle.visible or panel.visible:
        _fail("material controls must be hidden in normal-sized preview")
        return
    preview.call("set_fullscreen_state", true)
    if not toggle.visible or panel.visible:
        _fail("fullscreen should expose the toggle but not auto-open controls")
        return
    preview.call("_toggle_material_editor")
    if not panel.visible:
        _fail("material adjustment panel must open on demand")
        return
    var rows: Node = panel.get_node_or_null("IrisMaterialAdjustmentRows")
    if rows == null:
        _fail("no material controls created")
        return
    for i in range(4):
        if rows.get_node_or_null("IrisMaterialRow_%d" % i) == null:
            _fail("missing material %d" % i)
            return
    var settings: Array = preview.get("_iris_material_values")
    if settings.size() != 4 or int(settings[0]["steps"]) != 4:
        _fail("four typed material settings required")
        return
    preview.call("_adjust_iris_material", 0, "steps", 1)
    preview.call("_adjust_iris_material", 0, "threshold", 1)
    settings = preview.get("_iris_material_values")
    if int(settings[0]["steps"]) != 5 or not is_equal_approx(
            float(settings[0]["threshold"]), 0.60):
        _fail("armor changes must be independent and quantized")
        return
    if int(settings[1]["steps"]) != 4 or int(settings[2]["steps"]) != 0:
        _fail("other material presets unexpectedly changed")
        return
    preview.call("_toggle_iris_emission")
    if not bool(preview.get("_lens_lit")):
        _fail("cyan light toggle failed")
        return
    preview.call("set_fullscreen_state", false)
    if toggle.visible or panel.visible:
        _fail("material controls remain visible after shrink")
        return
    print("IRIS_MATERIAL_EDITOR_RUNTIME_PASS")
    quit(0)

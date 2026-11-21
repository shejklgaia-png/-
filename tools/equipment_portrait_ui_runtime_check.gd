extends SceneTree
## Exercise real Godot types/UI, no synthetic textures or profile destruction.
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const Mark = preload("res://scripts/sera_rotatable_mark.gd")
const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")
const WarehousePopup = preload("res://scripts/sera_warehouse_detail_popup.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_EQUIPMENT_PORTRAIT_UI_FAIL: " + message)
    quit(1)

func _run() -> void:
    if Catalog.ORDER.size() != 19:
        _fail("Nineteen equipment IDs must remain stable")
        return
    var cue := Mark.new()
    root.add_child(cue)
    cue.size = Vector2(26, 26)
    if cue.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        _fail("Rotation cue must never intercept a touch")
        return
    var viewer := PartViewer.new()
    root.add_child(viewer)
    viewer.size = Vector2(280, 280)
    await process_frame
    viewer.call("show_part", "B02")
    for i in range(20):
        await process_frame
        if viewer.get("ready_for_commands"):
            break
    if not bool(viewer.get("ready_for_commands")):
        _fail("Lazy real SeraRig preview never became ready")
        return
    var scene: Node3D = viewer.get("preview_scene")
    if scene == null or not bool(scene.get("ready_for_commands")):
        _fail("Viewer is not using the live equipment rig")
        return
    if str(scene.get("active_full_body_pose")) != "NEXUS_pose":
        _fail("Isolated ICON must use the authored NEXUS stand")
        return
    viewer.call("feed_touch", 0, true, Vector2(35, 42))
    viewer.call("feed_drag", 0, Vector2(85, 58))
    viewer.call("feed_touch", 0, false, Vector2(85, 58))
    if is_equal_approx(float(scene.get("camera_yaw")), -34.0):
        _fail("Drag must turn the actual part in 3D")
        return
    viewer.call("set_preview_active", false)
    var viewport: SubViewport = viewer.get("render_viewport") as SubViewport
    if viewport == null or viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
        _fail("Hidden viewer must not continue rendering")
        return
    var popup := WarehousePopup.new()
    root.add_child(popup)
    await process_frame
    popup.open_item({"uid":"H01-0001", "blueprint":"H01",
        "favorite":false,"junk":false,"affixes":[]})
    await process_frame
    if not popup.is_open() or popup.find_child("DetailName",true,false) == null or (
            popup.find_child("WarehouseDetailStatsScroll",true,false) == null) or (
            popup.find_child("WarehouseDetail3D",true,false) == null):
        _fail("Warehouse modal identity/preview/stat layout incomplete")
        return
    popup.close_item()
    if popup.is_open():
        _fail("Warehouse detail close did not return to list")
        return
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.call("_focus_arrived", "CUSTOMIZE")
    await process_frame
    var grid: GridContainer = nexus.get("customize_stats_grid") as GridContainer
    var stats: ScrollContainer = nexus.get("customize_stats_scroll") as ScrollContainer
    if grid == null or stats == null or stats.get_parent() != nexus.get("hud"):
        _fail("Aggregate stats must span the top of screen")
        return
    if grid.columns != 3:
        _fail("720px portrait uses three columns for aggregate stats")
        return
    nexus.call("_show_customization_part_picker", "head")
    await process_frame
    var picker: Control = nexus.get("customize_part_picker") as Control
    var part_grid: GridContainer = nexus.get("customize_part_grid") as GridContainer
    if picker == null or not picker.visible or part_grid == null or (
            part_grid.columns != 3):
        _fail("Three-column scroll picker not visible")
        return
    nexus.call("_close_customization_part_picker")
    if picker.visible:
        _fail("Picker should close without leaving CUSTOMIZE")
        return
    print("SERA_EQUIPMENT_PORTRAIT_UI_RUNTIME_PASS")
    quit(0)

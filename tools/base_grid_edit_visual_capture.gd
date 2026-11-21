extends SceneTree
## Actual Godot GL 720x1280 screenshot of the visual-only GRID edit shell.
const Board = preload("res://scripts/sera_base_power_board.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        push_error("SERA_GRID_EDIT_CAPTURE_FAIL: no BASE scene")
        quit(1)
        return
    var hub: Node3D = scene.instantiate() as Node3D
    root.add_child(hub)
    for i in range(6):
        await process_frame
    var camera: Camera3D = hub.get_node_or_null(
        "BaseOverheadCamera") as Camera3D
    var shell: Control = hub.get_node_or_null(
        "BaseHUDLayer/BaseHUD/BaseGridPresentation") as Control
    if camera == null or shell == null:
        push_error("SERA_GRID_EDIT_CAPTURE_FAIL: no camera or GRID UI")
        quit(1)
        return
    hub.call("_enter_power_board")
    var travel: Tween = hub.get("power_camera_tween") as Tween
    if travel != null:
        travel.kill()
    hub.set("power_transition_busy", false)
    hub.call("_grid_select_cell", Vector2i(3, 3))
    hub.call("_enter_grid_placement")
    travel = hub.get("power_camera_tween") as Tween
    if travel != null:
        travel.kill()
    hub.set("power_transition_busy", false)
    camera.position = Board.board_focus() + Vector3(0, 34.0, 0.01)
    camera.rotation = Vector3(-PI * 0.5, 0, 0)
    camera.size = float(hub.call("_grid_edit_ortho_size"))
    shell.call("set_grid", true, false)
    shell.call("set_edit", true, false)
    shell.call("_choose_node", "G")
    for i in range(4):
        await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    var directory: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if screenshot == null or screenshot.is_empty() or directory.is_empty():
        push_error("SERA_GRID_EDIT_CAPTURE_FAIL: buffer/output unavailable")
        quit(1)
        return
    var out: String = directory.path_join("sera_base_grid_edit_shell.png")
    var result: Error = screenshot.save_png(out)
    if result != OK:
        push_error("SERA_GRID_EDIT_CAPTURE_FAIL: save %d" % result)
        quit(1)
        return
    print("SERA_GRID_EDIT_CAPTURE_PASS: ", screenshot.get_size())
    quit(0)

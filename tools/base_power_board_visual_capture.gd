extends SceneTree
## Real Godot/GL screenshot of the distant 8x8 power stage.
## Delivers a compact visual check for the Android portrait composition.
const Board = preload("res://scripts/sera_base_power_board.gd")
const HUB_CAMERA_POSITION = Vector3(21.0, 23.0, 25.0)
const HUB_CAMERA_TARGET = Vector3(0.0, 0.0, -2.2)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://scenes/base_exploration.tscn")
    if source == null:
        push_error("SERA_POWER_BOARD_CAPTURE_FAIL: no BASE scene")
        quit(1)
        return
    var hub: Node3D = source.instantiate() as Node3D
    root.add_child(hub)
    for i in range(5):
        await process_frame
    var camera: Camera3D = hub.get_node_or_null("BaseOverheadCamera") as Camera3D
    var grid: Node3D = hub.get_node_or_null(
        "PowerPuzzleZone/PowerGrid8x8") as Node3D
    if camera == null or grid == null:
        push_error("SERA_POWER_BOARD_CAPTURE_FAIL: camera/grid absent")
        quit(1)
        return
    hub.call("_enter_power_board")
    var camera_tween: Tween = hub.get("power_camera_tween") as Tween
    if camera_tween != null:
        camera_tween.kill()
    camera.position = HUB_CAMERA_POSITION + Board.board_focus() - HUB_CAMERA_TARGET
    camera.size = float(hub.call("_power_view_ortho_size"))
    for i in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    if screenshot == null or screenshot.is_empty():
        push_error("SERA_POWER_BOARD_CAPTURE_FAIL: framebuffer unavailable")
        quit(1)
        return
    var directory: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if directory.is_empty():
        push_error("SERA_POWER_BOARD_CAPTURE_FAIL: no output directory")
        quit(1)
        return
    var target: String = directory.path_join("sera_base_power_grid.png")
    var err: Error = screenshot.save_png(target)
    if err != OK:
        push_error("SERA_POWER_BOARD_CAPTURE_FAIL: save %d" % err)
        quit(1)
        return
    print("SERA_POWER_BOARD_CAPTURE_PASS ", screenshot.get_size())
    quit(0)

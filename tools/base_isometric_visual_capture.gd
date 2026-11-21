extends SceneTree
## A real 720x1280 GL render is uploaded as a CI artifact for visual framing review.
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("SERA_BASE_ORTHO_SCREENSHOT_FAIL: framebuffer unavailable")
        quit(1)
        return
    var dir: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if dir.is_empty():
        push_error("SERA_BASE_ORTHO_SCREENSHOT_FAIL: missing output folder")
        quit(1)
        return
    var err: Error = image.save_png(dir.path_join("sera_base_orthographic.png"))
    if err != OK:
        push_error("SERA_BASE_ORTHO_SCREENSHOT_FAIL: save_png %d" % err)
        quit(1)
        return
    print("SERA_BASE_ORTHO_SCREENSHOT_PASS: " + str(image.get_size()))
    quit(0)

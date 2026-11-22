extends SceneTree
## Screen capture of the actual game BASE. Never use a decorative preview camera.
## Wait for the asynchronous 3D BASE construction AND HUD to finish first.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_ORTHO_SCREENSHOT_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(90):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null and (
            hub.get_node_or_null("BaseStartupOverlay") == null):
            break
    if hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") == null or (
        hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") == null or
        hub.get_node_or_null("BaseStartupOverlay") != null):
        _fail("gameplay BASE was not completely built before capture")
        return
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
        absf(camera.size - 38.0) > 0.001 or
        camera.position.distance_to(Vector3(21.0, 19.5, 25.0)) > 0.001 or
        bool(hub.get("power_view_active"))):
        _fail("capture must use default live BASE camera, not GRID/preview")
        return
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("framebuffer unavailable")
        return
    var dir: String = OS.get_environment("SERA_UI_RENDER_DIR")
    if dir.is_empty():
        _fail("missing output folder")
        return
    var err: Error = image.save_png(dir.path_join("sera_base_orthographic.png"))
    if err != OK:
        _fail("save_png %d" % err)
        return
    # A compact, explicit CI-log thumbnail permits actual-image review in
    # text-only GitHub connector clients; the original PNG remains unmodified.
    if OS.get_environment("SERA_BASE_PREVIEW_LOG") == "1":
        var thumbnail: Image = image.duplicate()
        thumbnail.resize(270, 480, Image.INTERPOLATE_LANCZOS)
        var jpeg: PackedByteArray = thumbnail.save_jpg_to_buffer(0.64)
        if jpeg.is_empty():
            _fail("base preview JPEG encode failed")
            return
        print("SERA_BASE_PREVIEW_JPEG_B64=" + Marshalls.raw_to_base64(jpeg))
    print("SERA_BASE_ORTHO_SCREENSHOT_PASS true gameplay angle: " +
        str(image.get_size()))
    quit(0)

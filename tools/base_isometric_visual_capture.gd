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
        thumbnail.resize(540, 960, Image.INTERPOLATE_LANCZOS)
        var jpeg: PackedByteArray = thumbnail.save_jpg_to_buffer(0.69)
        if jpeg.is_empty():
            _fail("base preview JPEG encode failed")
            return
        print("SERA_BASE_PREVIEW_JPEG_B64=" + Marshalls.raw_to_base64(jpeg))
    # Compare real rendered pixels with only the 6px inverted hull removed.
    # Node presence and shader uniforms cannot prove an Android-visible line.
    # Never alter the actual 720x1280 BASE camera, materials or timestamps.
    if OS.get_environment("SERA_BASE_ASSERT_OUTLINES") == "1":
        var outline_batches: Array[MultiMeshInstance3D] = []
        var facility_paths: Array[String] = [
            "NEXUSBuilding/NexusArchitecture",
            "BaseFacilities/LABO/IndustrialModel",
            "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel",
            "BaseFacilities/SMELTER/IndustrialModel",
            "BaseFacilities/RECYCLER/IndustrialModel",
            "BaseFacilities/GENERATOR/IndustrialModel",
            "BaseFacilities/STORAGE/IndustrialModel",
            "BaseFacilities/BUILD_TERMINAL/IndustrialModel",
        ]
        for facility_path in facility_paths:
            var facility: Node3D = hub.get_node_or_null(facility_path) as Node3D
            if facility == null:
                _fail("missing facility for visible-outline comparison")
                return
            var facility_ink_count: int = 0
            for piece in facility.get_children():
                if piece is MultiMeshInstance3D and (
                        str(piece.name).begins_with("ArchitecturalEdgeInk_")):
                    outline_batches.append(piece as MultiMeshInstance3D)
                    facility_ink_count += 1
            if facility_ink_count == 0:
                _fail("facility without 6px silhouette batches: " + facility_path)
                return
        for batch in outline_batches:
            batch.visible = false
        await process_frame
        await RenderingServer.frame_post_draw
        var no_outline: Image = root.get_texture().get_image()
        for batch in outline_batches:
            batch.visible = true
        if no_outline == null or no_outline.is_empty() or (
                no_outline.get_size() != image.get_size()):
            _fail("reference screenshot without silhouettes unavailable")
            return
        if no_outline.save_png(dir.path_join("sera_base_without_6px.png")) != OK:
            _fail("could not save before/after visual comparison")
            return
        var visible_stroke_pixels: int = 0
        # Subsample the genuine GL Compatibility framebuffer, excluding
        # navigation HUD and Android letterboxing. Compare only strong
        # darkening from a black line, not changes in a moving smoke plume.
        for py in range(130, mini(image.get_height() - 90, 1190), 2):
            for px in range(10, image.get_width() - 10, 2):
                var with_ink: Color = image.get_pixel(px, py)
                var without_ink: Color = no_outline.get_pixel(px, py)
                var darkening: float = (
                    without_ink.r - with_ink.r +
                    without_ink.g - with_ink.g +
                    without_ink.b - with_ink.b)
                if (with_ink.r < 0.13 and with_ink.g < 0.13 and
                        with_ink.b < 0.13 and darkening > 0.16):
                    visible_stroke_pixels += 1
        if visible_stroke_pixels < 50:
            _fail("black 6px outlines are present in nodes but invisible on screen: " +
                str(visible_stroke_pixels) + " darkened pixels")
            return
        print("SERA_BASE_VISIBLE_6PX_PIXELS_PASS count=" +
            str(visible_stroke_pixels))
        await process_frame
    # Optional second true-gameplay frame: same camera / scene after real
    # _process-driven machine animation advances for about a second.
    if OS.get_environment("SERA_BASE_ANIMATION_CAPTURE") == "1":
        for _frame in range(48):
            await process_frame
        await RenderingServer.frame_post_draw
        var animated: Image = root.get_texture().get_image()
        if animated == null or animated.is_empty() or (
                animated.save_png(dir.path_join("sera_base_animated.png")) != OK):
            _fail("real animated BASE frame capture failed")
            return
        print("SERA_BASE_ANIMATED_SCREENSHOT_PASS true gameplay frame")
    print("SERA_BASE_ORTHO_SCREENSHOT_PASS true gameplay angle: " +
        str(image.get_size()))
    quit(0)

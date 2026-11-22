extends SceneTree
## Actual Godot control instantiate, monotonic stage values and deterministic 5s demo.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_LOADING_CONSOLE_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var source: Script = load("res://scripts/sera_loading_console.gd") as Script
    if source == null or not source.can_instantiate():
        _fail("console script unavailable")
        return
    var screen: Control = source.new() as Control
    if screen == null:
        _fail("not a Control")
        return
    root.add_child(screen)
    screen.size = Vector2(720.0, 1280.0)
    screen.set_process(false)
    # Only the terminal's offscreen target is half resolution.
    var reduced_view: SubViewport = screen.get_node_or_null(
        "TerminalLowResViewport") as SubViewport
    var display: TextureRect = screen.get_node_or_null(
        "TerminalLowResOutput") as TextureRect
    if reduced_view == null or display == null:
        _fail("missing dedicated low-resolution terminal target")
        return
    if reduced_view.size != Vector2i(360, 640):
        _fail("720x1280 terminal must render internally at 360x640")
        return
    if display.texture != reduced_view.get_texture():
        _fail("terminal display is not presenting reduced-resolution texture")
        return
    if display.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
        _fail("terminal texture was blurred by linear interpolation")
        return
    var source_canvas: Control = reduced_view.get_node_or_null(
        "TerminalLowResCanvas") as Control
    if source_canvas == null or source_canvas.scale != Vector2(0.5, 0.5):
        _fail("offscreen terminal retains an incorrect source scale")
        return
    screen.size = Vector2(450.0, 800.0)
    if reduced_view.size != Vector2i(225, 400):
        _fail("offscreen viewport did not follow small-screen resize")
        return
    if source_canvas.get("pixel_font_atlas") == null:
        _fail("loading terminal glyph atlas was not created")
        return
    if int(source_canvas.call("_pixel_cell_pixels", 50)) != 3:
        _fail("50 percent large readout must use 3x bitmap pixels")
        return
    if float(source_canvas.call("_pixel_text_width", "100%", 50)) <= 0.0:
        _fail("bitmap glyph measurement is invalid")
        return
    # Preview variants rasterize the same original layout at real lower sizes.
    screen.call("set_render_scale", 0.375)
    if not is_equal_approx(float(source_canvas.get("console_render_scale")), 0.375):
        _fail("bitmap glyph source did not receive 37.5 percent raster scale")
        return
    if int(source_canvas.call("_pixel_cell_pixels", 50)) != 2:
        _fail("37.5 percent large readout must use 2x bitmap pixels")
        return
    if reduced_view.size != Vector2i(169, 300):
        _fail("37.5 percent narrow terminal is not 169x300 (ceil)")
        return
    if source_canvas.scale != Vector2(0.375, 0.375):
        _fail("37.5 percent preset did not scale the source canvas")
        return
    screen.size = Vector2(720.0, 1280.0)
    if reduced_view.size != Vector2i(270, 480):
        _fail("37.5 percent portrait terminal is not 270x480")
        return
    screen.call("set_render_scale", 0.25)
    if not is_equal_approx(float(source_canvas.get("console_render_scale")), 0.25):
        _fail("bitmap glyph source did not receive 25 percent raster scale")
        return
    if int(source_canvas.call("_pixel_cell_pixels", 50)) != 2:
        _fail("25 percent large readout must use 2x bitmap pixels")
        return
    if reduced_view.size != Vector2i(180, 320):
        _fail("25 percent portrait terminal is not 180x320")
        return
    if source_canvas.scale != Vector2(0.25, 0.25):
        _fail("25 percent preset did not scale the source canvas")
        return
    screen.size = Vector2(450.0, 800.0)
    if reduced_view.size != Vector2i(113, 200):
        _fail("25 percent narrow terminal is not 113x200 (ceil)")
        return
    screen.call("set_render_scale", 0.5)
    if reduced_view.size != Vector2i(225, 400):
        _fail("returning to existing 50 percent preset did not restore viewport")
        return
    screen.size = Vector2(720.0, 1280.0)
    if reduced_view.size != Vector2i(360, 640):
        _fail("real loading 50 percent render size was not restored")
        return
    screen.call("set_stage", "CORE / ONLINE", 18)
    if int(screen.get("percent")) != 18:
        _fail("real milestone not committed")
        return
    if int(source_canvas.get("percent")) != 18:
        _fail("offscreen renderer did not receive actual loading progress")
        return
    screen.call("set_stage", "STALE", 10)
    if int(screen.get("percent")) != 18:
        _fail("real progress rolled backward")
        return
    # Node lights represent completed BASE stages, never elapsed animation time.
    if not bool(screen.call("_system_node_online", "CORE")):
        _fail("CORE should be online at real 18 percent")
        return
    if bool(screen.call("_system_node_online", "NEXUS")):
        _fail("NEXUS lit before its 33 percent milestone")
        return
    screen.call("set_stage", "NEXUS / COMMAND LINK ONLINE", 33)
    if not bool(screen.call("_system_node_online", "NEXUS")):
        _fail("NEXUS did not light at stage completion")
        return
    if bool(screen.call("_system_node_online", "GRID")):
        _fail("GRID lit before 67 percent")
        return
    screen.call("set_stage", "GRID / ADDRESS MAP VERIFIED", 67)
    if not bool(screen.call("_system_node_online", "GRID")):
        _fail("GRID did not light at stage completion")
        return
    if bool(screen.call("_system_node_online", "OS")):
        _fail("OS lit before HUD 99 percent")
        return
    var bounds: Rect2 = screen.call("_system_visual_bounds", 720.0, 1280.0)
    if bounds.position.y < 108.0 or bounds.end.y > 770.0:
        _fail("CORE illustration collides with header/log region on portrait")
        return
    var narrow_bounds: Rect2 = screen.call("_system_visual_bounds", 450.0, 800.0)
    if narrow_bounds.position.y < 108.0 or narrow_bounds.end.y > 535.0:
        _fail("CORE illustration overflows narrow portrait terminal")
        return
    var live_percent: int = int(screen.get("percent"))
    screen.call("_process", 0.5)
    if float(screen.get("anim_time")) < 0.49 or int(screen.get("percent")) != live_percent:
        _fail("decorative animation must advance without faking real load progress")
        return
    screen.call("start_preview")
    screen.set_process(false)
    screen.call("_process", 2.5)
    if int(screen.get("percent")) != 50:
        _fail("2.5 sec did not produce exactly 50 steps")
        return
    var history_at_half: Array = screen.get("history")
    if history_at_half.size() < 12:
        _fail("scrolling log did not update with each progress unit")
        return
    screen.call("_process", 2.5)
    if int(screen.get("percent")) != 100:
        _fail("5 sec did not produce exactly 100 steps")
        return
    if bool(screen.get("preview_running")):
        _fail("completed demo is still advancing")
        return
    await process_frame
    print("SERA_LOADING_CONSOLE_RUNTIME_PASS")
    quit(0)

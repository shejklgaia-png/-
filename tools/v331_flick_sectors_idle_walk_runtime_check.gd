extends SceneTree
## Real animation/sample/CanvasItem logic, never a mocked clip conversion.
const OVERLAY = preload("res://scripts/touch_overlay.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("V331_FLICK_WALK_FAILED: " + reason)
    quit(1)
func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var touch: Control = game.get("touch_ui")
    if rig == null or touch == null or not bool(rig.get("loading_ok")):
        _fail("real SERA rig/UI unavailable")
        return
    touch.call("show_drag", Vector2(400.0, 900.0), Vector2(420.0, 900.0), 157.5)
    touch.call("set_flick_sector_forward", Vector2.RIGHT, 0.0, true)
    if (touch.call("flick_sector_direction", 0) as Vector2).distance_to(Vector2.RIGHT) > 0.0001:
        _fail("red front ring is not projected RIGHT")
        return
    if (touch.call("flick_sector_direction", 1) as Vector2).distance_to(Vector2.DOWN) > 0.0001:
        _fail("right yellow sector failed to rotate")
        return
    if (touch.call("flick_sector_direction", 3) as Vector2).distance_to(Vector2.UP) > 0.0001:
        _fail("left yellow sector failed to rotate")
        return
    touch.call("set_flick_sector_forward", Vector2.UP, 1.0/60.0, false)
    var partial: Vector2 = touch.get("flick_sector_forward")
    if partial.distance_to(Vector2.UP) < 0.001 or partial.distance_to(Vector2.RIGHT) < 0.001:
        _fail("continuous controller rotation did not interpolate")
        return
    touch.call("set_flick_sector_forward", Vector2.UP, 1.0/60.0, true)
    if (touch.get("flick_sector_forward") as Vector2).distance_to(Vector2.UP) > 0.0001:
        _fail("frozen combo input angle is not exact")
        return
    # Drawing is exercised by the CanvasItem's regular _draw callback;
    # calling draw_colored_polygon outside _draw is invalid in Godot.
    touch.call("hide_drag")

    rig.call("set_moving", false)
    if str(rig.get("current_clip")) != "Wait_motion":
        _fail("setup is not idle")
        return
    rig.call("set_moving", true, false, Vector2(0.0, 1.0), false)
    if not bool(rig.get("wait_to_run_landing_active")) \
            or str(rig.get("current_clip")) != "Jump" \
            or bool(rig.get("jump_playback")):
        _fail("WAIT did not immediately enter nonblocking landing")
        return
    if float(rig.get("blend_duration")) != 0.0 \
            or float(rig.get("blending_for")) < 0.99:
        _fail("landing ENTRY uses interpolation")
        return
    rig.call("_process", 0.10)
    var elapsed: float = float(rig.get("clip_time"))
    if absf(elapsed - 0.4375) > 0.001:
        _fail("0.2s landing did not play source keys halfway: " + str(elapsed))
        return
    rig.call("set_moving", true, false, Vector2.RIGHT, false)
    if str(rig.get("current_clip")) != "Jump":
        _fail("continued RUN input restarted landing")
        return
    rig.call("_process", 0.10)
    if str(rig.get("current_clip")) != "run_front_original" \
            or bool(rig.get("wait_to_run_landing_active")):
        _fail("last landing key did not complete before RUN exit")
        return
    if absf(float(rig.get("blend_duration")) - 0.11) > 0.0001:
        _fail("RUN EXIT blend is not active")
        return
    rig.call("_process", 0.055)
    if absf(float(rig.get("blending_for")) - 0.055) > 0.001:
        _fail("smooth RUN exit did not progress")
        return
    print("PASS v331 4 rotated sector colors and WAIT->0.2s Jump landing->blended RUN")
    game.queue_free()
    await process_frame
    quit(0)

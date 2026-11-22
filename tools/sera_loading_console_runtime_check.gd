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
    screen.call("set_stage", "CORE / ONLINE", 18)
    if int(screen.get("percent")) != 18:
        _fail("real milestone not committed")
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

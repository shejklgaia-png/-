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

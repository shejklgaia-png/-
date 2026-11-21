extends SceneTree
## Verify Godot compiles the actual procedural sweep and loops without assets.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_LOADING_SWEEP_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var resource: Resource = load("res://scripts/sera_loading_sweep.gd")
    if not (resource is Script) or not (resource as Script).can_instantiate():
        _fail("loading sweep script does not compile")
        return
    var sweep: Control = (resource as Script).new() as Control
    if sweep == null:
        _fail("loading sweep cannot instantiate as Control")
        return
    sweep.size = Vector2(720.0, 1280.0)
    root.add_child(sweep)
    sweep.set_process(false)
    await process_frame
    var start: float = float(sweep.get("phase"))
    sweep.call("_process", 0.39)
    var midway: float = float(sweep.get("phase"))
    if absf(midway - start - 0.39) > 0.015:
        _fail("sweep does not advance at high-tempo speed")
        return
    sweep.call("_process", 0.78)
    var looped: float = float(sweep.get("phase"))
    if absf(looped - midway) > 0.015:
        _fail("sweep does not wrap without a pause or jump in timing")
        return
    sweep.queue_redraw()
    await process_frame
    print("SERA_BASE_LOADING_SWEEP_RUNTIME_PASS")
    quit(0)

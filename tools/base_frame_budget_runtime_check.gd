extends SceneTree
## BASE uses the engine's actual FPS limiter, not alternate-frame viewport skips.
const Budget = preload("res://scripts/sera_base_frame_budget.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var budget = Budget.new()
    var original_max: int = Engine.max_fps
    var original_physics: int = Engine.physics_ticks_per_second
    var original_input: bool = Input.use_accumulated_input
    var original_time_scale: float = Engine.time_scale
    var viewport_rid: RID = root.get_viewport_rid()
    var original_mode: int = RenderingServer.viewport_get_update_mode(viewport_rid)

    budget.start(root)
    assert(Engine.max_fps == 30, "BASE should truly run at up to 30 fps")
    assert(Engine.physics_ticks_per_second == 60)
    assert(not Input.use_accumulated_input)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)

    # Repeated entry is harmless; zoom-in and the editing view are 60 fps.
    budget.start(root)
    assert(Engine.max_fps == 30)
    budget.set_grid_zoomed(true)
    assert(Engine.max_fps == 60)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)
    budget.set_grid_zoomed(true)
    assert(Engine.max_fps == 60)

    # Zoom-out callback restores ordinary BASE while preserving elapsed time.
    budget.set_grid_zoomed(false)
    assert(Engine.max_fps == 30)
    assert(Engine.physics_ticks_per_second == 60)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)

    budget.stop()
    assert(Engine.max_fps == original_max)
    assert(Engine.physics_ticks_per_second == original_physics)
    assert(Input.use_accumulated_input == original_input)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)
    budget.stop()
    print("BASE_FRAME_BUDGET_RUNTIME_PASS")
    quit(0)

extends SceneTree
## Scoped 30 Hz render / 60 Hz main loop and physics policy check, no full BASE needed.
const Budget = preload("res://scripts/sera_base_frame_budget.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var budget = Budget.new()
    var original_max: int = Engine.max_fps
    var original_physics: int = Engine.physics_ticks_per_second
    var original_input: bool = Input.use_accumulated_input
    var viewport_rid: RID = root.get_viewport_rid()
    var original_mode = RenderingServer.viewport_get_update_mode(viewport_rid)

    budget.start(root)
    assert(Engine.max_fps == 60)
    assert(Engine.physics_ticks_per_second == 60)
    assert(not Input.use_accumulated_input)

    # At 60 logic frames/s, render every second frame (30 visual frames/s).
    budget.advance(1.0 / 60.0)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_ONCE)
    budget.advance(1.0 / 60.0)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_DISABLED)
    budget.advance(1.0 / 60.0)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_ONCE)

    budget.set_grid_zoomed(true)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_ALWAYS)
    budget.advance(1.0 / 60.0)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_ALWAYS)
    budget.set_grid_zoomed(false)
    budget.advance(1.0 / 60.0)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == RenderingServer.VIEWPORT_UPDATE_ONCE)

    budget.stop()
    assert(Engine.max_fps == original_max)
    assert(Engine.physics_ticks_per_second == original_physics)
    assert(Input.use_accumulated_input == original_input)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)
    print("BASE_FRAME_BUDGET_RUNTIME_PASS")
    quit(0)

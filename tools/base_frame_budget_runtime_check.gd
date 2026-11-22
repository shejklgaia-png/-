extends SceneTree
## Isolated BASE FPS cap test; never touch a player's graphics settings.
const Budget = preload("res://scripts/sera_base_frame_budget.gd")
const Settings = preload("res://scripts/sera_frame_rate_settings.gd")
const TEST_PATH: String = "user://sera_base_frame_budget_ci.cfg"

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
    var path: String = ProjectSettings.globalize_path(TEST_PATH)
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(path)

    # Default settings emulate existing BASE 30 and edit GRID 60 contract.
    budget.start(root, TEST_PATH)
    assert(Engine.max_fps == 30)
    assert(Engine.physics_ticks_per_second == 60)
    assert(not Input.use_accumulated_input)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)
    budget.set_grid_zoomed(true)
    assert(Engine.max_fps == 60)
    budget.set_grid_zoomed(false)
    assert(Engine.max_fps == 30)
    budget.stop()

    # Personalized limits are read independently and never double game speed.
    assert(Settings.set_limit("base_nexus", 20, TEST_PATH))
    assert(Settings.set_limit("grid", 40, TEST_PATH))
    budget.start(root, TEST_PATH)
    assert(Engine.max_fps == 20)
    budget.set_grid_zoomed(true)
    assert(Engine.max_fps == 40)
    budget.set_grid_zoomed(false)
    assert(Engine.max_fps == 20)
    budget.stop()

    assert(Engine.max_fps == original_max)
    assert(Engine.physics_ticks_per_second == original_physics)
    assert(Input.use_accumulated_input == original_input)
    assert(Engine.time_scale == original_time_scale)
    assert(RenderingServer.viewport_get_update_mode(viewport_rid) == original_mode)
    assert(DirAccess.remove_absolute(path) == OK)
    print("BASE_FRAME_BUDGET_RUNTIME_PASS")
    quit(0)

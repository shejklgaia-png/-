extends SceneTree
## Isolated ConfigFile persistence test: never overwrite the user's settings.
const FPS = preload("res://scripts/sera_frame_rate_settings.gd")
const TEST_PATH: String = "user://sera_fps_options_ci_test.cfg"

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var absolute_path: String = ProjectSettings.globalize_path(TEST_PATH)
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(absolute_path)
    var legacy := ConfigFile.new()
    legacy.set_value("controls", "auto_lock_enabled", false)
    legacy.set_value("controls", "left_handed", true)
    assert(legacy.save(TEST_PATH) == OK)

    assert(FPS.FPS_LEVELS == [60, 40, 30, 20])
    assert(FPS.get_limit("base_nexus", TEST_PATH) == 30)
    assert(FPS.get_limit("grid", TEST_PATH) == 60)
    assert(FPS.get_limit("combat", TEST_PATH) == 60)
    assert(FPS.next_limit(60) == 40)
    assert(FPS.next_limit(40) == 30)
    assert(FPS.next_limit(30) == 20)
    assert(FPS.next_limit(20) == 60)

    assert(FPS.set_limit("base_nexus", 40, TEST_PATH))
    assert(FPS.set_limit("grid", 20, TEST_PATH))
    assert(FPS.set_limit("combat", 30, TEST_PATH))
    assert(not FPS.set_limit("grid", 25, TEST_PATH))
    assert(FPS.get_limit("base_nexus", TEST_PATH) == 40)
    assert(FPS.get_limit("grid", TEST_PATH) == 20)
    assert(FPS.get_limit("combat", TEST_PATH) == 30)
    var saved := ConfigFile.new()
    assert(saved.load(TEST_PATH) == OK)
    assert(not bool(saved.get_value("controls", "auto_lock_enabled", true)))
    assert(bool(saved.get_value("controls", "left_handed", false)))

    saved.set_value("fps", "grid", 25)
    assert(saved.save(TEST_PATH) == OK)
    assert(FPS.get_limit("grid", TEST_PATH) == 60, "Bad saved value must fall back")
    var old_max: int = Engine.max_fps
    FPS.apply("base_nexus", TEST_PATH)
    assert(Engine.max_fps == 40)
    FPS.apply("combat", TEST_PATH)
    assert(Engine.max_fps == 30)
    Engine.max_fps = old_max

    assert(DirAccess.remove_absolute(absolute_path) == OK)
    print("SERA_FPS_OPTIONS_RUNTIME_PASS")
    quit(0)

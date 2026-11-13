extends SceneTree
## Instantiate the actual main scene and test the existing private call surface
## against canonical v317 vectors, thresholds and camera basis projections.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_SPLIT_INPUT_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("missing training scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var constants: Dictionary = game.get_script().get_script_constant_map()
    game.set("pointer_origin", Vector2(200.0, 400.0))
    var slow: Vector2 = game.call("_analog_stick_direction", Vector2(205.0, 402.0))
    if slow.length_squared() > 0.000001:
        _fail("RUN deadzone changed")
        return
    var fast: Vector2 = game.call("_analog_stick_direction", Vector2(305.0, 400.0))
    if fast.distance_to(Vector2.RIGHT) > 0.00001:
        _fail("RUN full-strength control changed")
        return
    var directions: Array[Vector2] = [
        Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
        Vector2(1.0, -1.0).normalized(), Vector2(-1.0, 1.0).normalized()]
    for direction in directions:
        var delta: Vector2 = direction * 140.0
        game.set("gesture_max_travel", delta.length())
        var step: Vector2 = game.call("_classify_step_flick", delta, 0.20)
        if step.distance_to(direction) > 0.00001:
            _fail("continuous STEP input changed at " + str(direction))
            return
        var kick: Vector2 = game.call("_classify_combo_kick_flick", delta, 0.20)
        if kick.distance_to(direction) > 0.00001:
            _fail("combo kick screen input changed at " + str(direction))
            return
    if int(game.call("_combo_kick_side_for_flick", Vector2.RIGHT)) != 1:
        _fail("screen-right Kick_r changed")
        return
    if int(game.call("_combo_kick_side_for_flick", Vector2.LEFT)) != -1:
        _fail("screen-left Kick_l changed")
        return
    if int(game.call("_combo_kick_side_for_flick", Vector2.DOWN)) != 2:
        _fail("screen-down Kick_b changed")
        return
    if int(game.call("_combo_kick_side_for_flick", Vector2.UP)) != 0:
        _fail("screen-up Bash changed")
        return
    game.set("gesture_max_travel", 145.0)
    if (game.call("_classify_step_flick", Vector2.RIGHT * 100.0, 0.20)
            as Vector2).length_squared() > 0.000001:
        _fail("direction reversal protection changed")
        return
    game.set("gesture_max_travel", 100.0)
    if int(game.call("_classify_side_flick", Vector2.RIGHT * 100.0, 0.20)) != 1:
        _fail("release-only side gesture changed")
        return
    if bool(game.call("_is_upward_jump_flick", Vector2(0.0, -110.0), 0.20)) != true:
        _fail("debug-only jump classifier changed")
        return
    var camera: Camera3D = game.get("camera")
    var screen_right: Vector3 = game.call("_screen_drag_to_ground", Vector2.RIGHT)
    var screen_up: Vector3 = game.call("_screen_drag_to_ground", Vector2.UP)
    if absf(screen_right.y) > 0.000001 or absf(screen_up.y) > 0.000001:
        _fail("screen movement escaped XZ plane")
        return
    var actual_right: Vector3 = camera.global_transform.basis.x
    actual_right.y = 0.0
    if screen_right.distance_to(actual_right.normalized()) > 0.00001:
        _fail("camera screen-right projection changed")
        return
    # Lock-facing projection for pose: actor forward -Z, screen-right X.
    var locked_pose: Vector2 = game.call("_step_local_pose_direction", Vector3.RIGHT)
    if locked_pose.length() < 0.99:
        _fail("STEP pose direction normalization changed")
        return
    print("SERA_V317_SPLIT_INPUT_RUNTIME_PASS")
    quit(0)

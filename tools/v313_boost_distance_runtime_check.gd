extends SceneTree
## v314 correction to v313: BOOST continues beyond 5m; STEP is 5m.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V313_BOOST_CORRECTION_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("actors unavailable")
        return
    game.set("target_move_enabled", false)
    game.set("target_hp", 500)
    var directions: Array[Vector2] = [
        Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
        Vector2(1,-1).normalized(), Vector2(-1,-1).normalized(),
        Vector2(1,1).normalized(), Vector2(-1,1).normalized()
    ]
    for i in range(directions.size()):
        player.position = Vector3(target.position.x, 0.0, target.position.z + 18.0)
        game.set("camera_yaw", 0.0)
        game.call("_place_camera")
        game.set("energy", 100.0)
        game.set("energy_exhausted", false)
        game.set("combat_state", 0)
        game.set("guard_active", false)
        game.set("direction_input", directions[i])
        game.set("gesture_active", true)
        game.set("gesture_max_travel", 200.0)
        game.set("gesture_suppressed_from_damage", false)
        game.set("pointer_origin", Vector2.ZERO)
        game.set("pointer_location", directions[i] * 200.0)
        game.set("movement_boost_active", false)
        game.set("boost_has_activated_this_gesture", false)
        game.set("boost_confirm_elapsed", 0.0)
        game.call("_reset_boost_speed_transition")
        game.call("_update_boost_gesture", 0.11)
        if not bool(game.get("movement_boost_active")):
            _fail("BOOST did not activate at " + str(i))
            return
        var origin: Vector3 = player.global_position
        var exceeded_five: bool = false
        for tick in range(180):
            game.call("_physics_process", 1.0 / 60.0)
            var traveled: Vector3 = player.global_position - origin
            traveled.y = 0.0
            if traveled.length() > 5.15:
                exceeded_five = true
                break
        if not exceeded_five:
            _fail("BOOST still capped near 5m at " + str(i))
            return
        game.set("gesture_active", false)
        game.set("movement_boost_active", false)
        game.set("direction_input", Vector2.ZERO)
    var expected_distance: float = float(game.get_script().get_script_constant_map()["STEP_FORWARD_DISTANCE"])
    if absf(float(game.call("_step_fixed_distance_for_direction", Vector2.UP)) - expected_distance) > 0.0001:
        _fail("STEP distance not corrected")
        return
    print("GODOT_V313_CAP_REVOKED_CONTINUOUS_BOOST_PASS")
    quit(0)

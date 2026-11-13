extends SceneTree
## v313: Manual BOOST travels at most 5m in all screen directions, even across turns.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V313_BOOST_FAILED: " + reason)
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
        game.set("boost_distance_capped", false)
        game.set("boost_distance_traveled", 0.0)
        game.set("movement_boost_active", false)
        game.set("boost_has_activated_this_gesture", false)
        game.set("boost_confirm_elapsed", 0.0)
        game.call("_reset_boost_speed_transition")
        game.call("_update_boost_gesture", 0.11)
        if not bool(game.get("movement_boost_active")):
            _fail("BOOST did not activate at " + str(i))
            return
        var total_active_distance: float = 0.0
        var reached: bool = false
        for tick in range(120):
            # Turning through 90 degrees must not refund any of the 5m.
            if i == 4 and tick == 20:
                game.set("direction_input", Vector2.LEFT)
                game.set("pointer_location", Vector2.LEFT * 200.0)
            var before: Vector3 = player.global_position
            var active_before: bool = bool(game.get("movement_boost_active"))
            game.call("_physics_process", 1.0 / 60.0)
            var delta_move: Vector3 = player.global_position - before
            delta_move.y = 0.0
            if active_before:
                total_active_distance += delta_move.length()
            if bool(game.get("boost_distance_capped")):
                reached = true
                break
        if not reached:
            _fail("5m cap was never reached at " + str(i))
            return
        var tracked: float = float(game.get("boost_distance_traveled"))
        if absf(tracked - 5.0) > 0.02 or total_active_distance > 5.02:
            _fail("BOOST traveled beyond 5m at " + str(i) + ": " + str(total_active_distance) + "/" + str(tracked))
            return
        if bool(game.get("movement_boost_active")):
            _fail("BOOST did not stop at 5m at " + str(i))
            return
        for tick in range(15):
            game.call("_physics_process", 1.0 / 60.0)
            if bool(game.get("movement_boost_active")):
                _fail("BOOST restarted without rearming at " + str(i))
                return
        # The inward return is the only way to rearm during the same touch.
        game.set("pointer_location", directions[i] * 20.0)
        game.call("_update_boost_gesture", 0.016)
        if bool(game.get("boost_distance_capped")):
            _fail("inward return did not rearm BOOST at " + str(i))
            return
        game.set("pointer_location", directions[i] * 200.0)
        game.call("_update_boost_gesture", 0.11)
        if not bool(game.get("movement_boost_active")):
            _fail("rearmed BOOST could not start at " + str(i))
            return
        if float(game.get("boost_distance_traveled")) > 0.001:
            _fail("new BOOST did not reset distance at " + str(i))
            return
        game.set("gesture_active", false)
        game.set("movement_boost_active", false)
        game.set("direction_input", Vector2.ZERO)
    if absf(float(game.call("_step_fixed_distance_for_direction", Vector2.UP)) - 7.0) > 0.0001:
        _fail("STEP 7m was modified")
        return
    print("GODOT_V313_BOOST_5M_360_DEGREES_PASS")
    quit(0)

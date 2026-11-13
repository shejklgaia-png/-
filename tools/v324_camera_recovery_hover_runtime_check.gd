extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("V324_CAMERA_FAILED: " + message)
    quit(1)
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player = game.get("player")
    var target = game.get("target")
    var cfg: Dictionary = game.get_script().get_script_constant_map()
    var base: float = cfg["TARGET_BASE_HEIGHT"]
    target.position = Vector3(0, base, 0)
    player.position = Vector3(0, 0, 3.5)
    player.reset_physics_interpolation()
    target.reset_physics_interpolation()
    game.set("camera_player_render_position", player.position)
    game.set("camera_target_render_position", target.position)
    game.set("camera_focus_follow_xz", game.call("_desired_camera_follow_focus_xz"))
    var finals: Array[float] = []
    for hz in [30, 60, 120]:
        game.set("camera_yaw", deg_to_rad(-12.0))
        game.set("camera_follow_radius", 24.0)
        game.set("camera_fit_radius_floor", 24.0)
        game.set("camera_radius", 24.0)
        game.set("camera_dolly_in_speed", 0.0)
        for i in range(hz * 3):
            var before: float = game.get("camera_radius")
            game.call("_process", 1.0 / hz)
            var after: float = game.get("camera_radius")
            if before - after > 25.0 / hz:
                _fail("zoom recovery teleported")
                return
            if not game.call("_full_frame_safe"):
                _fail("recovery cropped combatants")
                return
        var recovered: float = game.get("camera_radius")
        var safe: float = game.call("_minimum_boost_camera_radius")
        # v329: 20% actor-side protection may need >16m; judge
        # recovery against the actual computed safe envelope instead.
        if recovered > safe + 0.6:
            _fail("stationary camera remains too far: %s / safe %s" % [recovered, safe])
            return
        finals.append(recovered)
    if absf(finals[0] - finals[2]) > 0.2:
        _fail("recovery depends on render rate")
        return
    # Hold the combat composition without needing an actual strike/contact.
    game.set("camera_follow_radius", 24.0)
    game.set("camera_fit_radius_floor", 24.0)
    for i in range(180):
        game.set("camera_combat_hold_remaining", 1.0)
        game.call("_process", 1.0 / 60.0)
    var combat_safe: float = game.call("_minimum_boost_camera_radius")
    if float(game.get("camera_radius")) > combat_safe + 0.6:
        _fail("combat hold latched an excessive radius")
        return
    # Full hover cycle must not pump zoom, while both extrema stay framed.
    var min_radius: float = INF
    var max_radius: float = 0.0
    for i in range(600):
        target.position.y = base + sin(i / 60.0 * 1.4) * 0.07
        target.reset_physics_interpolation()
        game.call("_process", 1.0 / 60.0)
        if i > 120:
            min_radius = minf(min_radius, game.get("camera_radius"))
            max_radius = maxf(max_radius, game.get("camera_radius"))
        if not game.call("_full_frame_safe"):
            _fail("hover envelope is cropped")
            return
    if max_radius - min_radius > 0.01:
        _fail("hover changes zoom: %s" % (max_radius - min_radius))
        return
    print("PASS v324: 30/60/120Hz recovery, combat recovery, hover-stable framing")
    game.queue_free()
    await process_frame
    quit(0)

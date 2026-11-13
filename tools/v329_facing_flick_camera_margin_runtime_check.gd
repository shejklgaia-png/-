extends SceneTree
## Real scene: projected-facing flick survives v330 camera rollback.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("V329_FLICK_CAMERA_FAILED: " + message)
    quit(1)
func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var cam: Camera3D = game.get("camera")
    if player == null or boss == null or cam == null:
        _fail("scene unavailable")
        return
    for forward in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
            Vector2(0.8, -0.6).normalized()]:
        game.set("gesture_screen_forward", forward)
        var right: Vector2 = Vector2(-forward.y, forward.x)
        if not bool(game.call("_is_character_forward_flick", forward * 100.0, 0.25)):
            _fail("Bash does not use projected SERA front")
            return
        if bool(game.call("_is_character_forward_flick", -forward * 100.0, 0.25)):
            _fail("backward flick incorrectly started Bash")
            return
        for sector in [[right, 1], [-right, -1], [-forward, 2], [forward, 0]]:
            if int(game.call("_combo_kick_side_for_flick", sector[0])) != int(sector[1]):
                _fail("Kick_r/l/Kick_b failed actor-relative classification")
                return
    game.set("gesture_screen_forward", Vector2.RIGHT)
    game.set("camera_yaw", deg_to_rad(145.0))
    game.call("_place_camera")
    if int(game.call("_combo_kick_side_for_flick", Vector2.DOWN)) != 1:
        _fail("camera movement rotated the frozen flick frame")
        return
    var viewport_width: float = game.get_viewport().get_visible_rect().size.x
    if viewport_width <= 0.0:
        _fail("viewport missing")
        return
    for offset in [Vector3(-20.0,0.0,-6.0),Vector3(20.0,0.0,-6.0),
            Vector3(-3.0,0.0,5.0),Vector3(3.0,0.0,5.0)]:
        player.position = boss.position + offset
        player.position.y = 0.0
        game.set("camera_player_render_position", player.position)
        game.set("camera_target_render_position", boss.position)
        game.set("camera_focus_follow_xz", game.call("_desired_camera_follow_focus_xz"))
        game.set("camera_yaw", atan2(offset.x,offset.z) - deg_to_rad(12.0))
        game.set("camera_follow_radius",8.0)
        game.set("camera_fit_radius_floor",0.0)
        game.set("camera_radius",8.0)
        game.call("_place_camera")
        game.call("_fit_boost_frame_analytically",1.0/60.0)
        if not bool(game.call("_horizontal_safe")):
            _fail("v327 camera failed to keep player within visible frame")
            return
        var torso: Vector3 = player.position + Vector3(0.0,1.05,0.0)
        var x: float = cam.unproject_position(torso).x / viewport_width
        if x < 0.02-0.0001 or x > 0.98+0.0001:
            _fail("player outside legacy safe band: " + str(x))
            return
    print("PASS v329 actor-facing kicks/Bash and restored 2% player frame")
    game.queue_free()
    await process_frame
    quit(0)

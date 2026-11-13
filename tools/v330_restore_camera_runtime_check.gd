extends SceneTree
## Check actual camera focus, yaw, screen boundary and preserved input.
const CAMERA_MATH = preload("res://scripts/sera_camera_math.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("V330_CAMERA_RESTORE_FAILED: "+message)
    quit(1)
func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var cam: Camera3D = game.get("camera")
    if player == null or boss == null or cam == null:
        _fail("camera/actor scene missing")
        return
    var c: Dictionary = game.get_script().get_script_constant_map()
    var player_xz := Vector2(3.0, 6.0)
    var boss_xz := Vector2(0.0, 0.0)
    game.set("camera_player_render_position",Vector3(3.0,0.0,6.0))
    game.set("camera_target_render_position",Vector3(0.0,1.53,0.0))
    var expected: Vector2 = CAMERA_MATH.desired_follow_focus(
        player_xz,boss_xz,2.0)
    var actual: Vector2 = game.call("_desired_camera_follow_focus_xz")
    if actual.distance_to(expected)>0.00001:
        _fail("focus is not v327 player + 2m target lead")
        return
    if actual.distance_to(boss_xz)<1.0:
        _fail("focus is still boss-centered")
        return
    var wanted_yaw: float = atan2(3.0,6.0)-deg_to_rad(12.0)
    game.set("camera_yaw", wanted_yaw)
    game.set("camera_focus_follow_xz", actual)
    game.set("camera_radius",14.0)
    game.call("_place_camera")
    var before: Vector2 = game.get("camera_focus_follow_xz")
    game.set("camera_target_render_position",Vector3(9.0,1.53,0.0))
    game.call("_advance_camera_follow_focus", 1.0/60.0)
    var after: Vector2 = game.get("camera_focus_follow_xz")
    if after.distance_to(before)>0.5:
        _fail("focus jumped instead of following smoothly")
        return
    # Confirm v327 2% margin, not v329's 20% threshold.
    if absf(float(c["SCREEN_MARGIN_X"])-0.02)>0.00001:
        _fail("20% camera framing constraint remains")
        return
    if absf(float(c["CAMERA_COMBAT_SHOULDER_DEGREES"])-12.0)>0.00001:
        _fail("old shoulder angle not restored")
        return
    # Noncamera v329 flick axis is preserved.
    game.set("gesture_screen_forward",Vector2.RIGHT)
    if int(game.call("_combo_kick_side_for_flick",Vector2.DOWN))!=1:
        _fail("actor-forward combat flick regression")
        return
    print("PASS v330 player-lead focus, 12deg shoulder, 2% margins and actor flick")
    game.queue_free()
    await process_frame
    quit(0)

extends SceneTree
## Main-scene test: true enemy-centered arcs, original timing, screen right/left
## and tighter camera polar-angle bound. No Android rendering assumptions.
func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V285_SIDE_KICK_ORBIT_CAMERA_FAILED: " + why)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main.tscn missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("scene actor or authored clips unavailable")
        return
    game.set("target_hp", 0)
    game.set("locked_target_part_id", "")
    target.position = Vector3.ZERO
    player.position = Vector3(0.0, 0.0, 9.0)
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("regular screen STEP failed to initialize")
        return
    if not bool(game.get("step_linear_fallback")):
        _fail("normal 360deg STEP was changed from linear")
        return
    var regular_length: float = float(game.get("step_arc_length"))
    var regular_duration: float = float(game.get("step_duration_current"))
    game.call("_finish_side_step", false)
    for side in [1,-1]:
        player.position = Vector3(0.0,0.0,9.0)
        game.set("step_kick_side_request", side)
        if not bool(game.call("_start_omni_step", Vector2.RIGHT if side > 0 else Vector2.LEFT)):
            _fail("kick side refused: " + str(side))
            return
        game.set("step_kick_side_request",0)
        var duration: float = float(game.get("step_duration_current"))
        if absf(duration-regular_duration*2.0)>0.0001:
            _fail("side kick altered 2x authored animation length")
            return
        var second_windup: float = 0.33333 if side>0 else 0.41667
        var start: Vector3 = player.position
        game.call("_advance_side_step",duration*(second_windup-0.001))
        if player.position.distance_to(start)>0.015:
            _fail("kick moved before second windup")
            return
        game.call("_advance_side_step",duration*0.002)
        if not bool(game.get("side_kick_travel_anchor_set")):
            _fail("kick did not latch orbit pivot at windup")
            return
        if bool(game.get("step_linear_fallback")):
            _fail("side kick still uses linear STEP, not enemy-centered orbit")
            return
        var signed_angle: float = float(game.get("step_signed_angle"))
        var start_radius: float = Vector2(start.x,start.z).length()
        if absf(absf(signed_angle)*start_radius-regular_length)>0.04:
            _fail("kick changed original 2-4m path distance")
            return
        # Restore target-independent initial geometry; the target pivot
        # may move without changing orbit radius.
        var midpoint: float = second_windup+0.3
        game.call("_advance_side_step",duration*(midpoint-(second_windup+0.001)))
        var pivot: Vector2 = Vector2(target.position.x,target.position.z)
        var offset: Vector2 = Vector2(player.position.x-pivot.x,player.position.z-pivot.y)
        if absf(offset.length()-start_radius)>0.05:
            _fail("arc changed enemy-centered radius at midpoint")
            return
        target.position = target.position + Vector3(0.08, 0.0, 0.0)
        game.call("_advance_side_step",duration*0.03)
        pivot=Vector2(target.position.x,target.position.z)
        offset=Vector2(player.position.x-pivot.x,player.position.z-pivot.y)
        if absf(offset.length()-start_radius)>0.05:
            _fail("orbit pivot did not follow moving enemy")
            return
        game.call("_finish_side_step",false)
    # The camera's target-centered player bearing constraint is now 45deg,
    # compared with 65deg before v285. One-second delta avoids turn-rate
    # limiting a test of the static bound itself.
    game.set("camera_yaw",deg_to_rad(80.0))
    var limited: float = float(game.call("_close_step_target_relative_yaw",
        0.0, 0.0, 1.0))
    if absf(rad_to_deg(limited)-45.0)>0.01:
        _fail("camera/target/player polar limit is not 45 degrees")
        return
    game.set("camera_yaw",deg_to_rad(-80.0))
    limited=float(game.call("_close_step_target_relative_yaw",0.0,0.0,1.0))
    if absf(rad_to_deg(limited)+45.0)>0.01:
        _fail("negative camera/target/player polar bound is not -45 degrees")
        return
    print("GODOT_V285_SIDE_KICK_ORBIT_CAMERA_PASS: live target-centered kicks, original timing and 45deg camera bound")
    quit(0)

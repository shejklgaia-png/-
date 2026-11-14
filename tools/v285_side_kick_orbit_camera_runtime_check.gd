extends SceneTree
## Historical v285 +/-45deg camera guard, v340 no-orbit linear exit.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("V285_SIDE_KICK_CAMERA_FAILED: " + why)
    quit(1)
func _run() -> void:
    var packed: PackedScene=load("res://scenes/main.tscn")
    if packed==null:
        _fail("main scene missing")
        return
    var game: Node3D=packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    var rig: Node3D=game.get("rig")
    if player==null or target==null or rig==null or not bool(rig.get("loading_ok")):
        _fail("rig missing")
        return
    game.set("target_hp",0)
    target.position=Vector3.ZERO
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    var stats: Dictionary=game.get("part_stats")
    stats["melee_boost_speed"]=0.0
    game.set("part_stats",stats)
    for side in [1,-1]:
        player.position=Vector3(0.0,0.0,9.0)
        game.set("energy",100.0)
        game.set("energy_exhausted",false)
        var screen: Vector2=Vector2.RIGHT if side>0 else Vector2.LEFT
        var world: Vector3=game.call("_screen_drag_to_ground",screen)
        var direction: Vector2=Vector2(world.x,world.z).normalized()
        game.set("step_kick_side_request",side)
        if not bool(game.call("_start_omni_step",screen)):
            _fail("kick refused")
            return
        game.set("step_kick_side_request",0)
        var d: float=float(game.get("step_duration_current"))
        game.call("_advance_side_step",d*.584)
        if not bool(game.get("side_kick_linear_active")):
            _fail("contact did not arm line")
            return
        var at_hit: Vector2=game.get("side_kick_linear_start")
        if at_hit.distance_to(Vector2(player.position.x,player.position.z))>.0001:
            _fail("moved during hit")
            return
        target.position.x+=.2
        game.set("camera_yaw",deg_to_rad(90.0))
        game.call("_place_camera")
        game.call("_advance_side_step",d*(.85-.584))
        if (game.get("side_kick_linear_direction") as Vector2).distance_to(direction)>.0001:
            _fail("target/camera turned committed flick")
            return
        var want: Vector2=at_hit+direction*4.0*((.85-.584)/(1.0-.584))
        if Vector2(player.position.x,player.position.z).distance_to(want)>.07:
            _fail("dash curved after camera/target movement")
            return
        game.call("_finish_side_step",false)
        target.position=Vector3.ZERO
        game.set("camera_yaw",0.0)
        game.call("_place_camera")
    game.set("camera_yaw",deg_to_rad(80.0))
    var limited: float=float(game.call("_close_step_target_relative_yaw",0.0,0.0,1.0))
    if absf(rad_to_deg(limited)-45.0)>.01:
        _fail("positive camera bound broken")
        return
    game.set("camera_yaw",deg_to_rad(-80.0))
    limited=float(game.call("_close_step_target_relative_yaw",0.0,0.0,1.0))
    if absf(rad_to_deg(limited)+45.0)>.01:
        _fail("negative camera bound broken")
        return
    print("GODOT_V285_SIDE_KICK_CAMERA_PASS (45deg bound, no orbit)")
    quit(0)

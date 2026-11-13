extends SceneTree
## v314: 4m dodge in every screen direction, independent of target distance.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V314_STEP_DISTANCE_FAILED: " + message)
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
        _fail("missing actors or rig")
        return
    var constants: Dictionary=game.get_script().get_script_constant_map()
    var step_distance: float=float(constants["STEP_SIDE_DISTANCE"])
    var step_speed: float=float(constants["STEP_SPEED"])
    var kick_distance: float=float(constants["SIDE_KICK_BOOST_DISTANCE"])
    var kick_speed: float=float(constants["SIDE_KICK_STEP_SPEED"])
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    game.set("locked_target_part_id","")
    game.set("target_move_enabled",false)
    var directions: Array[Vector2]=[
        Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),
        Vector2(1,1).normalized(),Vector2(-1,1).normalized()
    ]
    for i in range(directions.size()):
        player.position=target.position+Vector3(0.0,0.0,18.0)
        player.rotation.y=0.0
        game.set("energy",100.0)
        game.set("energy_exhausted",false)
        game.set("combat_state",0)
        game.call("_place_camera")
        var world: Vector3=game.call("_screen_drag_to_ground",directions[i])
        if world.length_squared()<0.001:
            _fail("invalid direction at "+str(i))
            return
        var before: Vector3=player.position
        if not bool(game.call("_start_omni_step",directions[i])):
            _fail("step refused "+str(i))
            return
        if absf(float(game.get("step_arc_length"))-step_distance)>0.0001:
            _fail("not 4m "+str(i))
            return
        if absf(float(game.get("step_speed_current"))-step_speed)>0.0001:
            _fail("speed changed "+str(i))
            return
        if absf(float(game.get("step_duration_current"))-step_distance/step_speed)>0.0001:
            _fail("duration changed "+str(i))
            return
        var planned: Vector2=game.get("step_linear_offset")
        var expected: Vector2=Vector2(world.x,world.z).normalized()*step_distance
        if planned.distance_to(expected)>0.001:
            _fail("planned direction changed "+str(i))
            return
        game.call("_advance_side_step",float(game.get("step_duration_current")))
        var actual: Vector3=player.position-before
        if Vector2(actual.x,actual.z).distance_to(expected)>0.07:
            _fail("actual displacement changed "+str(i))
            return
        if bool(game.get("step_active")):
            game.call("_finish_side_step",false)
    game.set("energy",100.0)
    game.set("step_kick_side_request",1)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("kick refused")
        return
    if absf(float(game.get("step_arc_length"))-kick_distance)>0.0001:
        _fail("kick distance changed")
        return
    if absf(float(game.get("step_speed_current"))-kick_speed)>0.0001:
        _fail("kick speed changed")
        return
    game.call("_finish_side_step",false)
    print("GODOT_V318_ALL_8_DIRECTIONS_4M_PASS")
    quit(0)

extends SceneTree
## v340 frozen accepted flick, queued Melee3 and next-tick-only post-hit dash.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("V340_LINEAR_KICK_FAILED: " + why)
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
        _fail("combat actors unavailable")
        return
    game.set("target_hp",0)
    target.position=Vector3.ZERO
    player.position=Vector3(0.0,0.0,9.0)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    game.set("energy",100.0)
    game.set("energy_exhausted",false)
    var stats: Dictionary=game.get("part_stats")
    stats["melee_boost_speed"]=0.0
    game.set("part_stats",stats)
    var flick: Vector2=Vector2(1.0,-0.35).normalized()
    var world: Vector3=game.call("_screen_drag_to_ground",flick)
    var accepted: Vector2=Vector2(world.x,world.z).normalized()
    # Queue an eligible lateral direction during the authored finisher.
    game.call("_start_strike",2)
    game.set("gesture_screen_forward",Vector2.UP)
    if not bool(game.call("_request_combo_side_kick",flick)):
        _fail("finisher flick was not queued")
        return
    game.set("camera_yaw",deg_to_rad(85.0))
    game.call("_place_camera")
    game.call("_finish_strike_and_release_queued_kick")
    if not bool(game.get("side_kick_active")):
        _fail("queued kick did not start")
        return
    var direction: Vector2=game.get("side_kick_linear_direction")
    if direction.distance_to(accepted)>.0001:
        _fail("queued release direction changed on camera turn")
        return
    var d: float=float(game.get("step_duration_current"))
    if absf(d-.30)>.0001:
        _fail("original authored kick shortened/extended")
        return
    game.call("_advance_side_step",d*.584)
    if not bool(game.get("side_kick_linear_active")):
        _fail("second contact missing")
        return
    var at_hit: Vector2=game.get("side_kick_linear_start")
    if at_hit.distance_to(Vector2(player.position.x,player.position.z))>.0001:
        _fail("moved during contact frame")
        return
    game.call("_advance_side_step",d*(.75-.584))
    var want: Vector2=at_hit+accepted*4.0*((.75-.584)/(1.0-.584))
    if Vector2(player.position.x,player.position.z).distance_to(want)>.08:
        _fail("next-frame dash not along accepted flick")
        return
    game.call("_advance_side_step",d*.25)
    if Vector2(player.position.x,player.position.z).distance_to(at_hit+accepted*4.0)>.08:
        _fail("4m straight dash incomplete")
        return
    print("GODOT_V340_LINEAR_KICK_PASS (queued direction, next-frame 4m exit)")
    quit(0)

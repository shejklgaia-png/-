extends SceneTree
## Historical 8-way 4m STEP and lock-aware contact; v340 4m flick exit.
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("V300_FIXED_STEP_LOCKED_KICK_FAILED: " + why)
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
    var parts: Node3D=game.get("target_parts")
    if player==null or target==null or rig==null or parts==null or not bool(rig.get("loading_ok")):
        _fail("combat scene unavailable")
        return
    target.position=Vector3.ZERO
    game.set("target_hp",0)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    var stats: Dictionary=game.get("part_stats")
    stats["melee_boost_speed"]=0.0
    game.set("part_stats",stats)
    var vectors: Array[Vector2]=[
        Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,
        Vector2(1,1).normalized(),Vector2(-1,1).normalized(),
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
    for direction in vectors:
        for distance in [3.0,6.0,12.0]:
            player.position=Vector3(0.0,0.0,float(distance))
            game.set("energy",100.0)
            game.set("energy_exhausted",false)
            if not bool(game.call("_start_omni_step",direction)):
                _fail("regular STEP refused")
                return
            if absf(float(game.get("step_arc_length"))-4.0)>.0001 or absf(float(game.get("step_speed_current"))-15.0)>.0001:
                _fail("ordinary step distance/speed changed")
                return
            game.call("_finish_side_step",false)
    for part_id in ["head","leg_fl",""]:
        for side in [1,-1]:
            player.position=Vector3(0.0,0.0,9.0)
            target.position=Vector3.ZERO
            game.set("camera_yaw",0.0)
            game.call("_place_camera")
            game.set("energy",100.0)
            game.set("energy_exhausted",false)
            game.set("locked_target_part_id",part_id)
            var screen: Vector2=Vector2.RIGHT if side>0 else Vector2.LEFT
            var world: Vector3=game.call("_screen_drag_to_ground",screen)
            var direction: Vector2=Vector2(world.x,world.z).normalized()
            game.set("step_kick_side_request",side)
            if not bool(game.call("_start_omni_step",screen)):
                _fail("sidekick refused")
                return
            game.set("step_kick_side_request",0)
            var d: float=float(game.get("step_duration_current"))
            if absf(d-.80)>.0001 or absf(float(game.get("step_arc_length"))-4.0)>.0001:
                _fail("kick clip or 4m dash contract changed")
                return
            game.call("_advance_side_step",d*.50)
            if bool(game.get("side_kick_linear_active")) or not bool(game.get("side_kick_travel_anchor_set")):
                _fail("pre-second-hit state invalid")
                return
            game.call("_advance_side_step",d*(.584-.50))
            if not bool(game.get("side_kick_linear_active")) or (int(game.get("side_kick_hit_mask"))&2)==0:
                _fail("second contact skipped")
                return
            var at_hit: Vector2=game.get("side_kick_linear_start")
            if at_hit.distance_to(Vector2(player.position.x,player.position.z))>.0001:
                _fail("moved on contact frame")
                return
            var actual_dir: Vector2=game.get("side_kick_linear_direction")
            if actual_dir.distance_to(direction)>.0001:
                _fail("flick world direction changed")
                return
            target.position.x+=.3
            game.set("camera_yaw",deg_to_rad(80.0))
            game.call("_place_camera")
            game.call("_advance_side_step",d*(.8-.584))
            var want: Vector2=at_hit+direction*4.0*((.8-.584)/(1.0-.584))
            if Vector2(player.position.x,player.position.z).distance_to(want)>.07:
                _fail("dash curved with lock/camera")
                return
            game.call("_advance_side_step",d*.2)
            if bool(game.get("step_active")):
                _fail("sidekick animation lengthened")
                return
            if Vector2(player.position.x,player.position.z).distance_to(at_hit+direction*4.0)>.07:
                _fail("not all 4m traversed")
                return
    print("GODOT_V300_FIXED_STEP_LOCKED_KICK_PASS (8-way 4m STEP, 4m kick exit)")
    quit(0)

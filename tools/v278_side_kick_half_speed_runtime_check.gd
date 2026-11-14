extends SceneTree
## v343 authored 0.65s Kick_l/Kick_r, v340 next-frame 4m exit.
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("V278_SLOW_KICK_RUNTIME_FAILED: " + message)
    quit(1)
func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene missing")
        return
    var game: Node3D=packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    var rig: Node3D=game.get("rig")
    if player==null or target==null or rig==null or not bool(rig.get("loading_ok")):
        _fail("actors unavailable")
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
        var flick: Vector2=Vector2.RIGHT if side>0 else Vector2.LEFT
        var world: Vector3=game.call("_screen_drag_to_ground",flick)
        var wanted: Vector2=Vector2(world.x,world.z).normalized()
        game.set("step_kick_side_request",side)
        if not bool(game.call("_start_omni_step",flick)):
            _fail("kick unavailable")
            return
        game.set("step_kick_side_request",0)
        var d: float=float(game.get("step_duration_current"))
        if absf(d-.65)>.0001:
            _fail("authored 0.65s duration changed")
            return
        if absf(float(game.get("step_arc_length"))-4.0)>.0001:
            _fail("post-contact dash not 4m")
            return
        if str(rig.get("current_clip"))!=("Kick_r" if side>0 else "Kick_l"):
            _fail("wrong authored clip")
            return
        if absf(float(rig.get("side_kick_playback_scale"))-1.0/d)>.0001:
            _fail("authored clip playback rate changed")
            return
        var beginning: Vector2=Vector2(player.position.x,player.position.z)
        game.call("_advance_side_step",d*.249)
        if int(game.get("side_kick_hit_mask"))!=0:
            _fail("early first hit")
            return
        game.call("_advance_side_step",d*.002)
        if int(game.get("side_kick_hit_mask"))!=1:
            _fail("first authored contact missed")
            return
        var contact_progress: float=.584
        game.call("_advance_side_step",d*(contact_progress-.251))
        if int(game.get("side_kick_hit_mask"))!=3:
            _fail("second authored contact missed")
            return
        if not bool(game.get("side_kick_linear_active")):
            _fail("post-hit dash not armed")
            return
        var at_hit: Vector2=game.get("side_kick_linear_start")
        if at_hit.distance_to(beginning)>.03:
            _fail("premature orbit/linear movement")
            return
        if Vector2(player.position.x,player.position.z).distance_to(at_hit)>.0001:
            _fail("moved on second hit frame")
            return
        var direction: Vector2=game.get("side_kick_linear_direction")
        if direction.distance_to(wanted)>.0001:
            _fail("flick direction changed")
            return
        game.call("_advance_side_step",d*(.8-contact_progress))
        var target_pos: Vector2=at_hit+direction*4.0*((.8-contact_progress)/(1.0-contact_progress))
        if Vector2(player.position.x,player.position.z).distance_to(target_pos)>.06:
            _fail("straight movement wrong on following frame")
            return
        game.call("_advance_side_step",d*.2)
        if bool(game.get("step_active")):
            _fail("authored kick time extended")
            return
        if Vector2(player.position.x,player.position.z).distance_to(at_hit+direction*4.0)>.06:
            _fail("4m line incomplete")
            return
    print("GODOT_V278_KICK_0P65S_PASS (0.65s clip, 4m next-frame exit)")
    quit(0)

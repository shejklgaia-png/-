extends SceneTree
## v300: every angle is target-distance-independent, then each kick orbits
## the locked PART until second hit and follows a fixed straight tangent.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V300_FIXED_STEP_LOCKED_KICK_FAILED: " + message)
    quit(1)


func _grounded_position(v: Vector2) -> Vector3:
    return Vector3(v.x, 0.0, v.y)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene not found")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    var parts: Node3D = game.get("target_parts")
    if player == null or target == null or rig == null or parts == null or not bool(rig.get("loading_ok")):
        _fail("combat actors or animations unavailable")
        return
    target.position = Vector3.ZERO
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    game.set("target_hp",0) # No chase for deterministic geometry.
    var vectors: Array[Vector2] = [
        Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,
        Vector2(1,1).normalized(),Vector2(-1,1).normalized(),
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
    var expected: Array[float] = [7.0,7.0,7.0,7.0,7.0,7.0,7.0,7.0]
    for i in range(vectors.size()):
        for radius in [3.0, 6.0, 12.0]:
            player.position = Vector3(0.0,0.0,radius)
            game.set("energy",100.0)
            game.set("energy_exhausted",false)
            if not bool(game.call("_start_omni_step", vectors[i])):
                _fail("screen STEP refused angle "+str(i))
                return
            var planned: float = float(game.get("step_arc_length"))
            if absf(planned-expected[i])>0.0001:
                _fail("distance changed for angle/radius: "+str(i)+" / "+str(radius))
                return
            if absf(float(game.get("step_speed_current"))-15.0)>0.0001:
                _fail("distance-to-target speed falloff was not removed")
                return
            game.call("_finish_side_step",false)

    # Free-space ordinary dodge travels 7m, with 15m/s base speed.
    player.position=Vector3(0.0,0.0,9.0)
    game.set("energy",100.0)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("free-space right step refused")
        return
    var start: Vector3 = player.position
    game.call("_advance_side_step",float(game.get("step_duration_current")))
    if player.position.distance_to(start+Vector3(7.0,0.0,0.0))>0.05:
        _fail("right STEP did not travel exactly 7m")
        return

    # Lateral kicks: circle around ACTUAL locked HEAD/leg/BODY, retain
    # the authored first and second hit timing, then straight boost.
    for lock_id in ["head","leg_fl",""]:
        for side in [1,-1]:
            target.position=Vector3.ZERO
            player.position=Vector3(0.0,0.0,6.0)
            game.set("camera_yaw",0.0)
            game.call("_place_camera")
            game.set("energy",100.0)
            game.set("target_hp",0)
            game.set("locked_target_part_id",lock_id)
            game.set("step_kick_side_request",side)
            if not bool(game.call("_start_omni_step",Vector2.RIGHT if side>0 else Vector2.LEFT)):
                _fail("kick launch refused: "+lock_id+"/"+str(side))
                return
            game.set("step_kick_side_request",0)
            if absf(float(game.get("step_arc_length"))-3.0)>0.0001:
                _fail("kick boost is not 3m")
                return
            var duration: float = float(game.get("step_duration_current"))
            if absf(duration-0.6)>0.0001:
                _fail("2x authored kick timing changed")
                return
            var windup: float=0.33333 if side>0 else 0.41667
            var hit: float=0.58333
            var beginning: Vector3 = player.position
            game.call("_advance_side_step",duration*windup)
            if player.position.distance_to(beginning)>0.02:
                _fail("kick moved during first strike windup")
                return
            if not bool(game.get("side_kick_travel_anchor_set")):
                _fail("orbit did not start at authored second windup")
                return
            var pivot: Vector2 = game.call("_kick_lock_center_xz")
            var expected_pivot: Vector3 = target.position
            if not lock_id.is_empty():
                expected_pivot = parts.call("get_part_aim_world",lock_id)
            if pivot.distance_to(Vector2(expected_pivot.x,expected_pivot.z))>0.0001:
                _fail("orbit is not centered on LOCKED part: "+lock_id)
                return
            var radial: Vector2 = Vector2(beginning.x,beginning.z)-pivot
            var turn: float = float(game.get("step_signed_angle"))
            var linear_m: float = float(game.get("side_kick_linear_distance"))
            if absf(radial.length()*absf(turn)+linear_m-3.0)>0.0001:
                _fail("orbit+straight total does not equal 3m")
                return
            var near_impact: float=hit-0.005
            game.call("_advance_side_step",duration*(near_impact-windup))
            if bool(game.get("side_kick_linear_active")):
                _fail("linear boost began BEFORE second foot hit")
                return
            var expected_orbit: Vector2=pivot+radial.rotated(
                turn*(near_impact-windup)/(hit-windup))
            if Vector2(player.position.x,player.position.z).distance_to(expected_orbit)>0.06:
                _fail("pre-hit motion is not locked-part orbit")
                return
            game.call("_advance_side_step",duration*(hit-near_impact))
            if not bool(game.get("side_kick_linear_active")):
                _fail("did not switch to tangent exactly at second hit")
                return
            if (int(game.get("side_kick_hit_mask")) & 2)==0:
                _fail("authored second hit key was dropped")
                return
            var line_start: Vector2=game.get("side_kick_linear_start")
            var tangent: Vector2=game.get("side_kick_linear_direction")
            if absf(tangent.length()-1.0)>0.0001:
                _fail("post-hit tangent is not unit length")
                return
            var true_radial: Vector2=line_start-Vector2(expected_pivot.x,expected_pivot.z)
            if absf(true_radial.normalized().dot(tangent))>0.02:
                _fail("straight direction not tangent to locked part")
                return
            target.position.x+=0.2
            game.call("_advance_side_step",duration*(0.8-hit))
            var expected_line: Vector2=line_start+tangent*linear_m*((0.8-hit)/(1.0-hit))
            if Vector2(player.position.x,player.position.z).distance_to(expected_line)>0.07:
                _fail("post-hit straight boost kept rotating with the target")
                return
            game.call("_advance_side_step",duration*0.2)
            var finish: Vector2=Vector2(player.position.x,player.position.z)
            if finish.distance_to(line_start+tangent*linear_m)>0.07:
                _fail("post-hit boost did not finish on its straight 3m plan")
                return

    # Kick_b remains one genuine cubic aerial arc, but now goes 5m back.
    game.set("back_somersault_direction",Vector3.BACK)
    for t in [0.0,0.25,0.5,0.75,1.0]:
        var offset: Vector3=game.call("_back_somersault_arc_offset",t)
        var expected_xz: float=5.0*(3.0*t*t-2.0*t*t*t)
        if absf(offset.dot(Vector3.BACK)-expected_xz)>0.0001:
            _fail("5m somersault Bezier distance wrong at "+str(t))
            return
        if absf(offset.y-6.0*t*(1.0-t))>0.0001:
            _fail("somersault height or curve was changed")
            return
    print("GODOT_V300_FIXED_STEP_LOCKED_KICK_PASS")
    quit(0)

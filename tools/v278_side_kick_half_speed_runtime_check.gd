extends SceneTree
## Historical v278: authored 2x kick timing and both hits, updated to v300
## locked-part orbit until impact 2 then straight 3m TOTAL boost.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V278_SLOW_KICK_RUNTIME_FAILED: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("cannot load main scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("actors or authored rig unavailable")
        return
    target.position = Vector3.ZERO
    player.position = Vector3(0.0,0.0,9.0)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    game.set("target_hp",0)
    game.set("locked_target_part_id","")
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("normal STEP refused")
        return
    var baseline_duration: float = float(game.get("step_duration_current"))
    var baseline_distance: float = float(game.get("step_arc_length"))
    var baseline_speed: float = float(game.get("step_speed_current"))
    if absf(baseline_distance-5.0)>0.0001             or absf(baseline_speed-15.0)>0.0001             or absf(baseline_duration-5.0/15.0)>0.0001:
        _fail("ordinary dodge is no longer 5m at 15m/s")
        return
    game.call("_finish_side_step",false)
    for side in [1,-1]:
        game.set("energy",100.0)
        game.set("energy_exhausted",false)
        player.position=Vector3(0.0,0.0,9.0)
        game.set("step_kick_side_request",side)
        if not bool(game.call("_start_omni_step",Vector2.RIGHT if side>0 else Vector2.LEFT)):
            _fail("kick refused "+str(side))
            return
        game.set("step_kick_side_request",0)
        var expected_clip: String="Kick_r" if side>0 else "Kick_l"
        if str(rig.get("current_clip"))!=expected_clip:
            _fail("authored kick clip changed")
            return
        var duration: float=float(game.get("step_duration_current"))
        if absf(duration-0.60)>0.0001:
            _fail("authored 2x motion timing changed")
            return
        if absf(float(game.get("step_arc_length"))-3.0)>0.0001:
            _fail("kick post-windup boost is not 3m")
            return
        if absf(float(game.get("step_speed_current"))-10.0)>0.0001:
            _fail("kick base speed changed")
            return
        if absf(float(rig.get("side_kick_playback_scale"))-(1.0/duration))>0.0001:
            _fail("authored kick playback differs from action duration")
            return
        var start: Vector3=player.position
        game.call("_advance_side_step",duration*0.249)
        if player.position.distance_to(start)>0.015 or int(game.get("side_kick_hit_mask"))!=0:
            _fail("kick moved/hit before first foot extension")
            return
        game.call("_advance_side_step",duration*0.002)
        if int(game.get("side_kick_hit_mask"))!=1 or player.position.distance_to(start)>0.015:
            _fail("first authored contact was skipped or moved")
            return
        game.call("_advance_side_step",duration*0.249)
        if not bool(game.get("step_active")) or not bool(game.get("side_kick_travel_anchor_set")):
            _fail("kick stopped or failed to enter orbit")
            return
        var windup: float=0.33333 if side>0 else 0.41667
        var turn: float=float(game.get("step_signed_angle"))
        var radial: Vector2=Vector2(start.x-target.position.x,start.z-target.position.z)
        var pivot: Vector2=Vector2(target.position.x,target.position.z)
        var orbit_progress: float=(0.5-windup)/(0.58333-windup)
        var expected_orbit: Vector2=pivot+radial.rotated(turn*orbit_progress)
        var actual: Vector2=Vector2(player.position.x,player.position.z)
        if actual.distance_to(expected_orbit)>0.04:
            _fail("kick did not orbit BODY during second swing")
            return
        if bool(game.get("side_kick_linear_active")):
            _fail("linear boost began before second impact")
            return
        var nominal_arc: float=radial.length()*absf(turn)
        var straight: float=float(game.get("side_kick_linear_distance"))
        if absf(nominal_arc+straight-3.0)>0.0001:
            _fail("orbit and tangent boost no longer sum to 3m")
            return
        rig.call("_process",duration*0.5)
        if absf(float(rig.call("get_clip_time"))-0.5)>0.016:
            _fail("authored kick clip midpoint failed")
            return
        game.call("_advance_side_step",duration*0.085)
        if int(game.get("side_kick_hit_mask"))!=3 or not bool(game.get("side_kick_linear_active")):
            _fail("second authored contact did not transition to linear boost")
            return
        var line_start: Vector2=game.get("side_kick_linear_start")
        var tangent: Vector2=game.get("side_kick_linear_direction")
        if absf(radial.normalized().dot(tangent))>0.25:
            # The tangent is perpendicular to the final, ROTATED radius,
            # not the original one: verify against the contact pose below.
            var at_hit: Vector2=line_start-pivot
            if absf(at_hit.normalized().dot(tangent))>0.025:
                _fail("boost is not tangent to orbit at second hit")
                return
        game.call("_advance_side_step",duration*0.415)
        if bool(game.get("step_active")):
            _fail("2x kick clip did not complete")
            return
        var ending: Vector2=Vector2(player.position.x,player.position.z)
        if ending.distance_to(line_start+tangent*straight)>0.04:
            _fail("kick did not finish the straight portion")
            return
    print("GODOT_V278_SIDE_KICK_HALF_SPEED_PASS: 2x kicks, 2 authored hits, locked BODY arc then tangent 3m")
    quit(0)

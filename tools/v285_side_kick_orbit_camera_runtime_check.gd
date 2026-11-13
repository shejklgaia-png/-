extends SceneTree
## v285 camera protection is retained, but v300 circles the locked part
## until 2nd contact before a committed 3m-total straight-tangent exit.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V285_SIDE_KICK_ORBIT_CAMERA_FAILED: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene=load("res://scenes/main.tscn")
    if packed==null:
        _fail("missing main.tscn")
        return
    var game: Node3D=packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    var rig: Node3D=game.get("rig")
    var parts: Node3D=game.get("target_parts")
    if player==null or target==null or rig==null or parts==null or not bool(rig.get("loading_ok")):
        _fail("combat scene nodes absent")
        return
    game.set("target_hp",0)
    target.position=Vector3.ZERO
    player.position=Vector3(0.0,0.0,9.0)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("regular STEP refused")
        return
    if not bool(game.get("step_linear_fallback")):
        _fail("ordinary STEP is not linear")
        return
    var regular_distance: float=float(game.get("step_arc_length"))
    var regular_duration: float=float(game.get("step_duration_current"))
    if absf(regular_distance-7.0)>0.0001 or absf(regular_duration-7.0/15.0)>0.0001:
        _fail("regular horizontal dodge is not 7m at 15m/s")
        return
    game.call("_finish_side_step",false)
    for side in [1,-1]:
        for lock_id in ["head","leg_fl",""]:
            player.position=Vector3(0.0,0.0,9.0)
            target.position=Vector3.ZERO
            game.set("energy",100.0)
            game.set("energy_exhausted",false)
            game.set("locked_target_part_id",lock_id)
            game.set("step_kick_side_request",side)
            if not bool(game.call("_start_omni_step",Vector2.RIGHT if side>0 else Vector2.LEFT)):
                _fail("sidekick refused "+str(side)+" / "+lock_id)
                return
            game.set("step_kick_side_request",0)
            var duration: float=float(game.get("step_duration_current"))
            if absf(duration-0.60)>0.0001:
                _fail("original authored 2x kick timing lost")
                return
            var windup: float=0.33333 if side>0 else 0.41667
            var pivot_expected: Vector3=target.position
            if not lock_id.is_empty():
                pivot_expected=parts.call("get_part_aim_world",lock_id)
            var pivot_xz: Vector2=Vector2(pivot_expected.x,pivot_expected.z)
            game.call("_advance_side_step",duration*(windup+0.001))
            if not bool(game.get("side_kick_travel_anchor_set")):
                _fail("orbit pivot not selected on 2nd windup")
                return
            var pivot: Vector2=game.call("_kick_lock_center_xz")
            if pivot.distance_to(pivot_xz)>0.0001:
                _fail("orbit pivot not LOCKED part")
                return
            var start_radial: Vector2=game.get("step_start_offset")
            var radius: float=start_radial.length()
            var angle: float=float(game.get("step_signed_angle"))
            var tangent: Vector2=Vector2(-start_radial.y,start_radial.x).normalized()
            var screen_right: Vector3=game.call("_screen_drag_to_ground",Vector2.RIGHT)
            var right_xz: Vector2=Vector2(screen_right.x,screen_right.z).normalized()
            if angle*tangent.dot(right_xz)*float(side)<=0.0:
                _fail("opposite screen side chosen for orbit")
                return
            var halfway: float=0.5*(windup+0.58333)
            game.call("_advance_side_step",duration*(halfway-(windup+0.001)))
            pivot=game.call("_kick_lock_center_xz")
            var offset: Vector2=Vector2(player.position.x,player.position.z)-pivot
            if absf(offset.length()-radius)>0.06:
                _fail("locked-part orbit radius changed")
                return
            target.position+=Vector3(0.08,0.0,0.0)
            game.call("_advance_side_step",duration*0.01)
            pivot=game.call("_kick_lock_center_xz")
            offset=Vector2(player.position.x,player.position.z)-pivot
            if absf(offset.length()-radius)>0.06:
                _fail("orbit did not follow moving target/locked part")
                return
            game.call("_advance_side_step",duration*(0.58333-(halfway+0.01)))
            if not bool(game.get("side_kick_linear_active")):
                _fail("did not switch at second contact")
                return
            var line_start: Vector2=game.get("side_kick_linear_start")
            var tangent_out: Vector2=game.get("side_kick_linear_direction")
            var straight_m: float=float(game.get("side_kick_linear_distance"))
            if absf(radius*absf(angle)+straight_m-3.0)>0.0001:
                _fail("fixed kick boost 3m budget broken")
                return
            target.position+=Vector3(0.3,0.0,0.0)
            game.call("_advance_side_step",duration*(0.8-0.58333))
            var expected: Vector2=line_start+tangent_out*straight_m*((0.8-0.58333)/(1.0-0.58333))
            if Vector2(player.position.x,player.position.z).distance_to(expected)>0.06:
                _fail("post-hit boost still circles moving boss")
                return
            game.call("_finish_side_step",false)
    # Existing independent camera constraint still caps relative yaw to 45°.
    game.set("camera_yaw",deg_to_rad(80.0))
    var limited: float=float(game.call("_close_step_target_relative_yaw",0.0,0.0,1.0))
    if absf(rad_to_deg(limited)-45.0)>0.01:
        _fail("positive camera bound changed")
        return
    game.set("camera_yaw",deg_to_rad(-80.0))
    limited=float(game.call("_close_step_target_relative_yaw",0.0,0.0,1.0))
    if absf(rad_to_deg(limited)+45.0)>0.01:
        _fail("negative camera bound changed")
        return
    print("GODOT_V285_SIDE_KICK_ORBIT_CAMERA_PASS: locked part arc then tangent, original 45deg camera bound")
    quit(0)

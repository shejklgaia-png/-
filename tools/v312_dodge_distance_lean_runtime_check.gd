extends SceneTree
## v312: 5m/15m/s in all directions; Waist leans down toward evasive travel.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V312_DODGE_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene=load("res://scenes/main.tscn")
    if scene==null:
        _fail("training scene unavailable")
        return
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var rig: Node3D=game.get("rig")
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    if rig==null or player==null or target==null or not bool(rig.get("loading_ok")):
        _fail("missing actors or authored STEP motions")
        return
    game.set("target_hp",500)
    game.set("target_move_enabled",false)
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    game.set("locked_target_part_id","")
    game.set("camera_yaw",0.0)
    var bones: Dictionary=rig.get("bones")
    var consts: Dictionary=rig.get_script().get_script_constant_map()
    var uid: String=str(consts["RUN_ROOT_BONE_UUID"])
    var pivot: Node3D=bones[uid]
    var bind_positions: Dictionary=rig.get("bind_positions")
    var directions: Array[Vector2]=[
        Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),
        Vector2(1,1).normalized(),Vector2(-1,1).normalized()
    ]
    for i in range(directions.size()):
        player.position=Vector3(target.position.x,0.0,target.position.z+16.0)
        player.rotation.y=0.35
        game.set("energy",100.0)
        game.set("energy_exhausted",false)
        game.set("combat_state",0)
        game.call("_place_camera")
        var wanted_world: Vector3=game.call("_screen_drag_to_ground",directions[i])
        if wanted_world.length_squared()<0.001:
            _fail("invalid camera axes at "+str(i))
            return
        var origin: Vector3=player.position
        if not bool(game.call("_start_omni_step",directions[i])):
            _fail("dodge refused at "+str(i))
            return
        if absf(float(game.get("step_arc_length"))-5.0)>0.0001:
            _fail("dodge not 5m at "+str(i))
            return
        if absf(float(game.get("step_speed_current"))-15.0)>0.0001:
            _fail("dodge not 15m/s at "+str(i))
            return
        if absf(float(game.get("step_duration_current"))-5.0/15.0)>0.0001:
            _fail("dodge not 5m/15m/s duration at "+str(i))
            return
        var displacement: Vector2=game.get("step_linear_offset")
        var expected_world: Vector2=Vector2(wanted_world.x,wanted_world.z).normalized()*5.0
        if displacement.distance_to(expected_world)>0.001:
            _fail("screen direction or distance changed at "+str(i))
            return
        var local: Vector2=rig.get("directional_step_vector")
        var lean: Quaternion=rig.call("_step_dodge_lean_rotation",1.0)
        var tilted_up: Vector3=lean*Vector3.UP
        var travel: Vector3=Vector3(local.x,0.0,local.y).normalized()
        if tilted_up.dot(travel)<0.36:
            _fail("dodge lean does not point toward travel at "+str(i)+": "+str(tilted_up))
            return
        if absf(rad_to_deg(lean.get_angle())-22.0)>0.05:
            _fail("lean angle is not 22 degrees at "+str(i))
            return
        rig.set("blending_for",0.12)
        rig.call("_apply_animation",0.0)
        var blended: Dictionary=rig.call("_blended_directional_step_pose",uid,0.0)
        var authored_q: Quaternion=blended["rotation"]
        var yaw_weight: float=1.0-float(rig.call("_step_right_authored_yaw_weight"))
        var base: Quaternion=rig.call("_face_locked_boss_with_waist",authored_q,yaw_weight)
        var expected_q: Quaternion=(lean*base).normalized()
        if pivot.quaternion.angle_to(expected_q)>0.001:
            _fail("additive lean failed on authored Waist at "+str(i))
            return
        var authored_position: Vector3=bind_positions[uid]+blended["position"]
        if absf(pivot.position.y-(authored_position.y-0.14))>0.0001:
            _fail("14cm low dodge stance missing at "+str(i))
            return
        # The collision root is never tilted or moved down.
        if absf(player.position.y)>0.0001:
            _fail("physical collision root was lowered")
            return
        # End-to-end actual world movement in free space: 5m, independent
        # of chosen lock-based pose, including every diagonal.
        game.call("_advance_side_step",float(game.get("step_duration_current")))
        var moved: Vector3=player.position-origin
        if Vector2(moved.x,moved.z).distance_to(expected_world)>0.07:
            _fail("actual displacement not 5m at "+str(i)+": "+str(moved))
            return
        if bool(game.get("step_active")):
            game.call("_finish_side_step",false)
        # The procedural lean/lowering must vanish when STEP ends.
        if bool(rig.get("directional_step_active")):
            _fail("dodge tilt still active after STEP "+str(i))
            return
        var rest_tilt: Quaternion=rig.call("_step_dodge_lean_rotation",1.0)
        if rest_tilt.angle_to(Quaternion.IDENTITY)>0.001:
            _fail("STEP tilt leaked into idle "+str(i))
            return
        rig.set("blending_for",0.16)
        rig.call("_apply_animation",0.0)
        var idle_pose: Dictionary=rig.call("_sample_step_clip_pose","Wait_motion",uid,0.0)
        var idle_height: float=float((bind_positions[uid] as Vector3).y)+float(
            (idle_pose["position"] as Vector3).y)
        if absf(pivot.position.y-idle_height)>0.0002:
            _fail("STEP crouch height not restored to idle "+str(i))
            return

    # A combo side kick is NOT a regular evade: preserve authored 3m and
    # old 10m/s-based 2x animation duration and do not add procedural lean.
    player.position=Vector3(target.position.x,0.0,target.position.z+16.0)
    game.set("energy",100.0)
    game.set("step_kick_side_request",1)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("side-kick fallback unavailable")
        return
    game.set("step_kick_side_request",0)
    if absf(float(game.get("step_arc_length"))-3.0)>0.0001:
        _fail("side kick distance was changed")
        return
    if absf(float(game.get("step_speed_current"))-10.0)>0.0001:
        _fail("side kick animation speed was changed")
        return
    if absf(float(game.get("step_duration_current"))-0.60)>0.0001:
        _fail("side kick original contact timing was changed")
        return
    if (rig.call("_step_dodge_lean_rotation",1.0) as Quaternion).angle_to(
            Quaternion.IDENTITY)>0.001:
        _fail("directional crouch was applied to side-kick clip")
        return
    game.call("_finish_side_step",false)
    print("GODOT_V312_5M_15MPS_LOW_DODGE_ALL_DIRECTIONS_PASS")
    quit(0)

extends SceneTree
## v305: SERA collision root orients toward selected lock part (XZ yaw),
## instant BODY/HEAD switching on first AUTO sample, manual/combo locks intact.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V305_TARGET_FACING_INSTANT_LOCK_FAILED: " + reason)
    quit(1)


func _check_face(player: CharacterBody3D, direction: Vector3, label: String) -> bool:
    direction.y = 0.0
    if direction.length_squared()<0.000001:
        _fail(label+": invalid facing direction")
        return false
    var forward: Vector3 = -player.global_basis.z
    forward.y=0.0
    if forward.normalized().dot(direction.normalized()) < 0.9998:
        _fail(label+": SERA yaw does not point to locked aim")
        return false
    if absf(player.global_basis.y.dot(Vector3.UP)-1.0)>0.0001:
        _fail(label+": SERA pitched/rolled toward a low or high part")
        return false
    return true


func _run() -> void:
    var scene: PackedScene=load("res://scenes/main.tscn")
    if scene==null:
        _fail("scene unavailable")
        return
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get("player")
    var target: Node3D=game.get("target")
    var parts: Node3D=game.get("target_parts")
    var camera: Camera3D=game.get("camera")
    var rig: Node3D=game.get("rig")
    if player==null or target==null or parts==null or camera==null or rig==null:
        _fail("training scene nodes unavailable")
        return
    game.set("target_move_enabled",false)
    game.set("gesture_active",false)
    game.set("running",false)
    game.set("target_hp",500)
    game.set("combat_state",0)
    game.set("bash_followup_window_remaining",0.0)
    game.set("bash_loop_window_remaining",0.0)
    var center: Vector3=target.global_position
    var front: Vector3=center+Vector3(0.0,-1.53,9.0)
    var rear: Vector3=center+Vector3(0.0,-1.53,-9.0)

    # Check the API and the actual physics tick, with a deliberately
    # stale previous ID and an impossibly large old pending timer.
    game.set("auto_lock_enabled",true)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_initialized",true)
    game.set("locked_target_part_id","leg_fl")
    game.set("auto_lock_pending_part","leg_rr")
    game.set("auto_lock_pending_elapsed",80.0)
    player.global_position=front
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("front HEAD did not acquire in first physics frame")
        return
    if str(game.get("auto_lock_pending_part"))!="" or \
            float(game.get("auto_lock_pending_elapsed"))>0.00001:
        _fail("obsolete confirmation timer still advances")
        return
    if not _check_face(player,parts.call("get_part_aim_world","head")-
            player.global_position,"AUTO HEAD"):
        return

    player.global_position=rear
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id"))!="":
        _fail("rear BODY did not acquire immediately after HEAD")
        return
    if not _check_face(player,target.global_position-player.global_position,"AUTO BODY"):
        return
    player.global_position=front
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("BODY->HEAD re-entry waited for another frame")
        return

    # MANUAL selection: all five authored limb points and BODY must drive
    # facing in WAIT, even if lock part lies beside rather than ahead of BODY.
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    player.global_position=center+Vector3(7.0,-1.53,6.0)
    for id in ["","head","leg_fl","leg_fr","leg_rl","leg_rr"]:
        game.set("locked_target_part_id",id)
        game.call("_physics_process",0.016)
        if str(game.get("locked_target_part_id"))!=id:
            _fail("MANUAL lock changed unexpectedly: "+id)
            return
        var point: Vector3=target.global_position if id.is_empty() \
            else parts.call("get_part_aim_world",id)
        var expected: Vector3=point-player.global_position
        expected.y=0.0
        var actual: Vector3=game.call("_locked_target_facing_direction")
        if expected.distance_to(actual)>0.0001:
            _fail("facing API uses BODY instead of selected part "+id)
            return
        if not _check_face(player,expected,"MANUAL "+id):
            return

    # HOLD: even though AUTO now changes immediately, the combo follow-up
    # input window freezes the selected part including just-broken parts.
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_enabled",true)
    player.global_position=rear
    game.set("locked_target_part_id","leg_fl")
    game.set("bash_followup_window_remaining",0.50)
    if not bool(game.call("_combo_lock_retention_active")):
        _fail("combo retention did not activate")
        return
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id"))!="leg_fl":
        _fail("immediate AUTO overrode locked combo part")
        return
    if not _check_face(player,parts.call("get_part_aim_world","leg_fl")-
            player.global_position,"combo held"):
        return
    game.set("bash_followup_window_remaining",0.0)
    game.call("_physics_process",0.016)
    if str(game.get("locked_target_part_id"))!="":
        _fail("AUTO did not resume instantly once combo finished")
        return

    # A camera move alone never affects AUTO selection; broken HEAD is
    # immediately skipped by camera-only dual-ray acquisition.
    player.global_position=front
    game.call("_acquire_stable_camera_part",0.0,false)
    if str(game.get("locked_target_part_id"))!="head":
        _fail("zero delta still introduced a lock delay")
        return
    for shift in [Vector3(10.0,4.0,1.0),Vector3(-8.0,3.0,-1.0)]:
        camera.global_position=center+shift
        camera.look_at(center,Vector3.UP)
        game.call("_acquire_stable_camera_part",0.0,false)
        if str(game.get("locked_target_part_id"))!="head":
            _fail("camera movement changed SERA-origin lock")
            return
    var model: Dictionary=parts.get("parts")
    model["head"]["broken"]=true
    game.call("_acquire_stable_camera_part",0.0,true)
    if str(game.get("locked_target_part_id"))!="":
        _fail("broken HEAD did not immediately fall back to BODY")
        return
    model["head"]["broken"]=false
    if not game.has_method("_switch_lock_screen_direction"):
        _fail("MANUAL lock UI removed")
        return
    print("GODOT_V305_TARGET_FACING_INSTANT_LOCK_PASS")
    quit(0)

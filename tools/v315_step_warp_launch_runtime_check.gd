extends SceneTree
## v315: full 360-degree launch, collision-swept warp, 5m total and 50ms flare.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V315_STEP_WARP_FAILED: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("actors or rig unavailable")
        return
    game.set("target_move_enabled", false)
    game.set("target_hp", 500)
    game.set("auto_lock_enabled", false)
    game.set("manual_part_lock_active", true)
    game.set("locked_target_part_id", "")
    var directions: Array[Vector2] = [
        Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
        Vector2(1,-1).normalized(), Vector2(-1,-1).normalized(),
        Vector2(1,1).normalized(), Vector2(-1,1).normalized()
    ]
    for i in range(directions.size()):
        player.position = target.position + Vector3(0.0, 0.0, 18.0)
        game.set("energy", 100.0)
        game.set("energy_exhausted", false)
        game.set("combat_state", 0)
        game.set("camera_yaw", 0.0)
        game.call("_place_camera")
        var motion: Vector3 = game.call("_screen_drag_to_ground", directions[i])
        var before: Vector3 = player.position
        if not bool(game.call("_start_omni_step", directions[i])):
            _fail("STEP refused at " + str(i))
            return
        var launch: Vector3 = player.position - before
        var unit: Vector2 = Vector2(motion.x, motion.z).normalized()
        if Vector2(launch.x, launch.z).distance_to(unit * 1.0) > 0.07:
            _fail("not a 1m launch: " + str(i) + " " + str(launch))
            return
        if absf(float(game.get("step_arc_length"))-5.0)>0.0001:
            _fail("total planned STEP no longer 5m")
            return
        if absf(float(game.get("step_elapsed")) -
                float(game.get("step_duration_current")) / 5.0)>0.0001:
            _fail("launch not counted in step clock")
            return
        if absf(float(game.get("step_traveled_distance")) - 1.0) > 0.07:
            _fail("launch not counted in traveled distance")
            return
        # Snapshot is still pinned to the original world-space model pose.
        var ages: Array = rig.get("_afterimage_ages")
        var lifetimes: Array = rig.get("_afterimage_lifetimes")
        var last_slot: int = (int(rig.get("_afterimage_next_slot")) + 2) % 3
        if absf(float(lifetimes[last_slot]) - 0.05) > 0.0001 or absf(float(ages[last_slot])) > 0.0001:
            _fail("launch afterimage was not captured for 0.05s")
            return
        var launch_fx: Node3D = game.get_node_or_null("StepLaunchWorldFlare")
        if launch_fx == null or launch_fx.get_child_count() < 2:
            _fail("world-space exhaust meshes not created")
            return
        var fx_position: Vector3 = (launch_fx.get_child(0) as Node3D).global_position
        var snapshot_position: Vector3 = fx_position
        game.call("_advance_side_step", float(game.get("step_duration_current")))
        var final_move: Vector3 = player.position - before
        if Vector2(final_move.x, final_move.z).distance_to(unit * 5.0) > 0.07:
            _fail("instant launch double-counted or snapped back: " + str(i))
            return
        if (launch_fx.get_child(0) as Node3D).global_position.distance_to(snapshot_position) > 0.0001:
            _fail("flare moved with the player")
            return
        await create_timer(0.07).timeout
        if is_instance_valid(launch_fx):
            _fail("old launch flare outlived 0.05s")
            return
        if bool(game.get("step_active")):
            game.call("_finish_side_step", false)

    # Kick follow-up never invokes the ordinary STEP launch.
    player.position = target.position + Vector3(0.0,0.0,18.0)
    game.set("energy",100.0)
    game.set("step_kick_side_request",1)
    var kick_origin: Vector3 = player.position
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("side kick refused")
        return
    if player.position.distance_to(kick_origin) > 0.01:
        _fail("the combo kick was accidentally warped")
        return
    if absf(float(game.get("step_arc_length")) - 3.0) > 0.0001:
        _fail("side kick arc changed")
        return
    game.call("_finish_side_step",false)
    print("GODOT_V315_STEP_1M_LAUNCH_5M_TOTAL_50MS_FX_PASS")
    quit(0)

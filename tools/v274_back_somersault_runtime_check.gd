extends SceneTree
## Actual Godot 4.7 runtime test for screen-down combo, airborne arc, landing.
## v275: the actual authored Kick_b must play instead of the old Jump fallback.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("SERA BACK KICK RUNTIME FAILED: " + message)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene could not be loaded")
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("player/rig initialization failed")
        return
    game.set("gesture_screen_forward", Vector2.UP)
    if int(game.call("_combo_kick_side_for_flick", Vector2.DOWN)) != 2:
        _fail("screen-down flick did not resolve to Kick_b")
        return
    if int(game.call("_combo_kick_side_for_flick", Vector2.RIGHT)) != 1:
        _fail("screen-right lateral kick was changed")
        return
    if int(game.call("_combo_kick_side_for_flick", Vector2.LEFT)) != -1:
        _fail("screen-left lateral kick was changed")
        return
    if not bool(rig.call("has_back_somersault_clip")):
        _fail("authored Kick_b missing or no valid tracks")
        return
    # Spawn just ahead of the target core so the first kick can connect.
    game.set("locked_target_part_id", "")
    game.set("target_hp", 500)
    player.position = Vector3(0.0, 0.0, -5.5)
    var start_position: Vector3 = player.position
    var energy_before: float = float(game.get("energy"))
    if not bool(game.call("_start_back_somersault")):
        _fail("back somersault rejected")
        return
    if not bool(game.get("back_somersault_active")):
        _fail("backflip action did not become active")
        return
    if not bool(rig.call("back_somersault_uses_authored_clip")) or str(rig.get("current_clip")) != "Kick_b":
        _fail("Kick_b API did not start the authored clip")
        return
    if energy_before - float(game.get("energy")) < 14.9:
        _fail("kick did not charge 15 EN")
        return
    var contact_seconds: float = float(game.get("BACK_SOMERSAULT_STRIKE_SECONDS"))
    game.call("_advance_back_somersault", contact_seconds)
    if not bool(game.get("back_somersault_hit")) or not bool(game.get("back_somersault_launched")):
        _fail("rear flight was not armed by actual kick contact")
        return
    if player.position.distance_to(start_position) > 0.01:
        _fail("rearward flight started before the kick hit")
        return
    var flight_half: float = float(game.get("BACK_SOMERSAULT_REAR_FLIGHT_SECONDS")) * 0.5
    game.call("_advance_back_somersault", flight_half)
    var middle: Vector3 = player.position
    if absf(middle.y - 1.5) > 0.15:
        _fail("missing 1.5m parabola apex: " + str(middle.y))
        return
    if absf(middle.z - start_position.z) < 1.5:
        _fail("no rearward displacement at half-time")
        return
    if not bool(rig.call("back_somersault_uses_authored_clip")):
        if absf(absf(rig.rotation.x) - PI) > 0.1:
            _fail("provisional full somersault has not rotated 180 degrees at apex")
            return
    game.call("_advance_back_somersault", flight_half)
    var arrived: Vector3 = player.position
    # v279: 4m travel finishes at 0.8s, but do NOT replace Kick_b before
    # its completed final pose was sampled by the render rig.
    if not bool(game.get("back_somersault_active")) or bool(game.get("landing_active")):
        _fail("Kick_b was cut before its last authored pose was displayed")
        return
    var clip_data: Dictionary = rig.get("animations")
    var source_clip: Dictionary = clip_data["Kick_b"]
    if absf(float(rig.call("get_clip_time")) - float(source_clip["length"])) > 0.00001:
        _fail("Kick_b did not reach its exact final frame")
        return
    if bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("terminal pose acknowledged without a rig render sample")
        return
    # Render the exact terminal pose before advancing the landing state.
    rig.call("_process", 0.06)
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("rendered terminal Kick_b pose was not acknowledged")
        return
    game.call("_advance_back_somersault", 0.016)
    if bool(game.get("back_somersault_active")):
        _fail("flight did not release after the final pose was rendered")
        return
    if not bool(game.get("landing_active")) or not bool(game.get("landing_from_somersault")):
        _fail("authored landing sequence did not start")
    if absf(arrived.y) > 0.001:
        _fail("rear arc did not touch ground at completion")
        return
    if absf(rig.rotation.x) > 0.001:
        _fail("visual somersault pitch was not reset before landing")
        return
    game.call("_advance_landing", 0.19)
    if not bool(game.get("landing_active")):
        _fail("landing ended before 0.2s")
        return
    game.call("_advance_landing", 0.01)
    if bool(game.get("landing_active")):
        _fail("landing did not end at 0.2s")
        return
    if str(rig.get("current_clip")) != "Wait_motion":
        _fail("landing did not blend back to idle")
        return
    print("GODOT_BACK_KICK_RUNTIME_PASS: rear arc, 1.5m apex, 4m plan, 0.8s clip including contact + 0.2s authored landing")
    quit(0)

extends SceneTree
## SERA v279: confirm the actual authored terminal pose is RENDERED before landing.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V279_SOMERSAULT_FINAL_POSE_FAILED: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("main/rig not initialized")
        return
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b refused to start")
        return
    if str(rig.get("current_clip")) != "Kick_b":
        _fail("authored Kick_b missing at start")
        return
    var start: Vector3 = player.position
    game.call("_advance_back_somersault", 0.8)
    var end_position: Vector3 = player.position
    var actual_clip: Dictionary = (rig.get("animations") as Dictionary)["Kick_b"]
    var duration: float = float(actual_clip["length"])
    if absf(float(rig.call("get_clip_time")) - duration) > 0.00001:
        _fail("Kick_b did not reach exact authored terminal time")
        return
    if not bool(game.get("back_somersault_active")) or bool(game.get("landing_active")):
        _fail("the clip was cut before rendering its final frame")
        return
    if bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("completion acknowledged before any render sample")
        return
    if absf(end_position.y) > 0.0001:
        _fail("flight ended above the ground")
        return
    if end_position.distance_to(start) < 2.5:
        _fail("rear flight did not complete the planned displacement")
        return
    # Simulate dropped render frames: many physics ticks must not cause either
    # an early animation switch OR any additional root motion at the endpoint.
    game.call("_advance_back_somersault", 0.2)
    if not bool(game.get("back_somersault_active")) or bool(game.get("landing_active")):
        _fail("unsampled terminal pose lost on additional physics tick")
        return
    if end_position.distance_to(player.position) > 0.00001:
        _fail("rear travel repeated after its 0.8s endpoint")
        return
    rig.call("_process", 0.02)
    if bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("partially blended last pose acknowledged prematurely")
        return
    rig.call("_process", 0.04)
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("unblended terminal authored pose never acknowledged")
        return
    if str(rig.get("current_clip")) != "Kick_b":
        _fail("rendering the final pose switched clips unexpectedly")
        return
    var saved_pose: Dictionary = {}
    var all_bones: Dictionary = rig.get("bones")
    for uid in all_bones.keys():
        var bone: Node3D = all_bones[uid]
        saved_pose[uid] = bone.quaternion
    # The next physics tick is the FIRST valid landing transition.
    game.call("_advance_back_somersault", 0.016)
    if bool(game.get("back_somersault_active")) or not bool(game.get("landing_active")):
        _fail("landing did not start after final pose was displayed")
        return
    if str(rig.get("current_clip")) != "Jump":
        _fail("not playing authored landing sequence")
        return
    if absf(float(rig.get("blend_duration")) - 0.055) > 0.00001:
        _fail("Kick_b-to-landing crossfade missing")
        return
    if end_position.distance_to(player.position) > 0.00001:
        _fail("transition added unwanted world displacement")
        return
    var previous_pose: Dictionary = rig.get("prior_rotations")
    for uid in saved_pose.keys():
        var prior_q: Quaternion = previous_pose[uid]
        var terminal_q: Quaternion = saved_pose[uid]
        if absf(prior_q.dot(terminal_q)) < 0.999999:
            _fail("landing blend did not preserve last Kick_b joint transforms")
            return
    game.call("_advance_landing", 0.19)
    if not bool(game.get("landing_active")):
        _fail("0.2s landing finished early")
        return
    game.call("_advance_landing", 0.01)
    if bool(game.get("landing_active")):
        _fail("0.2s landing did not finish")
        return
    if not bool(game.call("_start_back_somersault")):
        _fail("new Kick_b did not rearm")
        return
    if bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("completion leaked into next kick")
        return
    game.call("_cancel_back_somersault")
    if bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("cancel failed to clear completion")
        return
    # The regular Jump landing remains immediate; only Kick_b has a blend.
    rig.call("start_jump")
    rig.call("start_landing")
    if absf(float(rig.get("blend_duration"))) > 0.000001:
        _fail("ordinary Jump landing transition was modified")
        return
    print("GODOT_V279_SOMERSAULT_COMPLETE_PASS: final pose sampled, 4m/0.8s, 0.2s landing, safe cancel")
    quit(0)

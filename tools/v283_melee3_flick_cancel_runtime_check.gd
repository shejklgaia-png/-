extends SceneTree
## Run real main+rig to verify queued side/back/Bash starts at 0.675s
## and no-queue Melee3 remains locked until its original 0.83333s end.
const CANCEL_TIME: float = 15.0 / 24.0 + 0.05

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V283_MELEE3_FLICK_CANCEL_FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    for mode in ["no_queue", "kick_r", "kick_l", "kick_b", "bash"]:
        var game: Node3D = scene.instantiate()
        root.add_child(game)
        var rig: Node3D = game.get("rig")
        var player: CharacterBody3D = game.get("player")
        var target: Node3D = game.get("target")
        if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
            _fail("main/rig failed to initialize")
            return
        target.position = Vector3.ZERO
        player.position = Vector3(0.0, 0.0, 1.2)
        game.set("target_hp", 0)
        game.set("energy", 100.0)
        game.set("gesture_screen_forward", Vector2.UP)
        if absf(float(game.call("_melee3_flick_cancel_time")) - CANCEL_TIME) > 0.00001:
            _fail("actual Melee3 flick cancel time is not 0.675s")
            return
        game.call("_start_strike", 2)
        if int(game.get("combat_state")) != 3 or str(rig.get("current_clip")) != "Melee3":
            _fail("authored Melee3 did not start")
            return
        game.set("strike_did_hit", true)  # Avoid hit-stop; isolate cancel timing.
        rig.set("clip_time", 0.0)
        if mode == "bash":
            if not bool(game.call("_request_combo_bash")):
                _fail("Bash could not be queued during Melee3")
                return
        elif mode != "no_queue":
            var flick: Vector2 = Vector2.RIGHT if mode == "kick_r" else (
                Vector2.LEFT if mode == "kick_l" else Vector2.DOWN)
            if not bool(game.call("_request_combo_side_kick", flick)):
                _fail("kick request could not be buffered: " + mode)
                return
        rig.set("clip_time", CANCEL_TIME - 0.001)
        game.call("_advance_attack", 0.0)
        if int(game.get("combat_state")) != 3 or str(rig.get("current_clip")) != "Melee3":
            _fail("strike canceled too early: " + mode)
            return
        rig.set("clip_time", CANCEL_TIME + 0.001)
        game.call("_advance_attack", 0.0)
        if mode == "no_queue":
            if int(game.get("combat_state")) != 3:
                _fail("unqueued strike ended at the flick-only cancel point")
                return
            if bool(game.call("_start_attack")):
                _fail("ordinary Melee1 was unlocked 0.05s too early")
                return
            rig.set("clip_time", 0.83333)
            game.call("_advance_attack", 0.0)
            if int(game.get("combat_state")) != 0:
                _fail("unqueued Melee3 did not finish at old clip end")
                return
            if not bool(game.call("_start_attack")):
                _fail("original normal Melee1 input eligibility was lost")
                return
        elif mode == "bash":
            if int(game.get("combat_state")) not in [4, 5]:
                _fail("queued Bash was not triggered at cancel point")
                return
        elif mode == "kick_b":
            if not bool(game.get("back_somersault_active")) and int(game.get("combat_state")) != 7:
                _fail("queued rear Kick_b was not triggered at cancel point")
                return
        else:
            if not bool(game.get("step_active")):
                _fail("queued side kick was not triggered at cancel point: " + mode)
                return
            var expected_clip: String = "Kick_r" if mode == "kick_r" else "Kick_l"
            if str(rig.get("current_clip")) != expected_clip:
                _fail("incorrect kick clip: " + mode)
                return
        game.free()
    # Bash and both lateral kick sectors can reserve input while Melee3
    # is still performing its tracking/windup.
    var track_game: Node3D = scene.instantiate()
    root.add_child(track_game)
    var track_rig: Node3D = track_game.get("rig")
    var track_player: CharacterBody3D = track_game.get("player")
    track_player.position = Vector3(0.0, 0.0, 8.0)
    track_game.call("_start_strike", 2)
    if int(track_game.get("combat_state")) != 6:
        _fail("third strike tracking setup failed")
        return
    if not bool(track_game.call("_request_combo_bash")):
        _fail("Bash cannot buffer in third strike tracking")
        return
    if not bool(track_game.get("bash_queued")):
        _fail("Bash tracking request was not retained")
        return
    track_game.call("_cancel_attack")
    if bool(track_game.get("bash_queued")):
        _fail("interrupted third strike kept its queued Bash")
        return
    track_game.free()
    print("GODOT_V283_MELEE3_FLICK_CANCEL_PASS: 0.675s queued Bash/kicks; unchanged Melee1 restart after 0.83333s")
    quit(0)

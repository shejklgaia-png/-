extends SceneTree
## Exercise the ACTUAL SERA scene, authored kick clips and contact scheduler.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V277_KICK_RUNTIME_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
        _fail("scene actors did not load")
        return
    for side in [1, -1]:
        if not bool(rig.call("has_side_kick", side)):
            _fail("author kick missing")
            return
        target.position = player.position
        game.set("step_kick_side_request", side)
        if not bool(game.call("_start_omni_step", Vector2.RIGHT if side == 1 else Vector2.LEFT)):
            _fail("side kick did not start")
            return
        game.set("step_kick_side_request", 0)
        var expected: String = "Kick_r" if side == 1 else "Kick_l"
        if str(rig.get("current_clip")) != expected:
            _fail("wrong clip " + expected)
            return
        var duration: float = float(game.get("step_duration_current"))
        game.call("_advance_side_step", duration * 0.249)
        if int(game.get("side_kick_hit_mask")) != 0:
            _fail("premature side kick hit")
            return
        target.position = player.position
        game.call("_advance_side_step", duration * 0.002)
        if int(game.get("side_kick_hit_mask")) != 1:
            _fail("first extension missing")
            return
        target.position = player.position
        game.call("_advance_side_step", duration * 0.334)
        if int(game.get("side_kick_hit_mask")) != 3:
            _fail("second extension missing")
            return
        if int(game.get("side_kick_hit_count")) != 2:
            _fail("expected two actual landed contacts")
            return
        target.position = player.position
        game.call("_advance_side_step", duration * 0.10)
        if int(game.get("side_kick_hit_count")) != 2:
            _fail("same foot hit twice")
            return
        game.call("_finish_side_step", false)
    # Bash-like homing and safe timeout of a distant Kick_b.
    target.position = Vector3.ZERO
    player.position = Vector3(0.0, 0.0, 8.0)
    if not bool(game.call("_start_back_kick_track")):
        _fail("Kick_b tracking did not start")
        return
    if int(game.get("combat_state")) != 7:
        _fail("not in BACK_KICK_TRACK")
        return
    var distance_before: float = float(game.call("_distance_to_attack_target_surface", player.position))
    game.call("_advance_attack", 0.10)
    var distance_after: float = float(game.call("_distance_to_attack_target_surface", player.position))
    if distance_after >= distance_before - 0.05:
        _fail("Bash homing did not approach the target")
        return
    game.call("_advance_attack", 0.10)
    if bool(game.get("back_somersault_active")) or int(game.get("combat_state")) != 0:
        _fail("out-of-range tracking did not cancel")
        return
    player.position = target.position + Vector3(0, 0, 1.2)
    if not bool(game.call("_start_back_somersault")):
        _fail("in-range authored somersault rejected")
        return
    if str(rig.get("current_clip")) != "Kick_b":
        _fail("Kick_b source clip not playing")
        return
    game.call("_advance_back_somersault", 0.20)
    if bool(game.get("back_somersault_hit_checked")):
        _fail("premature back kick hit")
        return
    game.call("_advance_back_somersault", 0.02)
    if not bool(game.get("back_somersault_hit_checked")):
        _fail("back kick foot extension not checked")
        return
    game.call("_advance_back_somersault", 0.2)
    if not bool(game.get("back_somersault_hit_checked")):
        _fail("back kick hit slot was rearmed")
        return
    print("GODOT_V277_KICK_RUNTIME_PASS: two side contacts each, one back, Bash homing")
    quit(0)

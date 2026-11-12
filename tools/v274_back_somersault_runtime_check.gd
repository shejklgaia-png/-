extends SceneTree
## Actual Godot 4.7 runtime test for screen-down combo, airborne arc, landing.
## Kick_b original Blockbench keyframes are not on main yet: fallback is tested.
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
    var start_position: Vector3 = player.position
    var energy_before: float = float(game.get("energy"))
    if not bool(game.call("_start_back_somersault")):
        _fail("back somersault rejected")
        return
    if not bool(game.get("back_somersault_active")):
        _fail("backflip action did not become active")
        return
    if energy_before - float(game.get("energy")) < 14.9:
        _fail("kick did not charge 15 EN")
        return
    game.call("_advance_back_somersault", 0.40)
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
    game.call("_advance_back_somersault", 0.40)
    var arrived: Vector3 = player.position
    if bool(game.get("back_somersault_active")):
        _fail("flight did not finish at 0.8s")
        return
    if not bool(game.get("landing_active")) or not bool(game.get("landing_from_somersault")):
        _fail("authored landing sequence did not start")
        return
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
    print("GODOT_BACK_KICK_RUNTIME_PASS: rear arc, 1.5m apex, 4m plan, 0.8s flight + 0.2s authored landing")
    quit(0)

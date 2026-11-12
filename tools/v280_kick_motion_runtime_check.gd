extends SceneTree
## Real-rig regression: Kick_b must turn the WHOLE silhouette even when authored.
## The v278 runtime test independently covers both kicks' delayed lateral STEP.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V280_KICK_MOTION_RUNTIME_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("rig missing")
        return
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b failed to start")
        return
    if not bool(rig.call("back_somersault_uses_authored_clip")):
        _fail("authored Kick_b was not used")
        return
    var resting_y: float = float(game.get("back_somersault_original_rig_y"))
    var initial_collision_basis: Basis = player.transform.basis
    # Rotation is on the visible rig only, not the CharacterBody3D collision.
    game.call("_advance_back_somersault", 0.20)
    if absf(rig.transform.basis.y.z) < 0.90:
        _fail("quarter-flight SERA silhouette has not rotated 90 degrees")
        return
    if absf(rig.position.y - resting_y - 0.90) > 0.03:
        _fail("whole-body rotation pivot compensation missing")
        return
    game.call("_advance_back_somersault", 0.20)
    if rig.transform.basis.y.y > -0.95:
        _fail("authored Kick_b did not turn the whole character upside down")
        return
    if player.transform.basis.y.dot(initial_collision_basis.y) < 0.999:
        _fail("somersault accidentally rotated physics collision")
        return
    game.call("_advance_back_somersault", 0.20)
    if absf(rig.transform.basis.y.z) < 0.90:
        _fail("third-quarter SERA silhouette did not continue rotating")
        return
    game.call("_advance_back_somersault", 0.20)
    if not bool(game.get("back_somersault_active")):
        _fail("authored final pose was interrupted before it was sampled")
        return
    if rig.transform.basis.y.y < 0.99:
        _fail("full visible backflip did not end upright")
        return
    rig.call("_process", 0.06)
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("last authored pose not sampled")
        return
    game.call("_advance_back_somersault", 0.016)
    if not bool(game.get("landing_active")):
        _fail("landing never started after full turn")
        return
    if absf(rig.rotation.x) > 0.0001 or absf(rig.position.y - resting_y) > 0.0001:
        _fail("visual pitch or pivot offset leaked into landing")
        return
    game.call("_advance_landing", 0.20)
    if bool(game.get("landing_active")):
        _fail("0.2s landing was changed")
        return
    # Cancel path also restores rig transform after a partial somersault.
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b cannot restart after landing")
        return
    game.call("_advance_back_somersault", 0.20)
    game.call("_cancel_back_somersault")
    if bool(game.get("back_somersault_active")) or absf(rig.rotation.x) > 0.0001:
        _fail("cancel left visual rotation active")
        return
    if absf(rig.position.y - resting_y) > 0.0001:
        _fail("cancel left rig pivot offset active")
        return
    print("GODOT_V280_KICK_MOTION_PASS: authored Kick_b full rig flip, upright landing and reset")
    quit(0)

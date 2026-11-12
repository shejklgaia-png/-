extends SceneTree
## Full Godot scene test for one continuous Bezier flight and authored landing.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V281_SOMERSAULT_ARC_RUNTIME_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("player or rig missing")
        return
    game.set("locked_target_part_id", "")
    game.set("target_hp", 500)
    player.position = Vector3(0.0, 0.0, -5.5)
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b did not start")
        return
    if str(rig.get("current_clip")) != "Kick_b":
        _fail("authored Kick_b was not preserved")
        return
    var initial_position: Vector3 = player.position
    var strike_seconds: float = 0.80 * (0.20833 / 0.79167)
    game.call("_advance_back_somersault", strike_seconds)
    if not bool(game.get("back_somersault_launched")):
        _fail("no leap after the foot impact key")
        return
    if initial_position.distance_to(player.position) > 0.01:
        _fail("rear travel started during grounded strike")
        return
    var direction: Vector3 = game.get("back_somersault_direction")
    var stages: Array[float] = [0.125, 0.25, 0.5, 0.75, 1.0]
    var prior_time: float = 0.0
    for t in stages:
        # The same Bezier has x=5(3t²-2t³), y=6t(1-t). This makes
        # takeoff/landing tangent vertical, with a symmetric 1.5m peak.
        var expected_distance: float = 5.0 * (3.0 * t * t - 2.0 * t * t * t)
        var expected_height: float = 6.0 * t * (1.0 - t)
        var offset: Vector3 = game.call("_back_somersault_arc_offset", t)
        if absf(offset.dot(direction) - expected_distance) > 0.0005:
            _fail("Bezier XZ displacement mismatch at %s; actual=%.7f expected=%.7f; direction=%s offset=%s" % [str(t),offset.dot(direction),expected_distance,str(direction),str(offset)])
            return
        if absf(offset.y - expected_height) > 0.0005:
            _fail("Bezier height mismatch at " + str(t))
            return
        game.call("_advance_back_somersault", (t - prior_time) * (0.80 - strike_seconds))
        prior_time = t
        var travelled: float = (player.position - initial_position).dot(direction)
        if absf(travelled - expected_distance) > 0.07:
            _fail("physical rear travel diverged from arc at " + str(t))
            return
        if absf(player.position.y - expected_height) > 0.07:
            _fail("physical altitude diverged from arc at " + str(t))
            return
    var beginning: Vector3 = game.call("_back_somersault_arc_offset", 0.01)
    var near_end: Vector3 = game.call("_back_somersault_arc_offset", 0.99)
    if beginning.dot(direction) >= 0.002 or near_end.dot(direction) <= 4.998:
        _fail("launch/landing horizontal velocity is not smoothly eased")
        return
    if not bool(game.get("back_somersault_active")) or bool(game.get("landing_active")):
        _fail("authored final pose was replaced before rendering")
        return
    rig.call("_process", 0.06)
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("author's last keyframe was not displayed")
        return
    game.call("_advance_back_somersault", 0.016)
    if bool(game.get("back_somersault_active")) or not bool(game.get("landing_active")):
        _fail("landing did not follow completed Bezier flight")
        return
    if absf(rig.rotation.x) > 0.0001:
        _fail("full-body rotation leaked into landing")
        return
    game.call("_advance_landing", 0.20)
    if bool(game.get("landing_active")):
        _fail("0.2s landing duration changed")
        return
    print("GODOT_V281_SOMERSAULT_ARC_PASS: symmetric 5m Bezier, 1.5m apex, 0.8s flight, 0.2s landing")
    quit(0)

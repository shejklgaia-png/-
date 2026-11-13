extends SceneTree
## Actual scene collision and animated-sole tests, not a mocked math copy.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V327_COLLISION_LANDING_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var solid: AnimatableBody3D = game.get("target_collider")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or solid == null or rig == null:
        _fail("Main scene nodes missing")
        return
    # Boss bob never moves its physical support surface vertically.
    target.position.y += 0.065
    game.call("_physics_process", 1.0 / 60.0)
    if absf(solid.global_position.y - 1.53) > 0.0001:
        _fail("moving target collider vertically carried its legs")
        return

    player.position = Vector3(0.0, 0.45, 4.0)
    game.set("passive_fall_velocity", 0.0)
    game.call("_resolve_passive_vertical_motion", 1.0 / 60.0, 0.45, false)
    if player.position.y >= 0.45 or player.position.y <= 0.0:
        _fail("elevated idle player did not start descending")
        return
    for i in range(90):
        game.call("_resolve_passive_vertical_motion", 1.0 / 60.0,
            player.position.y, false)
    if absf(player.position.y) > 0.00001 or absf(
            float(game.get("passive_fall_velocity"))) > 0.00001:
        _fail("passive fall did not settle on visual floor")
        return
    player.position.y = 0.0
    game.call("_resolve_passive_vertical_motion", 1.0 / 60.0, 0.18, false)
    if player.position.y < 0.0:
        _fail("passive gravity passed through floor")
        return
    # A committed action has its own Y track and must not be gravity snapped.
    player.position.y = 1.25
    game.call("_resolve_passive_vertical_motion", 0.30, 1.25, true)
    if absf(player.position.y - 1.25) > 0.00001:
        _fail("STEP/MELEE Y ownership was overwritten")
        return
    # Sweep uses physical collisions but cannot ever change the current Y.
    var original_y: float = player.position.y
    game.call("_move_player_swept", Vector3(0.4, 0.0, 0.0), true)
    if absf(player.position.y - original_y) > 0.00001:
        _fail("horizontal attack/step sweep generated vertical displacement")
        return

    player.position.y = 0.0
    var equipment: RefCounted = rig.get("equipment_handler")
    if equipment == null or not bool(rig.call("has_back_somersault_clip")):
        _fail("authored Kick_b/equipment missing")
        return
    rig.call("start_back_somersault")
    var length: float = float((rig.get("animations") as Dictionary)["Kick_b"]["length"])
    rig.set("clip_time", length)
    rig.set("blending_for", rig.get("blend_duration"))
    rig.call("_process", 0.0)
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("Kick_b last authored pose did not render")
        return
    rig.call("start_landing", true)
    if not bool(rig.get("landing_pose_active")):
        _fail("landing did not enable sole contact")
        return
    for fraction in [0.0, 0.25, 0.55, 1.0]:
        rig.call("set_landing_progress", fraction)
        rig.call("_process", 0.016)
        var feet: Dictionary = equipment.call("get_active_foot_heights")
        if not feet.has("L") or not feet.has("R"):
            _fail("selected feet are missing from grounding calculator")
            return
        var lowest: float = minf(float(feet["L"]), float(feet["R"]))
        var sole_world: float = rig.to_global(Vector3(0.0, lowest, 0.0)).y
        if absf(sole_world + 0.0335) > 0.002:
            _fail("Kick_b landing sole is not on visible floor: " + str(sole_world))
            return
    rig.call("finish_jump", false, false)
    if bool(rig.get("landing_pose_active")):
        _fail("landing sole override persisted after exit")
        return
    print("PASS v327 enemy collider, passive gravity, flight exemption, planted Kick_b landing")
    game.queue_free()
    await process_frame
    quit(0)

extends SceneTree
## Godot regression for actor facing and grounded-contact Kick_b.
const HIT_TIME: float = 0.80 * (0.20833 / 0.79167)
const FLIGHT_TIME: float = 0.80 - HIT_TIME

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V284_CARDINAL_MELEE_CONTACT_FAILED: " + message)
    quit(1)


func _spawn() -> Node3D:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    game.set("locked_target_part_id", "")
    player.position = Vector3(0.0, 0.0, -5.0)
    game.set("energy", 100.0)
    return game


func _run() -> void:
    var game: Node3D = _spawn()
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("scene or model not loaded")
        return
    for front in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
        game.set("gesture_screen_forward", front)
        var actor_right: Vector2 = Vector2(-front.y, front.x)
        for heading in [[front, 0], [actor_right, 1],
                [-front, 2], [-actor_right, -1]]:
            if int(game.call("_combo_kick_side_for_flick", heading[0])) != int(heading[1]):
                _fail("projected SERA-forward kick quadrant incorrect")
                return
        if not bool(game.call("_is_character_forward_flick", front * 70.0, 0.2)):
            _fail("SERA-forward Bash did not accept flick")
            return
        if bool(game.call("_is_character_forward_flick", -front * 70.0, 0.2)):
            _fail("SERA-backward was mistaken for Bash")
            return
    if absf(float(game.call("_melee3_flick_cancel_time")) - 0.675) > 0.00001:
        _fail("finisher cancel is not 50ms after the authored stroke")
        return

    game.set("target_hp", 500)
    var start: Vector3 = player.position
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b failed to start")
        return
    game.call("_advance_back_somersault", HIT_TIME * 0.5)
    var preimpact_retreat: Vector3 = game.get("back_somersault_direction")
    if bool(game.get("back_somersault_launched")) \
            or (player.position - start).dot(preimpact_retreat) > 0.03:
        _fail("rear jump started before the kick made contact")
        return
    if str(rig.get("current_clip")) != "Kick_b":
        _fail("original Kick_b was not playing before hit")
        return
    game.call("_advance_back_somersault", HIT_TIME * 0.5)
    if not bool(game.get("back_somersault_hit_checked")):
        _fail("authored hit frame was skipped")
        return
    if not bool(game.get("back_somersault_hit")) or not bool(game.get("back_somersault_launched")):
        _fail("successful foot contact did not trigger rear takeoff")
        return
    var takeoff: Vector3 = player.position
    var before_retreat: Vector3 = game.get("back_somersault_direction")
    if (takeoff - start).dot(before_retreat) > 0.03:
        _fail("hit triggered rear movement before takeoff")
        return
    var back: Vector3 = game.get("back_somersault_direction")
    target.position.z -= 6.0  # homing must NOT resume after impact
    game.call("_advance_back_somersault", FLIGHT_TIME * 0.5)
    if absf(player.position.y - 1.5) > 0.10:
        _fail("flight did not reach 1.5m apex")
        return
    var terminal_control: float = 5.0 - 0.30 * FLIGHT_TIME / 0.20
    var expected_halfway: float = 0.375 * terminal_control + 0.625
    if absf((player.position - takeoff).dot(back) - expected_halfway) > 0.12:
        _fail("flight is not midway through the 5m Bezier retreat")
        return
    game.call("_advance_back_somersault", FLIGHT_TIME * 0.5)
    if absf((player.position - takeoff).dot(back) - 5.0) > 0.12:
        _fail("rear retreat did not finish 5m from impact")
        return
    if not bool(game.get("back_somersault_active")):
        _fail("authored final pose was cut before render")
        return
    rig.call("_process", 0.07)
    game.call("_advance_back_somersault", 0.016)
    if not bool(game.get("landing_active")):
        _fail("landed flight did not enter the 0.2s landing")
        return
    game.call("_advance_landing", 0.20)

    # Confirm the animation's grounded windup still uses the normal
    # target-following acceleration while out of contact range.
    var chase_game: Node3D = _spawn()
    var chase_player: CharacterBody3D = chase_game.get("player")
    var chase_target: Node3D = chase_game.get("target")
    chase_game.set("target_hp", 500)
    chase_player.position = Vector3(0.0, 0.0, -3.5)
    var chase_before: float = chase_player.position.distance_to(chase_target.position)
    if not bool(chase_game.call("_start_back_somersault")):
        _fail("grounded homing test could not begin Kick_b")
        return
    chase_game.call("_advance_back_somersault", 0.06)
    var chase_after: float = chase_player.position.distance_to(chase_target.position)
    if chase_after >= chase_before - 0.05:
        _fail("Kick_b did not home during its pre-impact animation")
        return
    if bool(chase_game.get("back_somersault_launched")):
        _fail("Kick_b launched during the pre-impact chase")
        return
    chase_game.call("_cancel_back_somersault")

    var miss_game: Node3D = _spawn()
    var miss_player: CharacterBody3D = miss_game.get("player")
    var miss_rig: Node3D = miss_game.get("rig")
    # A KO target can now be hit. Force a genuinely out-of-range miss and
    # disable pursuit only within this negative-contact test fixture.
    miss_game.set("target_hp", 0)
    miss_player.position = Vector3(0.0, 0.0, 30.0)
    var miss_stats: Dictionary = miss_game.get("part_stats")
    miss_stats["melee_boost_speed"] = 0.0
    miss_game.set("part_stats", miss_stats)
    var miss_start: Vector3 = miss_player.position
    if not bool(miss_game.call("_start_back_somersault")):
        _fail("miss test could not start Kick_b")
        return
    miss_game.call("_advance_back_somersault", 0.80)
    if bool(miss_game.get("back_somersault_launched")):
        _fail("missed attack still launched a rear jump")
        return
    if miss_player.position.distance_to(miss_start) > 0.03:
        _fail("missed Kick_b displaced the player")
        return
    miss_rig.call("_process", 0.07)
    miss_game.call("_advance_back_somersault", 0.016)
    if bool(miss_game.get("landing_active")) or bool(miss_game.get("back_somersault_active")):
        _fail("missed Kick_b incorrectly entered airborne landing or stayed locked")
        return
    print("GODOT_V284_CARDINAL_MELEE_CONTACT_PASS: screen cardinal, 0.675s cancel, hit-only homing-to-arc and miss cleanup")
    quit(0)

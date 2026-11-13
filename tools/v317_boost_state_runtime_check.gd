extends SceneTree
## Real training-scene regression for v317 RUN/BOOST state extraction.
const BOOST_STATE = preload("res://scripts/sera_boost_state.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BOOST_STATE_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene unavailable")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var constants: Dictionary = game.get_script().get_script_constant_map()
    var radius: float = float(constants["DRAG_RADIUS"])
    var entry: float = float(constants["BOOST_START_RADIUS_RATIO"])
    var exit_ratio: float = float(constants["BOOST_EXIT_RADIUS_RATIO"])
    var confirm: float = float(constants["BOOST_CONFIRM_SECONDS"])
    var blend: float = float(constants["BOOST_SPEED_BLEND_SECONDS"])
    if absf(blend - 0.20) > 0.000001 or entry <= exit_ratio:
        _fail("BOOST duration/hysteresis baseline changed")
        return

    # Pure threshold contract: threshold must confirm, hold in hysteresis,
    # clear on exit, and reject negative confirmation time.
    var trial: Dictionary = BOOST_STATE.next_gesture_state(
        false, 0.0, radius * entry, confirm * 0.6, radius,
        entry, exit_ratio, confirm)
    if bool(trial["active"]):
        _fail("BOOST started before confirmation")
        return
    trial = BOOST_STATE.next_gesture_state(
        bool(trial["active"]), float(trial["confirmation_elapsed"]),
        radius * entry, confirm * 0.5, radius, entry, exit_ratio, confirm)
    if not bool(trial["active"]):
        _fail("BOOST did not begin after confirmation")
        return
    trial = BOOST_STATE.next_gesture_state(
        true, confirm, radius * (exit_ratio + entry) * 0.5, 0.2,
        radius, entry, exit_ratio, confirm)
    if not bool(trial["active"]):
        _fail("hysteresis did not hold BOOST")
        return
    trial = BOOST_STATE.next_gesture_state(
        true, confirm, radius * (exit_ratio - 0.01), 0.016,
        radius, entry, exit_ratio, confirm)
    if bool(trial["active"]) or float(trial["confirmation_elapsed"]) != 0.0:
        _fail("BOOST exit did not clear confirmation")
        return

    # Actual main.gd gesture wrapper owns pointer state and UI transition.
    game.set("gesture_active", true)
    game.set("damage_reaction_active", false)
    game.set("guard_active", false)
    game.set("energy_exhausted", false)
    game.set("bash_flick_candidate", false)
    game.set("side_kick_flick_candidate", false)
    game.set("jump_active", false)
    game.set("landing_active", false)
    game.set("back_somersault_active", false)
    game.set("pointer_origin", Vector2(200.0, 400.0))
    game.set("pointer_location", Vector2(200.0 + radius * (entry + 0.02), 400.0))
    game.set("movement_boost_active", false)
    game.set("boost_confirm_elapsed", 0.0)
    game.set("boost_has_activated_this_gesture", false)
    game.call("_update_boost_gesture", confirm * 0.6)
    if bool(game.get("movement_boost_active")):
        _fail("main BOOST began early")
        return
    game.call("_update_boost_gesture", confirm * 0.5)
    if not bool(game.get("movement_boost_active")) or not bool(game.get("boost_has_activated_this_gesture")):
        _fail("main BOOST did not activate after confirmation")
        return
    game.set("pointer_location", Vector2(200.0 + radius * (exit_ratio + 0.01), 400.0))
    game.call("_update_boost_gesture", 0.016)
    if not bool(game.get("movement_boost_active")):
        _fail("main BOOST fell out inside hysteresis")
        return
    game.set("energy_exhausted", true)
    game.call("_update_boost_gesture", 0.016)
    if bool(game.get("movement_boost_active")) or float(game.get("boost_confirm_elapsed")) != 0.0:
        _fail("energy eligibility did not end BOOST")
        return
    game.set("energy_exhausted", false)

    # The 0.20s smoothstep and mid-transition reversal must not snap.
    var reset: Dictionary = BOOST_STATE.reset_speed_state(blend)
    if absf(float(reset["multiplier"]) - 1.0) > 0.000001 or absf(float(reset["elapsed"]) - blend) > 0.000001:
        _fail("speed reset contract changed")
        return
    var direct: Dictionary = BOOST_STATE.next_speed_state(
        1.0, 1.0, 1.0, blend, 1.5, blend * 0.5, blend)
    if absf(float(direct["multiplier"]) - 1.25) > 0.000001:
        _fail("smoothstep midpoint changed")
        return
    game.call("_reset_boost_speed_transition")
    game.set("movement_boost_active", true)
    game.call("_update_boost_speed", blend * 0.4)
    var before: float = float(game.get("boost_speed_multiplier"))
    if before <= 1.0:
        _fail("BOOST speed did not accelerate")
        return
    game.set("movement_boost_active", false)
    game.call("_update_boost_speed", 0.0)
    var after: float = float(game.get("boost_speed_multiplier"))
    if absf(before - after) > 0.000001 or absf(float(game.get("boost_speed_transition_start")) - before) > 0.000001:
        _fail("mid-blend reversal snapped to endpoint")
        return
    for i in range(20):
        game.call("_update_boost_speed", blend / 20.0)
    if absf(float(game.get("boost_speed_multiplier")) - 1.0) > 0.000001:
        _fail("RUN speed did not settle")
        return
    game.call("_reset_boost_speed_transition")
    if absf(float(game.get("boost_speed_multiplier")) - 1.0) > 0.000001:
        _fail("main reset no longer returns to RUN speed")
        return
    print("SERA_BOOST_STATE_RUNTIME_PASS: gesture hysteresis, energy gate, smoothstep reversal")
    quit(0)

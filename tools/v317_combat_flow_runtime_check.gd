extends SceneTree
## Headless real-scene regression of side-effect-free combat state decisions.
const FLOW = preload("res://scripts/sera_combat_flow.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_COMBAT_FLOW_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var states: Dictionary = game.get_script().get_script_constant_map().get(
        "CombatState", {})
    if not states.has("IDLE") or not states.has("STRIKE"):
        _fail("combat state enum lost")
        return
    var idle: int = int(states["IDLE"])
    var strike: int = int(states["STRIKE"])

    if not FLOW.followup_window_open(0.0, 0.3) \
            or not FLOW.followup_window_open(0.1, 0.0) \
            or FLOW.followup_window_open(0.0, 0.0):
        _fail("combo follow-up time windows changed")
        return
    if not FLOW.combo_retains_lock(false, false, false, true, false) \
            or not FLOW.combo_retains_lock(false, false, false, false, true) \
            or FLOW.combo_retains_lock(false, false, false, false, false):
        _fail("part-lock retention rule changed")
        return
    game.set("combat_state", idle)
    game.set("side_kick_active", false)
    game.set("back_somersault_active", false)
    game.set("landing_active", false)
    game.set("landing_from_somersault", false)
    game.set("bash_followup_window_remaining", 0.0)
    game.set("bash_loop_window_remaining", 0.0)
    if bool(game.call("_combo_lock_retention_active")):
        _fail("IDLE unexpectedly retains lock")
        return
    game.set("bash_followup_window_remaining", 0.25)
    if not bool(game.call("_combo_followup_input_window_open")) \
            or not bool(game.call("_combo_lock_retention_active")):
        _fail("post-finisher IDLE no longer retains lock")
        return
    game.set("bash_followup_window_remaining", 0.0)
    game.set("side_kick_active", true)
    if not bool(game.call("_combo_lock_retention_active")):
        _fail("side kick no longer retains lock")
        return
    game.set("side_kick_active", false)
    game.set("combat_state", strike)
    if not bool(game.call("_combo_lock_retention_active")):
        _fail("active strike no longer retains lock")
        return
    game.set("combat_state", idle)

    # The actual selected weapon determines whether the combo has two or
    # three stages, without modifying any equipment/animation assets.
    var katana: bool = bool(game.call("_katana_equipped"))
    var stage_count: int = int(game.call("_strike_stage_count"))
    if stage_count != FLOW.strike_stage_count(katana, 3) \
            or FLOW.strike_stage_count(true, 3) != 2 \
            or FLOW.strike_stage_count(false, 3) != 3:
        _fail("katana/normal combo stage count changed")
        return
    for stage in range(stage_count):
        game.set("strike_index", stage)
        if bool(game.call("_is_strike_finisher")) != (stage == stage_count - 1):
            _fail("finisher stage changed: " + str(stage))
            return
        var expected_clip: String = FLOW.active_strike_clip(
            stage, katana, "Melee_katana", "Melee_katana2",
            ["melee1", "Melee2", "Melee3"])
        if str(game.call("_active_strike_clip", stage)) != expected_clip:
            _fail("authored clip selection changed: " + str(stage))
            return

    var cancel_times: Array = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]
    for stage in range(stage_count):
        var expected_time: float = FLOW.strike_cancel_time(
            stage, katana, cancel_times)
        if absf(float(game.call("_strike_cancel_time", stage)) - expected_time) > 0.000001:
            _fail("strike cancel gate changed")
            return
    var flick_expected: float = FLOW.melee3_flick_cancel_time(
        katana, cancel_times, 3, 0.05)
    if absf(float(game.call("_melee3_flick_cancel_time")) - flick_expected) > 0.000001:
        _fail("Melee3/Katana flick cancel timing changed")
        return

    for sample in [
        Vector3(0.3, 0.0, 0.8), Vector3(-0.1, 0.4, 0.8),
        Vector3(0.5, 0.8, 1.0), Vector3(0.5, 1.4, 1.0),
    ]:
        var actual: float = FLOW.tracking_slice(sample.x, sample.y, sample.z)
        var expected: float = minf(maxf(0.0, sample.x),
            maxf(0.0, sample.z - sample.y))
        if absf(actual - expected) > 0.000001:
            _fail("approach/homing time cap changed")
            return

    game.set("combat_state", idle)
    game.set("step_active", true)
    if bool(game.call("_guard_can_start")):
        _fail("guard started during STEP")
        return
    game.set("step_active", false)
    game.set("combat_state", strike)
    if bool(game.call("_guard_can_start")):
        _fail("guard started during STRIKE")
        return
    if FLOW.guard_can_start(false, false, 0.0, false, 0.0,
            false, false, false, false, true, true) != true:
        _fail("eligible guard unexpectedly blocked")
        return
    if FLOW.guard_can_start(false, false, 0.0, true, 0.0,
            false, false, false, false, true, true):
        _fail("exhausted energy shield guard not blocked")
        return
    print("SERA_COMBAT_FLOW_RUNTIME_PASS: combo, lock, cancels, homing, guard")
    quit(0)

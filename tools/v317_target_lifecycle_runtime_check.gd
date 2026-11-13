extends SceneTree
## Stage9: real Godot scene confirms enemy movement/fire gates and shared reset.
const POLICY = preload("res://scripts/sera_target_lifecycle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_TARGET_LIFECYCLE_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) < 0.00004

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var c: Dictionary = game.get_script().get_script_constant_map()
    var states: Dictionary = c.get("CombatState", {})
    var parts: Node3D = game.get("target_parts")
    var shooter: Node3D = game.get("enemy_shooter")
    var target: Node3D = game.get("target")
    if parts == null or shooter == null or target == null \
            or not states.has("IDLE") or not states.has("STRIKE"):
        _fail("training target, shooter, or combat enum unavailable")
        return

    # Movement waits for warnings, stun, break, down and player KO.
    if POLICY.movement_frozen(true, false, 500, 0.0, 0.0, 0.0, 0.0):
        _fail("healthy target should move")
        return
    for condition in range(7):
        var move_allowed: bool = condition != 0
        var warning: bool = condition == 1
        var hp: int = 0 if condition == 2 else 500
        var stagger: float = 0.2 if condition == 3 else 0.0
        var broken: float = 0.2 if condition == 4 else 0.0
        var down: float = 0.2 if condition == 5 else 0.0
        var ko: float = 0.2 if condition == 6 else 0.0
        if not POLICY.movement_frozen(move_allowed, warning, hp, stagger, broken, down, ko):
            _fail("target failed to freeze for condition " + str(condition))
            return
    game.set("target_move_enabled", false)
    var before: Vector3 = target.position
    game.call("_advance_target_motion", 0.1)
    if target.position.distance_to(before) > 0.00001:
        _fail("live target ignored HOLD movement setting")
        return
    game.set("target_move_enabled", true)

    # Shooting gate differs from movement: do not add down/KO/telegraph flags.
    if not POLICY.fire_allowed(500, 800.0, 0.0, 0.0) \
            or POLICY.fire_allowed(0, 800.0, 0.0, 0.0) \
            or POLICY.fire_allowed(500, 0.0, 0.0, 0.0) \
            or POLICY.fire_allowed(500, 800.0, 0.1, 0.0) \
            or POLICY.fire_allowed(500, 800.0, 0.0, 0.1):
        _fail("enemy shooting gate changed")
        return
    game.set("player_hp", 800.0)
    game.set("target_hp", 500)
    game.set("stagger_remaining", 0.0)
    game.set("part_break_remaining", 0.0)
    game.call("_update_enemy_fire_eligibility")
    if not bool(shooter.get("can_fire")):
        _fail("healthy enemy cannot fire")
        return
    game.set("stagger_remaining", 0.2)
    game.call("_update_enemy_fire_eligibility")
    if bool(shooter.get("can_fire")):
        _fail("staggered enemy can fire")
        return
    game.set("stagger_remaining", 0.0)
    game.set("target_hp", 0)
    game.call("_update_enemy_fire_eligibility")
    if bool(shooter.get("can_fire")):
        _fail("dead enemy can fire")
        return

    # Scene state must be reset only once; never reset a pre-expired timer.
    game.set("auto_lock_enabled", true)
    game.set("auto_lock_initialized", true)
    game.set("locked_target_part_id", "head")
    game.set("auto_lock_pending_part", "leg_fl")
    game.set("auto_lock_pending_elapsed", 0.4)
    game.set("manual_part_lock_active", true)
    game.set("stagger_value", 34.0)
    game.set("stagger_remaining", 0.4)
    game.set("part_break_remaining", 1.4)
    parts.call("apply_part_hit", "head", 4.0, 200.0)
    shooter.call("set_head_destroyed", true)
    if bool(parts.call("is_targetable", "head")) or not bool(shooter.get("head_destroyed")):
        _fail("broken-head test setup failed")
        return
    game.set("target_respawn_remaining", 0.0)
    game.call("_tick_target_respawn", 0.05)
    if not bool(shooter.get("head_destroyed")) or int(game.get("target_hp")) != 0:
        _fail("already expired idle timer reset boss again")
        return

    # A running timer does not reset the broken part, even in a STRIKE.
    game.set("target_respawn_remaining", 0.50)
    game.set("combat_state", int(states["STRIKE"]))
    game.call("_tick_target_respawn", 0.10)
    if not _near(float(game.get("target_respawn_remaining")), 0.40) \
            or int(game.get("target_hp")) != 0 \
            or bool(parts.call("is_targetable", "head")):
        _fail("premature respawn before countdown expiry")
        return
    game.call("_advance_hit_fx", 0.50)
    if not _near(float(game.get("target_respawn_remaining")), 0.01) \
            or int(game.get("target_hp")) != 0 \
            or not bool(shooter.get("head_destroyed")) \
            or str(game.get("locked_target_part_id")) != "head":
        _fail("respawn erased held broken-part lock")
        return
    # The 10ms retry repeats while the full attack and link window remain.
    game.call("_advance_hit_fx", 0.02)
    if not _near(float(game.get("target_respawn_remaining")), 0.01):
        _fail("respawn retry was not retained through strike")
        return
    game.set("combat_state", int(states["IDLE"]))
    game.set("bash_followup_window_remaining", 0.0)
    game.set("bash_loop_window_remaining", 0.0)
    game.set("side_kick_active", false)
    game.set("back_somersault_active", false)
    game.set("landing_active", false)
    game.call("_advance_hit_fx", 0.02)
    if int(game.get("target_hp")) != int(c["TARGET_MAX_HP"]) \
            or not _near(float(game.get("target_respawn_remaining")), 0.0) \
            or not bool(parts.call("is_targetable", "head")) \
            or bool(shooter.get("head_destroyed")) \
            or not str(game.get("locked_target_part_id")).is_empty() \
            or bool(game.get("auto_lock_initialized")) \
            or str(game.get("auto_lock_pending_part")) != "" \
            or not _near(float(game.get("auto_lock_pending_elapsed")), 0.0) \
            or bool(game.get("manual_part_lock_active")) \
            or not _near(float(game.get("stagger_value")), 0.0) \
            or not _near(float(game.get("part_break_remaining")), 0.0):
        _fail("post-combo respawn did not reset enemy, lock and parts")
        return

    # Training KO uses the SAME boss-reset routine, but also teleports.
    game.set("auto_lock_enabled", false)
    game.set("auto_lock_initialized", true)
    game.set("manual_part_lock_active", false)
    game.set("locked_target_part_id", "leg_fr")
    game.set("target_hp", 0)
    game.set("target_respawn_remaining", 0.6)
    game.set("training_ko_remaining", 0.01)
    shooter.call("set_head_destroyed", true)
    game.call("_tick_training_ko", 0.02)
    if int(game.get("target_hp")) != int(c["TARGET_MAX_HP"]) \
            or not _near(float(game.get("target_respawn_remaining")), 0.0) \
            or not str(game.get("locked_target_part_id")).is_empty() \
            or not bool(game.get("manual_part_lock_active")) \
            or bool(shooter.get("head_destroyed")) \
            or not _near(float(game.get("training_ko_remaining")), 0.0):
        _fail("KO recovery no longer uses canonical boss reset")
        return
    print("SERA_TARGET_LIFECYCLE_RUNTIME_PASS: motion, fire, combo retry, reset, KO")
    quit(0)

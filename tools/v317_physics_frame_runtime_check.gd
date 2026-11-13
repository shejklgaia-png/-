extends SceneTree
## Stage10: real Godot scene and pure movement/effect state decisions.
const FRAME = preload("res://scripts/sera_physics_frame_rules.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_PHYSICS_FRAME_RUNTIME_FAIL: " + message)
    quit(1)

func _near(actual: float, expected: float) -> bool:
    return absf(actual - expected) < 0.000001

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene unavailable")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var constants: Dictionary = game.get_script().get_script_constant_map()
    var idle: int = int(constants.get("CombatState", {})["IDLE"])
    var grace: float = float(constants["BOOST_POSE_GRACE_SECONDS"])
    if not _near(grace, 0.50):
        _fail("BOOST pose hold duration changed")
        return

    # Visual pose grace activates while held and expires independently of
    # movement speed. A guard, damage or touch release cancels immediately.
    game.set("combat_state", idle)
    game.set("gesture_active", true)
    game.set("guard_active", false)
    game.set("damage_reaction_active", false)
    game.set("jump_active", false)
    game.set("landing_active", false)
    game.set("step_active", false)
    game.set("back_somersault_active", false)
    game.set("movement_boost_active", true)
    game.set("boost_pose_grace_remaining", 0.0)
    game.call("_tick_boost_pose_grace", 0.10)
    if not _near(float(game.get("boost_pose_grace_remaining")), grace):
        _fail("active BOOST failed to refresh pose grace")
        return
    game.set("movement_boost_active", false)
    game.call("_tick_boost_pose_grace", 0.12)
    if not _near(float(game.get("boost_pose_grace_remaining")), grace - 0.12):
        _fail("BOOST grace did not decay")
        return
    game.set("guard_active", true)
    game.call("_tick_boost_pose_grace", 0.01)
    if not _near(float(game.get("boost_pose_grace_remaining")), 0.0):
        _fail("guard failed to interrupt BOOST pose hold")
        return
    game.set("guard_active", false)
    game.set("movement_boost_active", true)
    game.call("_tick_boost_pose_grace", 0.01)
    game.set("gesture_active", false)
    game.call("_tick_boost_pose_grace", 0.01)
    if not _near(float(game.get("boost_pose_grace_remaining")), 0.0):
        _fail("finger release did not cancel pose hold")
        return
    if not _near(FRAME.next_boost_pose_grace(0.4, 0.1, grace, true,
            false, false, false, false, false, false, true, false), 0.3) \
            or not _near(FRAME.next_boost_pose_grace(0.4, 0.5, grace, true,
            false, false, false, false, false, false, true, false), 0.0) \
            or not _near(FRAME.next_boost_pose_grace(0.4, 0.01, grace, true,
            false, true, false, false, false, false, true, false), 0.0):
        _fail("pure pose grace gate, clamp or damage cancellation changed")
        return

    # Flight owns displacement on its starting and ending snapshots.
    if not FRAME.flight_owns_displacement(true, false, false, false, false) \
            or not FRAME.flight_owns_displacement(false, true, false, false, false) \
            or not FRAME.flight_owns_displacement(false, false, true, false, false) \
            or not FRAME.flight_owns_displacement(false, false, false, true, false) \
            or not FRAME.flight_owns_displacement(false, false, false, false, true) \
            or FRAME.flight_owns_displacement(false, false, false, false, false):
        _fail("committed flight ownership changed")
        return
    var current: Vector3 = Vector3(5.0, 3.0, -2.0)
    var last: Vector3 = Vector3(4.0, 4.0, -6.0)
    if FRAME.displacement_velocity(current, last, 0.2).distance_to(
            Vector3(5.0, -5.0, 20.0)) > 0.000001 \
            or FRAME.displacement_velocity(current, last, 0.000001) != Vector3.ZERO:
        _fail("collision-resolved velocity/zero-delta guard changed")
        return

    # Normal melee retains exhaust without motion. Safety gates still apply
    # during damage, guard, jump, landing or EN exhaustion.
    if not FRAME.exhaust_allowed(false, false, false, false, false,
            false, false, false, false, true):
        _fail("stationary melee follow-through lost exhaust")
        return
    for blocker in range(5):
        if FRAME.exhaust_allowed(blocker == 0, blocker == 1,
                blocker == 2, blocker == 3, blocker == 4,
                true, false, false, false, false):
            _fail("unsafe exhaust permitted: " + str(blocker))
            return
    if FRAME.exhaust_allowed(false, false, false, false, false,
            false, false, false, false, false):
        _fail("idle engine emits exhaust")
        return

    # A burst requires a new STEP, backflip launch, or MOVING tracking
    # phase. Ordinary stationary swing has no new acceleration burst.
    if not FRAME.acceleration_burst(true, true, false, false, -1, -1) \
            or FRAME.acceleration_burst(true, true, true, false, -1, -1) \
            or not FRAME.acceleration_burst(true, false, false, true, -1, -1) \
            or not FRAME.acceleration_burst(true, false, false, false, 3, 2) \
            or FRAME.acceleration_burst(true, false, false, false, 3, 3) \
            or FRAME.acceleration_burst(true, false, false, false, -1, -1) \
            or FRAME.acceleration_burst(false, true, false, true, 3, 2):
        _fail("acceleration burst exclusivity changed")
        return
    print("SERA_PHYSICS_FRAME_RUNTIME_PASS: pose hold, flight, velocity, exhaust, burst")
    quit(0)

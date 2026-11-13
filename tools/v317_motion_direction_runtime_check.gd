extends SceneTree
## Real Godot scene: pure local run heading and exhaust direction priorities.
const MOTION = preload("res://scripts/sera_motion_direction.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_MOTION_DIRECTION_RUNTIME_FAIL: " + message)
    quit(1)

func _near(actual: Vector3, expected: Vector3) -> bool:
    return actual.distance_to(expected) < 0.00001

func _near2(actual: Vector2, expected: Vector2) -> bool:
    return actual.distance_to(expected) < 0.00001

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    if player == null or game.get("rig") == null:
        _fail("player or rig missing")
        return
    var target_facing: Vector3 = Vector3(0.0, 0.0, -3.0)
    var back: Vector3 = Vector3(0.0, 0.0, 1.0)
    if not _near2(MOTION.local_run_direction(
            Vector3(0.0, 0.0, -0.5), target_facing, -back), Vector2(0.0, 0.5)) \
            or not _near2(MOTION.local_run_direction(
            Vector3.RIGHT, target_facing, -back), Vector2.RIGHT) \
            or not _near2(MOTION.local_run_direction(
            Vector3(0.0, 0.0, -1.0), Vector3.ZERO, -back), Vector2(0.0, 1.0)):
        _fail("target-relative RUN pose orientation/fallback/analog amount changed")
        return
    var move: Vector3 = game.call("_screen_drag_to_ground", Vector2(0.7, -0.3))
    var facing: Vector3 = game.call("_locked_target_facing_direction")
    var local: Vector2 = MOTION.local_run_direction(move, facing,
        -player.global_transform.basis.z)
    var actual_facing: Vector3 = facing if facing.length_squared() >= 0.000001 \
        else -player.global_transform.basis.z
    actual_facing = actual_facing.normalized()
    var expected: Vector2 = Vector2(
        move.dot(actual_facing.cross(Vector3.UP)), move.dot(actual_facing))
    if not _near2(local, expected):
        _fail("scene camera/locked target relative RUN heading differs")
        return

    # Ordinary measured movement and Y suppression.
    var raw: Vector3 = MOTION.exhaust_direction(
        Vector3(3.0, 1.5, -2.0), false, true, Vector3.ZERO,
        Vector3.ZERO, false, false, Vector3.ZERO,
        false, false, false, back)
    if not _near(raw, Vector3(-3.0, 0.0, 2.0)):
        _fail("measured movement exhaust no longer points backward")
        return
    # Live thumb wins over collision-blocked velocity; neutral thumb uses
    # the cached direction from the last BOOST frame.
    if not _near(MOTION.exhaust_direction(
            Vector3.ZERO, true, true, Vector3(0.0, 0.0, -1.0),
            Vector3.RIGHT, false, false, Vector3.ZERO,
            false, false, false, back), back) \
            or not _near(MOTION.exhaust_direction(
            Vector3.ZERO, true, false, Vector3.ZERO,
            Vector3.RIGHT, false, false, Vector3.ZERO,
            false, false, false, back), Vector3.RIGHT):
        _fail("BOOST request and neutral cached heading priority changed")
        return
    # Under a still-running but zero-length intent, the cache must NOT be
    # selected by an elif. The measured heading (then rear fallback) wins.
    if not _near(MOTION.exhaust_direction(
            Vector3(2.0, 0.0, 0.0), true, true, Vector3.ZERO,
            Vector3.RIGHT, false, false, Vector3.ZERO,
            false, false, false, back), Vector3(-2.0, 0.0, 0.0)):
        _fail("zero BOOST request wrongly selected cached heading")
        return
    # Somersault overrides BOOST steering; static melee follow-through uses
    # the real torso rear rather than subpixel collision jitter.
    if not _near(MOTION.exhaust_direction(
            Vector3.ZERO, true, true, Vector3.RIGHT,
            Vector3.RIGHT, true, true, Vector3(1.0, 0.0, 0.0),
            false, false, false, back), Vector3.LEFT) \
            or not _near(MOTION.exhaust_direction(
            Vector3(1.0, 0.0, 0.0), false, false, Vector3.ZERO,
            Vector3.ZERO, false, false, Vector3.ZERO,
            true, false, false, back), back):
        _fail("somersault/melee steering precedence changed")
        return
    # Tracking chase must NOT be replaced by normal-attack steady exhaust.
    if not _near(MOTION.exhaust_direction(
            Vector3(3.0, 0.0, 0.0), false, false, Vector3.ZERO,
            Vector3.ZERO, false, false, Vector3.ZERO,
            true, true, false, back), Vector3(-3.0, 0.0, 0.0)) \
            or not _near(MOTION.exhaust_direction(
            Vector3(0.01, 0.0, 0.0), false, false, Vector3.ZERO,
            Vector3.ZERO, false, false, Vector3.ZERO,
            false, false, false, back), back):
        _fail("tracking motion or blocked movement fallback changed")
        return
    print("SERA_MOTION_DIRECTION_RUNTIME_PASS: RUN, BOOST, neutral, kick, melee, tracking")
    quit(0)

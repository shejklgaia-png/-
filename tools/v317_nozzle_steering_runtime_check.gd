extends SceneTree
## Godot 4.7.2 real-scene and pure steering regression for Stage12.
const NOZZLE = preload("res://scripts/sera_nozzle_steering.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_NOZZLE_STEERING_RUNTIME_FAIL: " + message)
    quit(1)

func _near(a: float, b: float) -> bool:
    return absf(a - b) < 0.00002

func _vector_near(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) < 0.00002

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null:
        _fail("main actor or rig missing")
        return
    var rear: Vector3 = Vector3.BACK
    var right: Vector3 = Vector3.RIGHT
    var zero_flick: Vector2 = Vector2.ZERO
    # Actor-relative STEP travel overrides camera flick on diagonals.
    var step_right_back: Vector2 = Vector2(1.0, 1.0)
    var w: float = NOZZLE.backstroke_weight(true, true,
        Vector2(1.0, 1.0), Vector2.UP, 1, -2,
        false, false, false, false, Vector3.ZERO, rear, 0.25)
    if not _near(w, sqrt(0.5)):
        _fail("diagonal STEP must use its actual world displacement")
        return
    # Without a committed world fallback, use screen flick or legacy BACK.
    if not _near(NOZZLE.backstroke_weight(true, false,
            Vector2.ZERO, Vector2(0.0, 0.4), 1, -2,
            false, false, false, false, Vector3.ZERO, rear, 0.75), 0.4) \
            or not _near(NOZZLE.backstroke_weight(true, false,
            Vector2.ZERO, zero_flick, -2, -2,
            false, false, false, false, Vector3.ZERO, rear, 0.75), 1.0):
        _fail("STEP flick and legacy BACKSTEP weighting changed")
        return
    if not _near(NOZZLE.backstroke_weight(false, false,
            Vector2.ZERO, zero_flick, 0, -2, true, true,
            false, false, Vector3.ZERO, rear, 0.1), 1.0):
        _fail("somersault must aim nozzle down")
        return
    # BOOST follows requested world travel, or keeps its cached weight.
    if not _near(NOZZLE.backstroke_weight(false, false,
            Vector2.ZERO, zero_flick, 0, -2, false, false,
            true, false, Vector3(1.0, 0.0, 1.0), rear, 0.25), sqrt(0.5)) \
            or not _near(NOZZLE.backstroke_weight(false, false,
            Vector2.ZERO, zero_flick, 0, -2, false, false,
            false, true, Vector3.ZERO, rear, 0.65), 0.65) \
            or not _near(NOZZLE.backstroke_weight(false, false,
            Vector2.ZERO, zero_flick, 0, -2, false, false,
            false, false, Vector3.ZERO, rear, 0.65), 0.0):
        _fail("BOOST downwash, neutral caching or idle weighting changed")
        return

    # Left sector only applies to left-facing screen gestures.
    if not _near(NOZZLE.leftward_weight(true, Vector2(-0.8, 0.0),
            1, false, Vector2.ZERO), 0.8) \
            or not _near(NOZZLE.leftward_weight(true, zero_flick,
            -1, false, Vector2.ZERO), 1.0) \
            or not _near(NOZZLE.leftward_weight(false, zero_flick,
            0, true, Vector2(-0.6, 0.8)), 0.6) \
            or not _near(NOZZLE.leftward_weight(false, zero_flick,
            0, false, Vector2(-1.0, 0.0)), 0.0):
        _fail("LEFT screen weight or legacy LEFT STEP changed")
        return

    # Camera-right is computed by the real main-scene transform, not from
    # SERA's facing; with a pure left gesture the two curves meet at 45°.
    var screen_right: Vector3 = game.call("_screen_drag_to_ground", Vector2.RIGHT).normalized()
    var pure_left: Vector3 = NOZZLE.left_sector_direction(
        true, 1.0, screen_right, 0.0)
    var expected_left: Vector3 = Vector3.DOWN.slerp(screen_right, 0.5).normalized()
    if not _vector_near(pure_left, expected_left):
        _fail("pure-left sector lost camera-space down/right vector")
        return
    if not _vector_near(NOZZLE.left_sector_direction(
            true, 1.0, screen_right, 1.0), Vector3.DOWN) \
            or not _vector_near(NOZZLE.left_sector_direction(
            false, 1.0, screen_right, 0.0), Vector3.ZERO) \
            or not _vector_near(NOZZLE.left_sector_direction(
            true, 0.0, screen_right, 0.0), Vector3.ZERO):
        _fail("downward rear override or FX gating changed")
        return

    # Test rear-left diagonals over all actor-independent camera yaws.
    # The rightward sector angle MUST shrink monotonically with rear weight.
    for angle_degrees in [-160.0, -60.0, 0.0, 75.0, 150.0]:
        var camera_right: Vector3 = Vector3.RIGHT.rotated(
            Vector3.UP, deg_to_rad(angle_degrees))
        var previous_angle: float = 10.0
        for rear_weight in [0.0, 0.1, 0.5, 0.70710678, 0.9, 1.0]:
            var cone: Vector3 = NOZZLE.left_sector_direction(
                true, sqrt(0.5), camera_right, rear_weight)
            var component_right: float = cone.dot(camera_right)
            var actual_angle: float = atan2(component_right, -cone.y)
            var expected_angle: float = PI * 0.25 * sqrt(0.5) * (1.0 - rear_weight)
            if component_right < -0.00001 or cone.y > -0.00001 \
                    or not _near(cone.length(), 1.0) \
                    or not _near(actual_angle, expected_angle) \
                    or actual_angle > previous_angle + 0.00001:
                _fail("rear-left diagonal fanned sideways: " + str(angle_degrees))
                return
            previous_angle = actual_angle
    print("SERA_NOZZLE_STEERING_RUNTIME_PASS: STEP, BOOST, neutral, screen-left, rear-left")
    quit(0)

extends SceneTree
## Real scene and independent perspective/yaw regression for v317 extraction.
const FRAMING = preload("res://scripts/sera_camera_framing.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_CAMERA_FRAMING_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var view: Camera3D = game.get("camera") as Camera3D
    if view == null:
        _fail("scene camera missing")
        return
    var constants: Dictionary = game.get_script().get_script_constant_map()
    var follow_scale: float = float(constants["CAMERA_MOVING_YAW_SCALE"])
    var max_relative: float = float(constants["STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES"])
    var max_turn: float = float(constants["STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES"])
    for source_degrees in [-145.0, -20.0, 0.0, 35.0, 170.0]:
        var source_yaw: float = deg_to_rad(source_degrees)
        game.set("camera_yaw", source_yaw)
        for target_degrees in [-160.0, 0.0, 110.0, 179.0]:
            var target_yaw: float = deg_to_rad(target_degrees)
            var seconds: float = 1.0 / 60.0
            var value: float = float(game.call(
                "_close_step_target_relative_yaw", target_yaw, 0.32, seconds))
            var expected: float = FRAMING.close_step_target_relative_yaw(
                source_yaw, target_yaw, 0.32, seconds,
                follow_scale, max_relative, max_turn)
            if absf(value - expected) > 0.000001:
                _fail("close-step yaw mismatch")
                return
            if absf(wrapf(value - source_yaw, -PI, PI)) > deg_to_rad(max_turn) * seconds + 0.00001:
                _fail("close-step yaw speed limit lost")
                return
    var focus: Vector3 = Vector3(0.0, 1.0, 0.0)
    var right: Vector3 = Vector3.RIGHT
    var up: Vector3 = Vector3.UP
    var outward: Vector3 = Vector3.BACK
    for point in [Vector3(1.5, 2.0, -3.0), Vector3(-2.0, -1.0, -1.0),
                  Vector3(0.0, 1.0, 0.0), Vector3(0.5, 4.0, 2.0)]:
        var value: float = float(game.call("_camera_radius_for_safe_point",
            point, focus, right, up, outward, 1.0, 0.45, 0.75,
            0.02, 0.145, 0.75))
        var diff: Vector3 = point - focus
        var need_h: float = absf(diff.dot(right)) / (0.45 * (1.0 - 0.04))
        var need_v: float = (diff.dot(up) / (0.75 * (1.0 - 0.29))
            if diff.dot(up) >= 0.0 else -diff.dot(up) / (0.75 * (1.5 - 1.0)))
        var expected: float = maxf(0.0,
            maxf(view.near + 0.005, maxf(need_h, need_v)) + diff.dot(outward))
        if absf(value - expected) > 0.0001:
            _fail("perspective radius inequality changed")
            return
        var delegated: float = FRAMING.required_radius_for_point(
            point, focus, right, up, outward, 1.0, 0.45, 0.75,
            0.02, 0.145, 0.75, view.near)
        if absf(value - delegated) > 0.000001:
            _fail("camera near plane not propagated")
            return
    print("SERA_CAMERA_FRAMING_RUNTIME_PASS")
    quit(0)

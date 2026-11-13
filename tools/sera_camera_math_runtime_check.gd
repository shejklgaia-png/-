extends SceneTree
const M = preload("res://scripts/sera_camera_math.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_CAMERA_MATH_FAILED: " + message)
    quit(1)
func _run() -> void:
    if M.desired_follow_focus(Vector2.ZERO, Vector2(0.0, -8.0), 2.0).distance_to(
            Vector2(0.0, -2.0)) > 0.000001:
        _fail("focus lead changed")
        return
    var current: Vector2 = Vector2.ZERO
    for i in range(180):
        var desired: Vector2 = Vector2(float(i) * 0.24, -2.0)
        current = M.advance_follow_focus(current, desired, 1.0/60.0, 15.0, 0.65)
        if current.distance_to(desired) > 0.650001:
            _fail("hard position leash failed")
            return
    var yaw: float = 0.0
    for degrees in [0.0, 1.0, 5.0, 14.0, 30.0, 60.0, 110.0, 160.0, 195.0, -160.0]:
        yaw = M.stable_shoulder_yaw(yaw, deg_to_rad(degrees), 1.0/60.0, 12.0, 10.0, 12.0)
        var desired_yaw: float = deg_to_rad(degrees - 12.0)
        if absf(wrapf(desired_yaw-yaw, -PI, PI)) > deg_to_rad(12.0) + 0.00001:
            _fail("hard angular leash failed")
            return
    print("SERA_CAMERA_MATH_PASS")
    quit(0)

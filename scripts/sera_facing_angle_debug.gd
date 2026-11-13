extends Control
## Optional in-game visual verification of the ACTUAL screen-space axis.
## Always passive: hit tests and gesture interpretation stay in main.gd.
var torso: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var forward: Vector2 = Vector2.UP
var input_forward: Vector2 = Vector2.UP
var committed: bool = false
var ready: bool = false

func set_geometry(from_point: Vector2, to_point: Vector2, axis: Vector2,
        captured_axis: Vector2, gesture_active: bool) -> void:
    torso = from_point
    target = to_point
    forward = axis.normalized() if axis.length_squared() > 0.000001 else Vector2.UP
    input_forward = captured_axis.normalized() if captured_axis.length_squared() > 0.000001 else forward
    committed = gesture_active
    ready = true
    if visible:
        queue_redraw()

func _draw() -> void:
    if not ready:
        return
    var color: Color = Color(0.25, 0.93, 0.99, 0.95)
    var frozen: Color = Color(1.0, 0.77, 0.27, 0.92)
    draw_line(torso, target, color, 2.5, true)
    draw_circle(torso, 5.0, color)
    draw_circle(target, 5.0, color)
    var axis: Vector2 = input_forward if committed else forward
    var center_angle: float = axis.angle()
    for side in [-1.0, 1.0]:
        var ray: Vector2 = axis.rotated(side * PI * 0.25)
        draw_line(torso, torso + ray * 115.0, frozen, 1.8, true)
    draw_arc(torso, 78.0, center_angle - PI * 0.25,
        center_angle + PI * 0.25, 32, frozen, 2.0, true)
    var screen_angle: float = wrapf(rad_to_deg(atan2(axis.x, -axis.y)),
        -180.0, 180.0)
    var state: String = "FROZEN INPUT" if committed else "LIVE LOCK"
    var label: String = "%s  FRONT %+0.1f deg  (90 deg)" % [
        state, screen_angle]
    draw_string(get_theme_default_font(),
        torso + Vector2(14.0, -70.0), label,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, frozen)

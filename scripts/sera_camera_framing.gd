extends RefCounted
## Stateless camera perspective fitting and close-STEP yaw angle calculations.
## Scene nodes, camera state, rendering and input remain in main.gd.

static func close_step_target_relative_yaw(current_yaw: float,
        player_bearing: float, easing: float, delta: float,
        moving_yaw_scale: float, max_relative_degrees: float,
        max_turn_degrees_per_second: float) -> float:
    var desired_yaw: float = lerp_angle(
        current_yaw, player_bearing, easing * moving_yaw_scale)
    var offset_from_player: float = wrapf(desired_yaw - player_bearing, -PI, PI)
    var max_angle: float = deg_to_rad(max_relative_degrees)
    var bounded_yaw: float = player_bearing + clampf(
        offset_from_player, -max_angle, max_angle)
    var yaw_to_go: float = wrapf(bounded_yaw - current_yaw, -PI, PI)
    var turn_limit: float = deg_to_rad(max_turn_degrees_per_second) * delta
    return current_yaw + clampf(yaw_to_go, -turn_limit, turn_limit)


static func required_radius_for_point(point: Vector3, focus: Vector3,
        screen_right: Vector3, screen_up: Vector3, outward: Vector3,
        radial_scale: float, tan_h: float, tan_v: float,
        margin_x: float, margin_top: float, margin_bottom: float,
        near_plane: float) -> float:
    var offset: Vector3 = point - focus
    var screen_x: float = offset.dot(screen_right)
    var screen_y: float = offset.dot(screen_up)
    var horizontal_depth: float = absf(screen_x) / maxf(
        0.0001, tan_h * (1.0 - 2.0 * margin_x))
    var vertical_depth: float = 0.0
    if screen_y >= 0.0:
        vertical_depth = screen_y / maxf(
            0.0001, tan_v * (1.0 - 2.0 * margin_top))
    else:
        vertical_depth = -screen_y / maxf(
            0.0001, tan_v * (2.0 * margin_bottom - 1.0))
    var depth: float = maxf(near_plane + 0.005,
        maxf(horizontal_depth, vertical_depth))
    return maxf(0.0, (depth + offset.dot(outward)) / radial_scale)

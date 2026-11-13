extends RefCounted
## Stateless camera follow equations moved out of main.gd without changing tunables.
static func desired_follow_focus(player_xz: Vector2, target_xz: Vector2,
        lead: float) -> Vector2:
    return player_xz + (target_xz - player_xz).limit_length(lead)

static func advance_follow_focus(current: Vector2, desired: Vector2,
        delta: float, rate: float, max_lag: float) -> Vector2:
    var alpha: float = 1.0 - exp(-rate * maxf(delta, 0.0))
    var next: Vector2 = current.lerp(desired, alpha)
    var error: Vector2 = desired - next
    if error.length_squared() > max_lag * max_lag:
        next = desired - error.normalized() * max_lag
    return next

static func stable_shoulder_yaw(current_yaw: float, bearing: float,
        delta: float, shoulder_degrees: float, rate: float,
        max_lag_degrees: float) -> float:
    var desired: float = bearing - deg_to_rad(shoulder_degrees)
    var error: float = wrapf(desired - current_yaw, -PI, PI)
    var alpha: float = 1.0 - exp(-rate * maxf(delta, 0.0))
    var residual: float = error * (1.0 - alpha)
    var leash: float = deg_to_rad(max_lag_degrees)
    return current_yaw + error - clampf(residual, -leash, leash)

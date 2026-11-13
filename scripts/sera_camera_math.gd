extends RefCounted
## Stateless camera follow equations moved out of main.gd without changing tunables.
static func desired_follow_focus(player_xz: Vector2, target_xz: Vector2,
        lead: float) -> Vector2:
    return player_xz + (target_xz - player_xz).limit_length(lead)

static func advance_follow_focus(current: Vector2, desired: Vector2,
        delta: float, rate: float, max_lag: float) -> Vector2:
    var dt: float = maxf(delta, 0.0)
    var alpha: float = 1.0 - exp(-rate * dt)
    var next: Vector2 = current.lerp(desired, alpha)
    # A hard error leash teleports the camera almost the full distance on a
    # sudden STEP/BOOST displacement. Cap distance *per render frame* instead.
    # max_lag is still the desired steady tracking tolerance, not a teleport.
    var max_travel: float = maxf(16.0, rate * max_lag * 1.7) * dt
    var travel: Vector2 = next - current
    if travel.length_squared() > max_travel * max_travel:
        next = current + travel.normalized() * max_travel
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

# Camera side has to be measured relative to the TARGET's screen X,
# not the viewport center. A hysteresis band prevents boundary chatter
# when SERA and target overlap; initial side is kept until clear crossing.
static func screen_side_after_crossing(current_side: int,
        player_x: float, target_x: float, hysteresis_px: float) -> int:
    if not is_finite(player_x) or not is_finite(target_x):
        return current_side
    var difference: float = player_x - target_x
    if difference > hysteresis_px:
        return 1
    if difference < -hysteresis_px:
        return -1
    return current_side


# Mirror the shoulder continuously over several rendered frames. Never
# suddenly rotate by twice the shoulder angle at screen-crossing.
static func smooth_shoulder_mirror(current: float, next_side: int,
        delta: float, rate: float) -> float:
    var alpha: float = 1.0 - exp(-maxf(0.0, rate) * maxf(0.0, delta))
    return lerpf(current, float(next_side), alpha)


# Avoid abrupt 180-degree bearing reversals when SERA crosses the boss
# center. Retain the previous bearing inside the nearly coincident radius,
# then reacquire the new bearing continuously outside that radius.
static func stable_near_bearing(previous: float, raw_bearing: float,
        separation: float, delta: float) -> float:
    var fraction: float = smooth_response(
        (separation - 0.40) / (2.20 - 0.40))
    var alpha: float = 1.0 - exp(-9.0 * maxf(0.0, delta) * fraction)
    return lerp_angle(previous, raw_bearing, alpha)


# Camera response profiles remain pure functions: main.gd owns event timing.
static func smooth_response(progress: float) -> float:
    var t: float = clampf(progress, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


static func step_recovery_response(elapsed: float, hold_seconds: float,
        total_seconds: float) -> float:
    if elapsed <= hold_seconds:
        return 0.0
    return smooth_response((elapsed - hold_seconds) /
        maxf(0.00001, total_seconds - hold_seconds))


static func follow_yaw_with_side_room(current_yaw: float, bearing: float,
        delta: float, shoulder_degrees: float, rate: float,
        side_room_degrees: float, max_turn_degrees_per_second: float) -> float:
    # Keep the user's familiar yaw sensitivity *outside* the lateral room.
    # No hard-leash teleport when recovering from a committed STEP.
    var desired: float = bearing - deg_to_rad(shoulder_degrees)
    var error: float = wrapf(desired - current_yaw, -PI, PI)
    var room: float = deg_to_rad(maxf(0.0, side_room_degrees))
    var amount: float = signf(error) * maxf(0.0, absf(error) - room)
    var alpha: float = 1.0 - exp(-maxf(0.0, rate) * maxf(0.0, delta))
    var limit: float = deg_to_rad(maxf(0.0,
        max_turn_degrees_per_second)) * maxf(0.0, delta)
    return current_yaw + clampf(amount * alpha, -limit, limit)

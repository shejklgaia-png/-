extends RefCounted
## Pure RUN/BOOST gesture and speed-transition state calculations.
## The live state, eligibility gates, EN spending, UI and animation effects
## remain in main.gd. Thresholds and blend duration are passed by the caller.

static func next_gesture_state(active: bool, confirmation_elapsed: float,
        finger_distance: float, delta: float, drag_radius: float,
        start_ratio: float, exit_ratio: float,
        confirm_seconds: float) -> Dictionary:
    var next_active: bool = active
    var next_confirmation: float = confirmation_elapsed
    if active:
        # Keep BOOST until the thumb crosses the lower hysteresis radius.
        if finger_distance < drag_radius * exit_ratio:
            next_active = false
            next_confirmation = 0.0
    elif finger_distance >= drag_radius * start_ratio:
        next_confirmation += maxf(delta, 0.0)
        if next_confirmation >= confirm_seconds:
            next_active = true
    else:
        # Even a brief dip below entry restarts the confirmation interval.
        next_confirmation = 0.0
    return {
        "active": next_active,
        "confirmation_elapsed": next_confirmation,
    }


static func reset_speed_state(blend_seconds: float) -> Dictionary:
    return {
        "multiplier": 1.0,
        "start": 1.0,
        "target": 1.0,
        "elapsed": blend_seconds,
    }


static func next_speed_state(current_multiplier: float, start_multiplier: float,
        target_multiplier: float, elapsed: float, wanted: float,
        delta: float, blend_seconds: float) -> Dictionary:
    var next_start: float = start_multiplier
    var next_target: float = target_multiplier
    var next_elapsed: float = elapsed
    if not is_equal_approx(wanted, next_target):
        # A reversal starts at the current speed, never the prior end point.
        next_start = current_multiplier
        next_target = wanted
        next_elapsed = 0.0
    next_elapsed = minf(blend_seconds, next_elapsed + maxf(delta, 0.0))
    var t: float = clampf(next_elapsed / blend_seconds, 0.0, 1.0)
    var eased: float = t * t * (3.0 - 2.0 * t)
    return {
        "multiplier": lerpf(next_start, next_target, eased),
        "start": next_start,
        "target": next_target,
        "elapsed": next_elapsed,
    }

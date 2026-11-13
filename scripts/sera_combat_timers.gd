extends RefCounted
## Stateless countdown math for combat windows, stagger recovery and
## damage locks. The main scene owns every timer and the event triggered
## when it expires; the order of its physics/render callbacks is unchanged.

static func remaining_after_delta(remaining: float, delta: float) -> float:
    # Keep the existing inclusive zero threshold and unmodified delta.
    return maxf(0.0, remaining - delta)


static func stagger_after_countdown(value: float, stagger_remaining: float,
        delta: float, decay_rate: float) -> float:
    # The stagger timer has already advanced for this physics frame.
    # A timer that reaches zero starts decaying stagger on this SAME frame.
    if stagger_remaining <= 0.0:
        return maxf(0.0, value - decay_rate * delta)
    return value

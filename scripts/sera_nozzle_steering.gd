extends RefCounted
## Stateless nozzle weight and screen-sector steering (v317 Stage 12).
## Main owns input projection, jet direction/caching, rig, nozzle limits and FX.
## No scene lookup, shared state or per-frame collection allocations.

static func backstroke_weight(stepping: bool, step_linear_fallback: bool,
        step_linear_offset: Vector2, step_flick: Vector2, step_side: int,
        step_back: int, somersault: bool, somersault_launched: bool,
        boost_exhaust: bool, boost_pose_exhaust: bool,
        intended_boost: Vector3, actor_rear: Vector3,
        held_boost_weight: float) -> float:
    # STEP's world path takes priority over the gesture direction, since
    # camera-UP may actually move backwards from the locked actor's facing.
    var weight: float = 0.0
    if stepping:
        if step_linear_fallback and step_linear_offset.length_squared() > 0.000001:
            var step_world_rear: Vector3 = Vector3(
                step_linear_offset.x, 0.0, step_linear_offset.y).normalized()
            weight = clampf(step_world_rear.dot(actor_rear), 0.0, 1.0)
        else:
            weight = clampf(step_flick.y, 0.0, 1.0)
        # Legacy dedicated BACKSTEP has no omnidirectional flick vector.
        if step_side == step_back and step_flick.is_zero_approx():
            weight = 1.0
    elif somersault and somersault_launched:
        weight = 1.0
    elif boost_exhaust or boost_pose_exhaust:
        if intended_boost.length_squared() > 0.000001:
            weight = clampf(intended_boost.normalized().dot(actor_rear), 0.0, 1.0)
        else:
            weight = held_boost_weight
    return weight


static func leftward_weight(stepping: bool, step_flick: Vector2,
        step_side: int, boost_or_pose: bool, direction_input: Vector2) -> float:
    var weight: float = 0.0
    if stepping:
        weight = clampf(-step_flick.x, 0.0, 1.0)
        if step_side == -1 and step_flick.is_zero_approx():
            weight = 1.0
    elif boost_or_pose and direction_input.length_squared() > 0.000001:
        weight = clampf(-direction_input.normalized().x, 0.0, 1.0)
    return weight


static func left_sector_direction(exhaust_on: bool, left_weight: float,
        screen_right: Vector3, backstroke: float) -> Vector3:
    if not exhaust_on or left_weight <= 0.0:
        return Vector3.ZERO
    # Preserve the original two spherical blends: gravity -> screen-right,
    # then blend BACK toward gravity. Rear-left diagonal bias must override
    # the screen-right fan and avoid sideways nozzle flips.
    var left_sector_world: Vector3 = Vector3.DOWN.slerp(
        screen_right, left_weight * 0.50).normalized()
    left_sector_world = left_sector_world.slerp(
        Vector3.DOWN, backstroke).normalized()
    return left_sector_world

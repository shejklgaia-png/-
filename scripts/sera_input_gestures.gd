extends RefCounted
## SERA input interpretation. Pure functions: no camera, UI, frame state or scene
## dependencies. Thresholds come from main.gd (the approved v317 values).
const FLICK_DIRECTION_POLICY = preload("res://scripts/flick_direction_policy.gd")

static func analog_stick_direction(displacement: Vector2,
        deadzone: float, radius: float) -> Vector2:
    var distance: float = displacement.length()
    if distance <= deadzone:
        return Vector2.ZERO
    # v245: analog steering retains continuous 360-degree direction.
    var strength: float = clampf(
        (distance - deadzone) / (radius - deadzone), 0.0, 1.0)
    return displacement / distance * strength


static func side_flick(displacement: Vector2, seconds: float,
        max_seconds: float, min_horizontal: float, min_speed: float,
        max_vertical_ratio: float, max_travel: float) -> int:
    # Release-only lateral gesture; never convert an ordinary held drag.
    if seconds <= 0.0 or seconds > max_seconds:
        return 0
    var horizontal: float = absf(displacement.x)
    if horizontal < min_horizontal:
        return 0
    if horizontal / seconds < min_speed:
        return 0
    if absf(displacement.y) > horizontal * max_vertical_ratio:
        return 0
    if max_travel > displacement.length() * 1.20:
        return 0
    return 1 if displacement.x > 0.0 else -1


static func step_flick(displacement: Vector2, seconds: float,
        max_seconds: float, min_distance: float, min_speed: float,
        max_travel: float) -> Vector2:
    if seconds <= 0.0 or seconds > max_seconds:
        return Vector2.ZERO
    var distance: float = displacement.length()
    if distance < min_distance:
        return Vector2.ZERO
    if distance / seconds < min_speed:
        return Vector2.ZERO
    if max_travel > distance * 1.20:
        return Vector2.ZERO
    # Exact 360-degree vector, not four-way quantization.
    return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)


static func combo_kick_flick(displacement: Vector2, seconds: float,
        max_seconds: float, min_distance: float, min_speed: float,
        max_travel: float, reversal_ratio: float) -> Vector2:
    if seconds <= 0.0 or seconds > max_seconds:
        return Vector2.ZERO
    var distance: float = displacement.length()
    if distance < min_distance:
        return Vector2.ZERO
    if distance / seconds < min_speed:
        return Vector2.ZERO
    if max_travel > distance * reversal_ratio:
        return Vector2.ZERO
    return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)


static func combo_kick_side(flick: Vector2,
        actor_screen_forward: Vector2 = Vector2.UP) -> int:
    # FWD=Bash, actor-right=Kick_r, BACK=Kick_b, actor-left=Kick_l.
    # The camera-projected axis is frozen for the entire gesture.
    var actor_sector: int = FLICK_DIRECTION_POLICY.sector_index(
        flick, actor_screen_forward)
    match actor_sector:
        1:
            return 1
        2:
            return 2
        3:
            return -1
        _:
            return 0


static func upward_jump_flick(displacement: Vector2, seconds: float,
        max_seconds: float, min_vertical: float, min_speed: float,
        max_horizontal_ratio: float) -> bool:
    if seconds <= 0.0 or seconds > max_seconds:
        return false
    var upward: float = -displacement.y
    return upward >= min_vertical \
        and upward / seconds >= min_speed \
        and absf(displacement.x) <= upward * max_horizontal_ratio


static func controller_contains(pos: Vector2, screen: Vector2) -> bool:
    return (pos.x >= 0.0 and pos.x <= screen.x
        and pos.y >= 0.0 and pos.y <= screen.y)

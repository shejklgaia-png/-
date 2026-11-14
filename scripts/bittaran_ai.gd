extends RefCounted
## BITTARAN combat policy. Forward is the boss's +Z after the authored
## Blockbench model is rotated 180 degrees to face SERA.
const VISION_TOTAL_DEGREES: float = 100.0
const VISION_HALF_DEGREES: float = 50.0
const APPROACH_SPEED_MPS: float = 0.72
const ACCELERATION_MPS2: float = 0.60
const STATIONARY_TURN_DEG_PER_SEC: float = 34.0
const MOVING_TURN_DEG_PER_SEC: float = 22.0
const TRACK_AT_REST_DEG_PER_SEC: float = 18.0
const STOP_DISTANCE_METERS: float = 7.8
const RESUME_DISTANCE_METERS: float = 8.6
const FACING_TOLERANCE_DEGREES: float = 5.0
const VISION_HYSTERESIS_DEGREES: float = 3.0
var current_speed: float = 0.0
var in_view: bool = false
var closing_in: bool = false

func reset() -> void:
    current_speed = 0.0
    in_view = false
    closing_in = false

func advance_recovery_turn(delta: float, position: Vector3, yaw: float,
        player_position: Vector3, turn_enabled: bool) -> Dictionary:
    # Yaw starts at NORMAL stationary-turn speed on the very first
    # stand-up frame. No advance, velocity blend, speed interpolation
    # or translation: the actual walk/Turn clip still waits for standing.
    current_speed = 0.0
    var state := {"position": position, "yaw": yaw, "motion": "Idle"}
    if delta <= 0.0 or not turn_enabled:
        return state
    var toward: Vector3 = player_position - position
    toward.y = 0.0
    if toward.length_squared() <= 0.000001:
        return state
    var wanted_yaw: float = atan2(toward.x, toward.z)
    var angle: float = wrapf(wanted_yaw - yaw, -PI, PI)
    var maximum_step: float = deg_to_rad(
        STATIONARY_TURN_DEG_PER_SEC) * delta
    state["yaw"] = yaw + clampf(angle, -maximum_step, maximum_step)
    return state


func advance(delta: float, position: Vector3, yaw: float,
        player_position: Vector3, frozen: bool) -> Dictionary:
    var state := {"position": position, "yaw": yaw, "motion": "Idle"}
    if delta <= 0.0 or frozen:
        current_speed = 0.0
        return state
    var toward: Vector3 = player_position - position
    toward.y = 0.0
    var distance: float = toward.length()
    if distance <= 0.001:
        current_speed = 0.0
        return state
    var desired_yaw: float = atan2(toward.x, toward.z)
    var angle: float = wrapf(desired_yaw - yaw, -PI, PI)
    var abs_degrees: float = absf(rad_to_deg(angle))
    # 3-degree hysteresis prevents rapid turn/walk swaps at the FOV edge.
    if in_view:
        in_view = abs_degrees <= VISION_HALF_DEGREES + VISION_HYSTERESIS_DEGREES
    else:
        in_view = abs_degrees <= VISION_HALF_DEGREES - VISION_HYSTERESIS_DEGREES
    # Distance hysteresis prevents repeated foot lift at the stop boundary.
    if closing_in:
        closing_in = distance > STOP_DISTANCE_METERS
    else:
        closing_in = distance > RESUME_DISTANCE_METERS
    if not in_view:
        current_speed = 0.0
        state["motion"] = "Turn"
        state["yaw"] = yaw + clampf(angle,
            -deg_to_rad(STATIONARY_TURN_DEG_PER_SEC) * delta,
            deg_to_rad(STATIONARY_TURN_DEG_PER_SEC) * delta)
        return state
    if closing_in:
        current_speed = move_toward(current_speed, APPROACH_SPEED_MPS,
            ACCELERATION_MPS2 * delta)
        state["motion"] = "Approach"
        var next_yaw: float = yaw + clampf(angle,
            -deg_to_rad(MOVING_TURN_DEG_PER_SEC) * delta,
            deg_to_rad(MOVING_TURN_DEG_PER_SEC) * delta)
        state["yaw"] = next_yaw
        # Drive in the boss's current forward direction, not straight toward
        # the player; the gradual turn is visible as a curved approach.
        state["position"] = position + Vector3(
            sin(next_yaw), 0.0, cos(next_yaw)) * current_speed * delta
        return state
    current_speed = move_toward(current_speed, 0.0, ACCELERATION_MPS2 * delta)
    if abs_degrees > FACING_TOLERANCE_DEGREES:
        state["motion"] = "Turn"
        state["yaw"] = yaw + clampf(angle,
            -deg_to_rad(TRACK_AT_REST_DEG_PER_SEC) * delta,
            deg_to_rad(TRACK_AT_REST_DEG_PER_SEC) * delta)
    return state

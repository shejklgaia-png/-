extends RefCounted
## BITTARAN combat policy. Forward is the boss's +Z after the authored
## Blockbench model is rotated 180 degrees to face SERA.
const VISION_TOTAL_DEGREES: float = 100.0
const VISION_HALF_DEGREES: float = 50.0
## 1.30x approach travel speed, with the authored gait cadence unchanged.
const APPROACH_SPEED_MPS: float = 0.936
const ACCELERATION_MPS2: float = 0.78
const STATIONARY_TURN_DEG_PER_SEC: float = 34.0
const MOVING_TURN_DEG_PER_SEC: float = 22.0
const TRACK_AT_REST_DEG_PER_SEC: float = 18.0
# v451: stop INSIDE the new 7.10m real attack-acquisition band.
# At the old 7.8m stop distance, Bittaran could remain permanently
# out of attack range even after all three required steps.
const STOP_DISTANCE_METERS: float = 5.85
const RESUME_DISTANCE_METERS: float = 6.40
# v464: while the 3 completed walk steps are outstanding,
# move rather than stand still at the former 7.8m stop radius.
# Close = backstep, middle = sidestep around SERA, far = advance.
const WALK_RETREAT_DISTANCE_METERS: float = 3.35
const WALK_ORBIT_DISTANCE_METERS: float = 5.95
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
        player_position: Vector3, frozen: bool,
        force_three_step_walk: bool = false,
        force_attack_variation: bool = false,
        last_attack_kind: String = "") -> Dictionary:
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
    # v464: when the 3 real gait steps are still pending, choose a
    # movement suited to distance and keep animating full steps.
    if force_three_step_walk:
        # The three-step requirement does not permit blind translation.
        # When SERA is outside the 100-degree tracking cone, first
        # turn on the spot at the normal stationary yaw rate. Walking
        # away/sideways here caused fall/stand-up tests to enter
        # Approach instead of Turn and made the boss strafe blindly.
        if not in_view and not force_attack_variation:
            current_speed = 0.0
            state["motion"] = "Turn"
            state["yaw"] = yaw + clampf(angle,
                -deg_to_rad(STATIONARY_TURN_DEG_PER_SEC) * delta,
                deg_to_rad(STATIONARY_TURN_DEG_PER_SEC) * delta)
            return state
        current_speed = move_toward(current_speed, APPROACH_SPEED_MPS,
            ACCELERATION_MPS2 * delta)
        var next_yaw: float = yaw + clampf(angle,
            -deg_to_rad(MOVING_TURN_DEG_PER_SEC) * delta,
            deg_to_rad(MOVING_TURN_DEG_PER_SEC) * delta)
        var direction: Vector3 = Vector3(
            sin(next_yaw), 0.0, cos(next_yaw))
        if force_attack_variation:
            # A repeat-blocked attack cannot become legal merely by
            # circling SERA at a fixed radius. The previous AI orbited
            # at ~6.8m forever after SWEEP: walk steps accumulated
            # (131 steps in the live regression) but the next attack
            # remained SWEEP, which the nonrepeat rule rejects.
            # Move THROUGH the sector boundary into a different valid
            # attack. All distances are ordinary movement, never a
            # teleport or a forced clip outside its hit range.
            match last_attack_kind:
                "sweep":
                    # Approach until KICK (front 3-5m) or STOMP (<3m).
                    direction = toward.normalized()
                "kick", "stomp":
                    # Withdraw until SWEEP or KICK becomes legal.
                    direction = -toward.normalized()
                _:
                    # Compatibility for generic movement requests.
                    var radial: Vector3 = toward.normalized()
                    direction = Vector3(-radial.z, 0.0, radial.x)
        elif distance <= 2.85:
            # v452: preserve STOMP range during the mandatory FIRST
            # three steps. Blindly backstepping from a close SERA
            # pushed Bittaran to ~3.35m before its first decision;
            # the only legal close attack was then always KICK.
            # Circle the player at the CURRENT radius instead of
            # translating away; the actual diagonal gait still
            # completes 3 steps and the true toe decides impact.
            var close_radial: Vector3 = toward.normalized()
            direction = Vector3(
                -close_radial.z, 0.0, close_radial.x)
        elif distance < WALK_RETREAT_DISTANCE_METERS:
            # Backstep from midrange only, not from a target still
            # inside the legal short-range STOMP sector.
            direction = -toward.normalized()
        elif distance <= WALK_ORBIT_DISTANCE_METERS:
            # Orbit only while meeting the minimum-walk-step
            # requirement; once an attack type is repeat-blocked,
            # deliberate radial movement changes its legal sector.
            var radial: Vector3 = toward.normalized()
            direction = Vector3(-radial.z, 0.0, radial.x)
        state["position"] = position + direction * current_speed * delta
        state["yaw"] = next_yaw
        state["motion"] = "Approach"
        return state
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

extends RefCounted
## Stateless physics-frame decisions. Scene-owned state, movement, collisions,
## rig animation, sound and FX nodes stay in main.gd.
## No per-frame dictionary/array allocations or mutable module state.

static func next_boost_pose_grace(remaining: float, delta: float,
        grace_seconds: float, gesture_active: bool, guard_active: bool,
        damage_active: bool, jump_active: bool, landing_active: bool,
        step_active: bool, back_somersault_active: bool, combat_idle: bool,
        boost_active: bool) -> float:
    if not gesture_active or guard_active or damage_active             or jump_active or landing_active or step_active             or back_somersault_active or not combat_idle:
        return 0.0
    if boost_active:
        return grace_seconds
    return maxf(0.0, remaining - delta)


static func flight_owns_displacement(jumping_this_frame: bool,
        landing_this_frame: bool, somersault_this_frame: bool,
        back_somersault_active: bool, landing_active: bool) -> bool:
    # A committed move owns its first and last frame even if its live flag
    # is cleared by the advance callback earlier in this physics tick.
    return (jumping_this_frame or landing_this_frame
        or somersault_this_frame or back_somersault_active or landing_active)


static func displacement_velocity(current_position: Vector3,
        previous_position: Vector3, delta: float) -> Vector3:
    # Collision-resolved STEP and attack movement do not use player.velocity.
    if delta > 0.000001:
        return (current_position - previous_position) / delta
    return Vector3.ZERO


static func exhaust_allowed(damage_active: bool, jumping: bool,
        landing: bool, guarding: bool, energy_exhausted: bool,
        boost_exhaust: bool, boost_pose_exhaust: bool, stepping: bool,
        tracking_exhaust: bool, attack_exhaust: bool) -> bool:
    return (not damage_active and not jumping and not landing
        and not guarding and not energy_exhausted
        and (boost_exhaust or boost_pose_exhaust or stepping
            or tracking_exhaust or attack_exhaust))


static func acceleration_burst(exhaust_on: bool, stepping: bool,
        previous_step: bool, new_somersault_burst: bool,
        tracking_state: int, previous_tracking_state: int) -> bool:
    # Continuous melee exhaust is intentionally NOT a new burst.
    return (exhaust_on
        and ((stepping and not previous_step)
            or new_somersault_burst
            or (tracking_state >= 0
                and tracking_state != previous_tracking_state)))

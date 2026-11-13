extends RefCounted
## Single owner for the commanded BOOST nozzle cache and final rig FX update.
## The scene still owns input, world-space direction, energy, physics and
## the nozzle's real authored pivots/angle limits.
## One persistent instance per main scene; zero per-frame container allocations.

var held_boost_exhaust_direction: Vector3 = Vector3.ZERO
var held_boost_backstroke_weight: float = 0.0
var held_boost_left_sector_world: Vector3 = Vector3.ZERO


func update(rig: Node, exhaust_on: bool, direction_of_exhaust: Vector3,
        delta: float, backstroke_weight: float, left_sector_world: Vector3,
        acceleration_burst: bool, normal_attack_exhaust: bool,
        boost_pose_exhaust: bool, running: bool, boost_exhaust: bool) -> void:
    # Keep the current command through the neutral thumb crossing while the
    # actual BOOST pose remains rendered. Do not cache while stationary.
    if boost_pose_exhaust:
        if running:
            held_boost_exhaust_direction = direction_of_exhaust.normalized()
            held_boost_backstroke_weight = backstroke_weight
            held_boost_left_sector_world = left_sector_world
        elif held_boost_exhaust_direction.length_squared() > 0.000001:
            # The nozzle DOWN / screen-left restrictions must hold as well
            # as the direction; otherwise neutral frames visibly snap.
            backstroke_weight = held_boost_backstroke_weight
            left_sector_world = held_boost_left_sector_world
    elif not boost_exhaust:
        # Actual BOOST alone (without its pose) does not clear the cache.
        # Clear only after both actual BOOST and the displayed pose have ended.
        held_boost_exhaust_direction = Vector3.ZERO
        held_boost_backstroke_weight = 0.0
        held_boost_left_sector_world = Vector3.ZERO

    # One emission call every physics frame, including inactive frames.
    # The selected equipment/rig owns its authored nozzle, particles and
    # continuing melee flames; no other FX state is created here.
    rig.call("update_back_thruster_fx", exhaust_on,
        direction_of_exhaust.normalized(), delta, backstroke_weight,
        left_sector_world, acceleration_burst, normal_attack_exhaust)

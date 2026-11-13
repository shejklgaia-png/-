extends RefCounted
## Pure directions for local RUN pose and physical rear exhaust steering.
## Camera space, actor transforms, input state and collision motion are passed
## in by main.gd; the live rig, nozzle, boost-hold cache and FX stay in main.

static func local_run_direction(world_move: Vector3, target_forward: Vector3,
        default_forward: Vector3) -> Vector2:
    # RUN animation is relative to SERA's locked target, not camera travel.
    # Preserve the original fallback, handedness, and analog magnitude.
    var facing: Vector3 = target_forward
    if facing.length_squared() < 0.000001:
        facing = default_forward
    facing = facing.normalized()
    return Vector2(
        world_move.dot(facing.cross(Vector3.UP)),
        world_move.dot(facing))


static func exhaust_direction(blur_velocity: Vector3, boost_pose_exhaust: bool,
        running: bool, requested_boost: Vector3,
        held_boost_direction: Vector3, somersault_this_frame: bool,
        somersault_launched: bool, somersault_direction: Vector3,
        normal_attack_exhaust: bool, tracking_exhaust: bool,
        stepping_this_frame: bool, actor_rear: Vector3) -> Vector3:
    var direction_of_exhaust: Vector3 = -blur_velocity
    direction_of_exhaust.y = 0.0
    # BOOST follows current thumb motion even against a wall. When the
    # thumb is neutral, preserve the previous jet heading if available.
    if boost_pose_exhaust and running:
        if requested_boost.length_squared() > 0.000001:
            direction_of_exhaust = -requested_boost.normalized()
    elif boost_pose_exhaust and held_boost_direction.length_squared() > 0.000001:
        direction_of_exhaust = held_boost_direction
    if somersault_this_frame and somersault_launched:
        direction_of_exhaust = -somersault_direction
    if normal_attack_exhaust and not tracking_exhaust \
            and not (somersault_this_frame and somersault_launched) \
            and not stepping_this_frame:
        # A static melee swing must never steer tiny hit-stop jitter into
        # the torso; it keeps the nozzle at SERA's stable rear axis.
        direction_of_exhaust = actor_rear
    if direction_of_exhaust.length_squared() < 0.0004:
        # A blocked STEP/BOOST still needs a non-zero rearward jet vector.
        direction_of_exhaust = actor_rear
    return direction_of_exhaust

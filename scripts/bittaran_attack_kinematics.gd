extends RefCounted
## Single-frame authored attack-space math. No persistent joint offsets:
## every target is rebuilt from the Blockbench source clip and the current
## anatomical hip, never from last frame's IK-mutated limb rotations.
const FLOOR_CLEARANCE_METERS: float = 0.012
const IK_MARGIN_METERS: float = 0.002
const POLE_ENTRY_SECONDS: float = 0.25


static func mirrored_delta(v: Vector3, leg_id: String,
        rig_frame: Basis) -> Vector3:
    var local: Vector3 = rig_frame.inverse() * v
    if leg_id.ends_with("r"):
        local.x = -local.x
    if leg_id.begins_with("leg_r"):
        local.z = -local.z
    return rig_frame * local


static func mirror_rotation(source: Quaternion, leg_id: String,
        rig_frame: Basis) -> Quaternion:
    var result: Basis = Basis(source)
    for axis in [rig_frame.x, rig_frame.z]:
        var do_mirror: bool = (
            leg_id.ends_with("r") if axis == rig_frame.x
            else leg_id.begins_with("leg_r"))
        if not do_mirror:
            continue
        var n: Vector3 = axis.normalized()
        var reflection := Basis(
            Vector3(1.0 - 2.0 * n.x * n.x, -2.0 * n.y * n.x,
                -2.0 * n.z * n.x),
            Vector3(-2.0 * n.x * n.y, 1.0 - 2.0 * n.y * n.y,
                -2.0 * n.z * n.y),
            Vector3(-2.0 * n.x * n.z, -2.0 * n.y * n.z,
                1.0 - 2.0 * n.z * n.z))
        result = reflection * result * reflection
    return result.get_rotation_quaternion().normalized()


static func aim_about_hip(point: Vector3, hip: Vector3,
        yaw: Quaternion) -> Vector3:
    return hip + yaw * (point - hip)


static func normalized_ground_sole(sole: Vector3,
        target_sole_to_mesh_bottom: float, source_low: float,
        source_entry_low: float, floor_y: float = 0.0) -> Vector3:
    # The SOURCE determines the vertical shape; its entry frame is
    # placed on the arena floor for all four mirrored limbs. A toe that
    # rises in the authored animation is allowed to rise by that amount.
    var relative_height: float = maxf(
        source_low - source_entry_low, 0.0)
    return Vector3(sole.x, floor_y + FLOOR_CLEARANCE_METERS
        + relative_height + target_sole_to_mesh_bottom, sole.z)


static func reachable_floor_target(hip: Vector3, ankle: Vector3,
        sole: Vector3, upper_len: float, lower_len: float) -> Dictionary:
    # Never stretch a limb or change its toe rotation. Where a rear
    # socket cannot reach a planted toe, contract only the horizontal
    # distance by the minimum required to keep the true ankle on the
    # requested floor plane.
    var radius: float = maxf(0.001,
        upper_len + lower_len - IK_MARGIN_METERS)
    var delta: Vector3 = ankle - hip
    var result_ankle: Vector3 = ankle
    var unreachable_vertical: float = maxf(absf(delta.y) - radius, 0.0)
    if unreachable_vertical > 0.0:
        # This is an explicit geometric failure, not a hidden
        # Y-only foot teleport or an accumulated root pitch.
        return {"ankle": ankle, "sole": sole,
            "vertical_unreachable": unreachable_vertical,
            "horizontal_contraction": 0.0}
    var lateral: Vector2 = Vector2(delta.x, delta.z)
    var max_lateral: float = sqrt(maxf(
        radius * radius - delta.y * delta.y, 0.0))
    var correction: float = maxf(lateral.length() - max_lateral, 0.0)
    if correction > 0.0 and lateral.length() > 0.00001:
        var reduced: Vector2 = lateral.normalized() * max_lateral
        result_ankle.x = hip.x + reduced.x
        result_ankle.z = hip.z + reduced.y
    var shift: Vector3 = result_ankle - ankle
    return {"ankle": result_ankle, "sole": sole + shift,
        "vertical_unreachable": 0.0,
        "horizontal_contraction": correction}


static func continuous_pole(hip: Vector3, previous_knee: Vector3,
        source_knee: Vector3, progress: float) -> Vector3:
    var from_axis: Vector3 = previous_knee - hip
    var to_axis: Vector3 = source_knee - hip
    if from_axis.length_squared() < 0.0001:
        return source_knee
    if to_axis.length_squared() < 0.0001:
        return previous_knee
    var t: float = clampf(progress, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    var from_dir: Vector3 = from_axis.normalized()
    var to_dir: Vector3 = to_axis.normalized()
    # Antiparallel directions cannot be slerped deterministically.
    # Choose a stable perpendicular to prevent knee-pole sign flips.
    if from_dir.dot(to_dir) < -0.999:
        var side: Vector3 = from_dir.cross(Vector3.UP)
        if side.length_squared() < 0.00001:
            side = from_dir.cross(Vector3.RIGHT)
        var intermediate: Vector3 = side.normalized()
        var blended: Vector3 = (
            from_dir.slerp(intermediate, t * 2.0)
            if t < 0.5 else
            intermediate.slerp(to_dir, (t - 0.5) * 2.0))
        return hip + blended * lerpf(
            from_axis.length(), to_axis.length(), t)
    return hip + from_dir.slerp(to_dir, t) * lerpf(
        from_axis.length(), to_axis.length(), t)


static func fitted_sole_local(sole: Vector3, ankle: Vector3,
        rotation: Quaternion, world_scale: Vector3) -> Vector3:
    var relative: Vector3 = Basis(rotation).inverse() * (
        sole - ankle)
    return Vector3(
        relative.x / maxf(absf(world_scale.x), 0.0001),
        relative.y / maxf(absf(world_scale.y), 0.0001),
        relative.z / maxf(absf(world_scale.z), 0.0001))

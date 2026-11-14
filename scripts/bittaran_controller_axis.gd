extends RefCounted
## Stable screen-space Bittaran lock direction. Keep the real 3D
## SERA-center -> aim projection when it agrees with the horizontal combat
## direction, but do not let a high HEAD/shin or camera near-plane reverse
## the controller by 180 degrees. No input coordinates are consulted.
const FLICK = preload("res://scripts/flick_direction_policy.gd")

# A very short XZ line has no meaningful facing: hold the last axis.
const MIN_PLANAR_DISTANCE_METERS: float = 0.12
const MIN_PIXELS_SQUARED: float = 16.0

static func heading(camera: Camera3D, actor_center: Vector3,
        locked_point: Vector3, last_axis: Vector2 = Vector2.UP) -> Vector2:
    var previous: Vector2 = (last_axis.normalized()
        if last_axis.length_squared() > 0.000001 else Vector2.UP)
    if camera == null:
        return previous

    # An aim point can be higher or lower than the player. The XZ line is
    # authoritative for choosing which HALF of the controller is 'front'.
    var on_actor_plane := Vector3(locked_point.x, actor_center.y,
        locked_point.z)
    var planar: Vector3 = on_actor_plane - actor_center
    if planar.length_squared() <= (
            MIN_PLANAR_DISTANCE_METERS * MIN_PLANAR_DISTANCE_METERS):
        return previous

    # Camera-basis projection remains defined even when either actor
    # crosses the camera near-plane during a rapid orbit/camera catch-up.
    # Never fall back to a fixed screen-UP there.
    var world_basis: Basis = camera.global_transform.basis
    var stable := Vector2(
        planar.dot(world_basis.x), -planar.dot(world_basis.y))
    if stable.length_squared() < 0.000001:
        return previous
    stable = stable.normalized()
    var ground_axis: Vector2 = stable
    if not camera.is_position_behind(actor_center) and not camera.is_position_behind(
            on_actor_plane):
        var ground_pixels: Vector2 = (camera.unproject_position(on_actor_plane)
            - camera.unproject_position(actor_center))
        # Reject perspective near-plane inversions before treating a raw
        # planar pixel vector as a heading.
        if ground_pixels.length_squared() >= MIN_PIXELS_SQUARED and (
                ground_pixels.normalized().dot(stable) > 0.0):
            ground_axis = ground_pixels.normalized()

    if camera.is_position_behind(actor_center) or camera.is_position_behind(
            locked_point):
        return ground_axis
    var aim_pixels: Vector2 = (camera.unproject_position(locked_point)
        - camera.unproject_position(actor_center))
    if aim_pixels.length_squared() < MIN_PIXELS_SQUARED:
        return ground_axis

    var actual: Vector2 = aim_pixels.normalized()
    var agreement: float = actual.dot(ground_axis)
    # HEAD elevation can move the projected lock marker above SERA while
    # SERA is physically BEHIND the boss. Blend toward the ground-heading
    # before 90 degrees, with continuous behavior even at exact opposition.
    # This preserves the 3D direction whenever both projections agree.
    var three_dimensional_weight: float = smoothstep(0.35, 0.75, agreement)
    var blended: Vector2 = ground_axis.lerp(actual, three_dimensional_weight)
    return blended.normalized() if blended.length_squared() > 0.000001         else ground_axis

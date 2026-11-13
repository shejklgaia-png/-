extends RefCounted
## Stateless movement-frame transforms extracted from main.gd v317.
## Screen-space physics travel and actor-relative pose selection stay separate.

static func screen_drag_to_ground(screen_drag: Vector2, camera_basis: Basis) -> Vector3:
    # InputEvent positions use screen +X=right and +Y=down.
    # Camera basis.x is screen-right; -basis.z is screen-forward.
    if screen_drag.length_squared() < 0.000001:
        return Vector3.ZERO
    var screen_right: Vector3 = camera_basis.x
    screen_right.y = 0.0
    var screen_forward: Vector3 = -camera_basis.z
    screen_forward.y = 0.0
    if screen_right.length_squared() < 0.000001 or screen_forward.length_squared() < 0.000001:
        return Vector3(screen_drag.x, 0.0, screen_drag.y).limit_length(1.0)
    screen_right = screen_right.normalized()
    screen_forward = screen_forward.normalized()
    return (screen_right * screen_drag.x - screen_forward * screen_drag.y).limit_length(1.0)


static func step_local_pose_direction(world_direction: Vector3,
        locked_facing: Vector3, player_forward: Vector3) -> Vector2:
    if world_direction.length_squared() < 0.000001:
        return Vector2.UP
    var facing: Vector3 = locked_facing
    if facing.length_squared() < 0.000001:
        facing = player_forward
    facing.y = 0.0
    if facing.length_squared() < 0.000001:
        return Vector2.UP
    facing = facing.normalized()
    var right: Vector3 = facing.cross(Vector3.UP)
    var world_unit: Vector3 = world_direction.normalized()
    return Vector2(world_unit.dot(right), -world_unit.dot(facing)).normalized()

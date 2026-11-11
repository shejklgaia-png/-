extends RefCounted
## Shared SERA flick direction: project the visible character forward and
## test all directional action gestures against a snapshot of this screen axis.
## New action recognizers MUST NOT hard-code screen-UP or world-Z.

static func projected_forward(camera: Camera3D, actor: Node3D) -> Vector2:
    if camera == null or actor == null:
        return Vector2.UP
    var from_world: Vector3 = actor.global_position + Vector3.UP * 1.05
    var forward_world: Vector3 = -actor.global_transform.basis.z
    forward_world.y = 0.0
    if forward_world.length_squared() < 0.000001:
        return Vector2.UP
    var to_world: Vector3 = from_world + forward_world.normalized()
    if camera.is_position_behind(from_world) or camera.is_position_behind(to_world):
        return Vector2.UP
    var screen_forward: Vector2 = (
        camera.unproject_position(to_world) - camera.unproject_position(from_world))
    if screen_forward.length_squared() < 0.000001:
        return Vector2.UP
    return screen_forward.normalized()

static func within_sector(displacement: Vector2, screen_axis: Vector2,
        lateral_ratio: float) -> bool:
    if displacement.length_squared() < 0.000001 or screen_axis.length_squared() < 0.000001:
        return false
    var axis: Vector2 = screen_axis.normalized()
    var forward_amount: float = displacement.dot(axis)
    var sideways_amount: float = absf(displacement.cross(axis))
    return forward_amount > 0.0 and (
        sideways_amount <= forward_amount * maxf(lateral_ratio, 0.0))

static func is_flick(displacement: Vector2, seconds: float,
        screen_axis: Vector2, max_seconds: float, min_forward_pixels: float,
        min_forward_speed: float, lateral_ratio: float) -> bool:
    if seconds <= 0.0 or seconds > max_seconds:
        return false
    if not within_sector(displacement, screen_axis, lateral_ratio):
        return false
    var forward_amount: float = displacement.dot(screen_axis.normalized())
    return (forward_amount >= min_forward_pixels
        and forward_amount / seconds >= min_forward_speed)

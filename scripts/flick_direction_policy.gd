extends RefCounted
## v262: STEP uses the full normalized 360-degree screen flick vector.
## Four 90-degree combat sectors are SERA-facing in screen space (v329).
const SECTOR_COUNT: int = 4
const SECTOR_ANGLE: float = TAU / 4.0

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

# 360-degree screen deltas relative to supplied reference axis. Exact clockwise
# boundary (+45 degrees) is classified as the clockwise neighbor.
static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:
    if displacement.length_squared() < 0.000001 or screen_axis.length_squared() < 0.000001:
        return -1
    var forward: Vector2 = screen_axis.normalized()
    var right: Vector2 = Vector2(-forward.y, forward.x)
    var angle: float = atan2(displacement.dot(right), displacement.dot(forward))
    return posmod(floori((angle + SECTOR_ANGLE * 0.5) / SECTOR_ANGLE),
        SECTOR_COUNT)

# Convert a sector into one of the four cardinal animation directions.
# This is a reusable quantizer: STEP uses its continuous screen vector,
# while Bash and Combo Kick use the captured actor-facing axis.
static func four_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:
    var sector: int = sector_index(displacement, screen_axis)
    if sector < 0:
        return Vector2.ZERO
    return Vector2.UP.rotated(float(sector) * SECTOR_ANGLE)

# No 90-degree STEP quantization: physics and four-clip pose blend share
# the identical normalized raw screen direction, including diagonals.
static func screen_step_direction(displacement: Vector2) -> Vector2:
    if displacement.length_squared() < 0.000001:
        return Vector2.ZERO
    return displacement.normalized()

# Compatibility parameter deliberately ignored. The 90-degree front
# sector defines the complete Bash direction gate; an additional 0.42
# side/forward ratio would accidentally narrow it back to ~45 degrees.
static func within_sector(displacement: Vector2, screen_axis: Vector2,
        _lateral_ratio: float) -> bool:
    return sector_index(displacement, screen_axis) == 0

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

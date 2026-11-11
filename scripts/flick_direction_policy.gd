extends RefCounted
## Shared SERA flick direction: project the visible character forward and
## test all directional action gestures against a snapshot of this screen axis.
## New action recognizers MUST NOT hard-code screen-UP or world-Z.
## v254: every direction is assigned to exactly one of eight 45-degree
## sectors (center +/-22.5 degrees), relative to a supplied visible axis.
## STEP uses screen-UP as its axis; Bash uses SERA's projected facing.
const SECTOR_COUNT: int = 8
const SECTOR_ANGLE: float = TAU / float(SECTOR_COUNT)

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

# Sector index: 0=FORWARD, 1=FORWARD_RIGHT, 2=RIGHT, 3=BACK_RIGHT,
# 4=BACK, 5=BACK_LEFT, 6=LEFT, 7=FORWARD_LEFT.  Returned headings are
# clockwise in viewport coordinates, relative to screen_axis.
# At exact boundaries, clockwise sector wins. -1 means no direction.
static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:
    if displacement.length_squared() < 0.000001 or screen_axis.length_squared() < 0.000001:
        return -1
    var forward: Vector2 = screen_axis.normalized()
    var right: Vector2 = Vector2(-forward.y, forward.x)
    var angle: float = atan2(displacement.dot(right), displacement.dot(forward))
    return posmod(floori((angle + SECTOR_ANGLE * 0.5) / SECTOR_ANGLE),
        SECTOR_COUNT)

# Convert screen-space finger travel into the eight discrete relative
# gameplay directions, then pass that normalized 2D vector to STEP/pose.
# The supplied screen_axis determines only which sector is selected.
static func eight_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:
    var sector: int = sector_index(displacement, screen_axis)
    if sector < 0:
        return Vector2.ZERO
    return Vector2.UP.rotated(float(sector) * SECTOR_ANGLE)

static func within_sector(displacement: Vector2, screen_axis: Vector2,
        lateral_ratio: float) -> bool:
    if displacement.length_squared() < 0.000001 or screen_axis.length_squared() < 0.000001:
        return false
    var axis: Vector2 = screen_axis.normalized()
    var forward_amount: float = displacement.dot(axis)
    var sideways_amount: float = absf(displacement.cross(axis))
    # The forward action occupies only sector 0, a fixed 45-degree wedge.
    # Keep a narrower caller-specific tolerance when requested.
    return (sector_index(displacement, screen_axis) == 0
        and forward_amount > 0.0
        and sideways_amount <= forward_amount * maxf(lateral_ratio, 0.0))

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

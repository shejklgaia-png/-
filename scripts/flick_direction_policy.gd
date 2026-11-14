extends RefCounted
## v262: STEP uses the full normalized 360-degree screen flick vector.
## Four 90-degree combat sectors are SERA-facing in screen space (v329).
const SECTOR_COUNT: int = 4
const SECTOR_ANGLE: float = TAU / 4.0

# The controller must use the VISIBLE SERA's projected front, not only
# CharacterBody3D's target-facing collision root. During RUN the rendered
# Waist, upper body and head have independent authored/procedural yaw.
# visual_pivot is the actual head/upper-body Node3D sampled after rig pose.
# The fallback keeps old callers and missing/unloaded rigs operational.
static func projected_forward(camera: Camera3D, actor: Node3D,
        visual_pivot: Node3D = null) -> Vector2:
    if camera == null or actor == null:
        return Vector2.UP
    var from_world: Vector3 = actor.global_position + Vector3.UP * 1.05
    var forward_world: Vector3 = -actor.global_transform.basis.z
    if is_instance_valid(visual_pivot):
        var visual_forward: Vector3 = -visual_pivot.global_transform.basis.z
        visual_forward.y = 0.0
        if visual_forward.length_squared() > 0.0001:
            from_world = visual_pivot.global_position
            forward_world = visual_forward
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

# v333: A lock-target-relative front is the XZ line from SERA's world
# position to the selected part's authored aim pivot. Project a one-metre
# planar direction at torso height to avoid camera pitch/target height
# rotating the front sector, and do NOT depend on animated Head or Waist.
static func projected_lock_forward(camera: Camera3D, actor_world: Vector3,
        lock_direction: Vector3, fallback: Vector2 = Vector2.UP) -> Vector2:
    if camera == null:
        return fallback
    var planar: Vector3 = Vector3(lock_direction.x, 0.0, lock_direction.z)
    if planar.length_squared() < 0.000001:
        return fallback
    var start: Vector3 = actor_world + Vector3.UP * 1.05
    var finish: Vector3 = start + planar.normalized()
    if camera.is_position_behind(start) or camera.is_position_behind(finish):
        return fallback
    var pixels: Vector2 = (
        camera.unproject_position(finish) - camera.unproject_position(start))
    if pixels.length_squared() < 0.000001:
        return fallback
    return pixels.normalized()


# The directional UI points from SERA's projected torso to the SAME
# authored 3D aim point used by the lock-on marker. Projecting a planar
# one-metre offset (v333) changes the apparent screen angle when head/legs
# sit at a different height, especially at close camera distances.
static func projected_target_line(camera: Camera3D,
        actor_torso_world: Vector3, target_aim_world: Vector3,
        fallback: Vector2 = Vector2.UP) -> Vector2:
    if camera == null or camera.is_position_behind(actor_torso_world) \
            or camera.is_position_behind(target_aim_world):
        return fallback
    var delta_screen: Vector2 = (
        camera.unproject_position(target_aim_world)
        - camera.unproject_position(actor_torso_world))
    # At nearly coincident points, perspective projection has no stable
    # horizontal direction: keep the last valid / planar heading.
    if delta_screen.length_squared() < 16.0:
        return fallback
    return delta_screen.normalized()


# v337: The front sector starts at the finger-down SCREEN coordinate and
# points to the locked part's raw Camera3D projection (never the edge-clamped
# indicator). One caller can freeze this for an entire swipe so camera and
# target motion cannot change the result partway through a combo.
static func touch_to_target_forward(camera: Camera3D,
        touch_screen: Vector2, target_world: Vector3,
        fallback: Vector2 = Vector2.UP) -> Vector2:
    if camera == null or camera.is_position_behind(target_world):
        return fallback
    var toward_lock: Vector2 = camera.unproject_position(target_world) - touch_screen
    # A finger on top of the lock marker has no geometrically defined
    # forward axis; use the stable supplied fallback, not a random quadrant.
    if toward_lock.length_squared() < 16.0:
        return fallback
    return toward_lock.normalized()


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

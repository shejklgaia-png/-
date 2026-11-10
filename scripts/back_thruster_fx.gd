extends Node3D
## v219: decagonal hollow back-thruster exhaust with wobbling emissive walls.
## Authored nozzle group provides the origin; direction is limited relative to
## its actual animated/rotated Blockbench pivot. Separate from SLIDE mode.
const FLAME_SHADER = preload("res://shaders/back_thruster.gdshader")
const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0
const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0
const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0
const TURN_TIME: float = 0.075
const EXHAUST_LENGTH: float = 0.65
# Vertex deformation needs intermediate rings: two end-caps cannot form a
# rapid flare close to the nozzle, only a linearly tapered giant triangle.
const EXHAUST_AXIAL_SEGMENTS: int = 12
# A 10-sided cross-section softens the outline without adding particles.
const EXHAUST_RADIAL_SIDES: int = 10
# Acceleration flares to 15x within the near-nozzle quarter of the jet.
const BURST_RISE_SECONDS: float = 0.05
const BURST_FALL_SECONDS: float = 0.18
const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS
var burst_elapsed: float = BURST_TOTAL_SECONDS
var outer_material: ShaderMaterial
var inner_material: ShaderMaterial
var current_strength: float = 0.0
var nozzle_rest_rotation: Quaternion = Quaternion.IDENTITY
var steering_yaw: float = 0.0
var steering_pitch: float = 0.0
var returning_from_screen_sector: bool = false

func _ready() -> void:
    # The Blockbench Thruster_L/R group pivot, not this FX child, is the hinge.
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle != null:
        nozzle_rest_rotation = nozzle.quaternion
        # The default/idle posture is already down before the first frame.
        steering_pitch = PITCH_DOWN_LIMIT_RADIANS
        nozzle.quaternion = (nozzle_rest_rotation
            * Quaternion(Vector3.RIGHT, steering_pitch)).normalized()
    outer_material = _build_tube(0.058, EXHAUST_LENGTH, Color(0.17, 0.63, 0.95, 0.53), 0.0)
    inner_material = _build_tube(0.029, EXHAUST_LENGTH * 0.83,
        Color(0.66, 0.91, 1.0, 0.48), 1.7)
    visible = false

func _build_tube(half_width: float, length: float, tint: Color,
        offset: float) -> ShaderMaterial:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Generate the 10-sided tube around +Z, keeping the same nominal
    # diameter as the previous square's flat-to-flat width (2*half_width).
    # Adjacent segments share the same circle points, so the mesh has no gaps.
    for side in range(EXHAUST_RADIAL_SIDES):
        var start_angle: float = TAU * float(side) / float(EXHAUST_RADIAL_SIDES)
        var end_angle: float = TAU * float(side + 1) / float(EXHAUST_RADIAL_SIDES)
        var a := Vector2(cos(start_angle), sin(start_angle)) * half_width
        var b := Vector2(cos(end_angle), sin(end_angle)) * half_width
        for section in range(EXHAUST_AXIAL_SEGMENTS):
            var t0: float = float(section) / float(EXHAUST_AXIAL_SEGMENTS)
            var t1: float = float(section + 1) / float(EXHAUST_AXIAL_SEGMENTS)
            var z0: float = length * t0
            var z1: float = length * t1
            var vertices := [
                Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0),
                Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)
            ]
            var uvs := [Vector2(0.0, t0), Vector2(1.0, t0),
                Vector2(1.0, t1), Vector2(0.0, t1)]
            for corner_index in [0, 1, 2, 0, 2, 3]:
                tool.set_uv(uvs[corner_index])
                tool.set_normal(Vector3.BACK)
                tool.add_vertex(vertices[corner_index])
    var instance := MeshInstance3D.new()
    instance.name = "DecagonalExhaustCore" if offset > 0.0 else "DecagonalExhaustShell"
    instance.mesh = tool.commit()
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Keep transparent shader on its own instances, not on the shared SERA mesh.
    var material := ShaderMaterial.new()
    material.shader = FLAME_SHADER
    material.set_shader_parameter("flame_tint", tint)
    material.set_shader_parameter("tube_length", length)
    material.set_shader_parameter("phase_offset", offset)
    material.set_shader_parameter("strength", 0.0)
    material.set_shader_parameter("burst", 0.0)
    instance.material_override = material
    add_child(instance)
    return material

func set_exhaust(enabled: bool, world_exhaust_direction: Vector3,
        delta: float, backstroke_weight: float = 0.0,
        left_sector_world: Vector3 = Vector3.ZERO,
        acceleration_burst: bool = false) -> void:
    if outer_material == null or inner_material == null:
        return
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle == null or not (nozzle.get_parent() is Node3D):
        return
    # Rotate the authored 3D nozzle itself, carrying its exhaust lip along.
    var yaw: float = 0.0
    var pitch: float = PITCH_DOWN_LIMIT_RADIANS
    if enabled and world_exhaust_direction.length_squared() > 0.000001:
        # Use the authored REST axes; using the rotating nozzle basis feeds the
        # steering angle back into itself and can cause oscillation.
        var nozzle_parent: Node3D = nozzle.get_parent() as Node3D
        var rest_basis: Basis = (
            nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)).orthonormalized()
        var local_dir: Vector3 = (
            rest_basis.inverse() * world_exhaust_direction.normalized()).normalized()
        var rear_denominator: float = (maxf(local_dir.z, 0.0)
            + 2.0 * maxf(-local_dir.z, 0.0) + 0.02)
        var requested_yaw: float = atan2(local_dir.x, rear_denominator)
        yaw = clampf(requested_yaw, -YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS)
        var horizontal: float = sqrt(local_dir.x * local_dir.x + local_dir.z * local_dir.z)
        pitch = clampf(-atan2(local_dir.y, horizontal),
            -PITCH_UP_LIMIT_RADIANS, PITCH_DOWN_LIMIT_RADIANS)
        # Reverse BOOST and reverse STEP deliberately point the real nozzles
        # DOWN instead of flipping the jets forward: backstroke-like travel.
        # At 100% rearward, yaw=0 and pitch=+90 degrees around each authored
        # Thruster_L/R pivot. Rear diagonals interpolate without snapping.
        var backstroke: float = clampf(backstroke_weight, 0.0, 1.0)
        yaw = lerpf(yaw, 0.0, backstroke)
        pitch = lerpf(pitch, PITCH_DOWN_LIMIT_RADIANS, backstroke)
    # Inactive nozzle softly returns to a downward default, using the same
    # 3D nozzle pivot. Exhaust geometry remains attached to that pivot.
    var ease: float = 1.0 - exp(-maxf(delta, 0.0) / TURN_TIME)
    steering_yaw = lerp_angle(steering_yaw, yaw, ease)
    steering_pitch = lerp_angle(steering_pitch, pitch, ease)
    var normal_quaternion: Quaternion = (nozzle_rest_rotation
        * Quaternion(Vector3.UP, steering_yaw)
        * Quaternion(Vector3.RIGHT, steering_pitch)).normalized()
    if enabled and left_sector_world.length_squared() > 0.000001:
        # The special LEFT motion is bounded by the screen's DOWN->RIGHT
        # quadrant, rather than yaw/pitch angles relative to the moving Chest.
        # Convert the screen-space jet to the authored REST nozzle axes.
        # This rotates the actual 3D metal nozzle AND its child jet together.
        var nozzle_parent: Node3D = nozzle.get_parent() as Node3D
        var rest_basis: Basis = (
            nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)).orthonormalized()
        var local_sector_direction: Vector3 = (
            rest_basis.inverse() * left_sector_world.normalized()).normalized()
        var screen_sector_quaternion: Quaternion = (nozzle_rest_rotation
            * Quaternion(Vector3.BACK, local_sector_direction)).normalized()
        nozzle.quaternion = nozzle.quaternion.slerp(
            screen_sector_quaternion, ease).normalized()
        returning_from_screen_sector = true
    elif returning_from_screen_sector:
        # Exit the special quadrant without snapping to the standard yaw/
        # pitch servo. Outside this transition normal steering is unchanged.
        nozzle.quaternion = nozzle.quaternion.slerp(
            normal_quaternion, ease).normalized()
        if nozzle.quaternion.angle_to(normal_quaternion) < deg_to_rad(0.5):
            returning_from_screen_sector = false
    else:
        nozzle.quaternion = normal_quaternion
    visible = enabled
    if not enabled:
        current_strength = 0.0
        burst_elapsed = BURST_TOTAL_SECONDS
        outer_material.set_shader_parameter("burst", 0.0)
        inner_material.set_shader_parameter("burst", 0.0)
        return
    if acceleration_burst:
        burst_elapsed = 0.0
    burst_elapsed = minf(BURST_TOTAL_SECONDS, burst_elapsed + maxf(delta, 0.0))
    var burst: float = 0.0
    if burst_elapsed < BURST_RISE_SECONDS:
        # The flare opens outward over the first 0.05s, reaching its widest tip.
        burst = burst_elapsed / BURST_RISE_SECONDS
    elif burst_elapsed < BURST_TOTAL_SECONDS:
        # Ease smoothly back to the ordinary narrow exhaust over 0.18s.
        var fall: float = clampf(
            (burst_elapsed - BURST_RISE_SECONDS) / BURST_FALL_SECONDS, 0.0, 1.0)
        burst = 1.0 - fall * fall * (3.0 - 2.0 * fall)
    current_strength = lerpf(current_strength, 1.0,
        1.0 - exp(-maxf(delta, 0.0) / 0.045))
    outer_material.set_shader_parameter("strength", current_strength)
    inner_material.set_shader_parameter("strength", current_strength)
    outer_material.set_shader_parameter("burst", burst)
    inner_material.set_shader_parameter("burst", burst)

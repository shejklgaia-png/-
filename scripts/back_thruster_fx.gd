extends Node3D
## v206: rectangular hollow back-thruster exhaust with wobbling emissive walls.
## Authored nozzle group provides the origin; direction is limited relative to
## its actual animated/rotated Blockbench pivot. Separate from SLIDE mode.
const FLAME_SHADER = preload("res://shaders/back_thruster.gdshader")
const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0
const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0
const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0
const TURN_TIME: float = 0.075
const EXHAUST_LENGTH: float = 0.65
var outer_material: ShaderMaterial
var inner_material: ShaderMaterial
var current_strength: float = 0.0
var nozzle_rest_rotation: Quaternion = Quaternion.IDENTITY
var steering_yaw: float = 0.0
var steering_pitch: float = 0.0

func _ready() -> void:
    # The Blockbench Thruster_L/R group pivot, not this FX child, is the hinge.
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle != null:
        nozzle_rest_rotation = nozzle.quaternion
    outer_material = _build_tube(0.058, EXHAUST_LENGTH, Color(0.17, 0.63, 0.95, 0.53), 0.0)
    inner_material = _build_tube(0.029, EXHAUST_LENGTH * 0.83,
        Color(0.66, 0.91, 1.0, 0.48), 1.7)
    visible = false

func _build_tube(half_width: float, length: float, tint: Color,
        offset: float) -> ShaderMaterial:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var corners := [Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
        Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]
    for side in range(4):
        var a: Vector2 = corners[side] * half_width
        var b: Vector2 = corners[(side + 1) % 4] * half_width
        var vertices := [
            Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0),
            Vector3(b.x, b.y, length), Vector3(a.x, a.y, length)
        ]
        var uvs := [Vector2(0.0, 0.0), Vector2(1.0, 0.0),
            Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
        for corner_index in [0, 1, 2, 0, 2, 3]:
            tool.set_uv(uvs[corner_index])
            tool.set_normal(Vector3.BACK)
            tool.add_vertex(vertices[corner_index])
    var instance := MeshInstance3D.new()
    instance.name = "RectangularExhaustCore" if offset > 0.0 else "RectangularExhaustShell"
    instance.mesh = tool.commit()
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Keep transparent shader on its own instances, not on the shared SERA mesh.
    var material := ShaderMaterial.new()
    material.shader = FLAME_SHADER
    material.set_shader_parameter("flame_tint", tint)
    material.set_shader_parameter("tube_length", length)
    material.set_shader_parameter("phase_offset", offset)
    material.set_shader_parameter("strength", 0.0)
    instance.material_override = material
    add_child(instance)
    return material

func set_exhaust(enabled: bool, world_exhaust_direction: Vector3,
        delta: float, backstroke_weight: float = 0.0) -> void:
    if outer_material == null or inner_material == null:
        return
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle == null or not (nozzle.get_parent() is Node3D):
        return
    # Rotate the authored 3D nozzle itself, carrying its exhaust lip along.
    var yaw: float = 0.0
    var pitch: float = 0.0
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
    # Inactive nozzle softly returns to its authored zero-rotation angle.
    var ease: float = 1.0 - exp(-maxf(delta, 0.0) / TURN_TIME)
    steering_yaw = lerp_angle(steering_yaw, yaw, ease)
    steering_pitch = lerp_angle(steering_pitch, pitch, ease)
    nozzle.quaternion = (nozzle_rest_rotation
        * Quaternion(Vector3.UP, steering_yaw)
        * Quaternion(Vector3.RIGHT, steering_pitch)).normalized()
    visible = enabled
    if not enabled:
        current_strength = 0.0
        return
    current_strength = lerpf(current_strength, 1.0,
        1.0 - exp(-maxf(delta, 0.0) / 0.045))
    outer_material.set_shader_parameter("strength", current_strength)
    inner_material.set_shader_parameter("strength", current_strength)

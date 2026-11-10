extends Node3D
## v206: rectangular hollow back-thruster exhaust with wobbling emissive walls.
## Authored nozzle group provides the origin; direction is limited relative to
## its actual animated/rotated Blockbench pivot. Separate from SLIDE mode.
const FLAME_SHADER = preload("res://shaders/back_thruster.gdshader")
const YAW_LIMIT_RADIANS: float = PI * 38.0 / 180.0
const PITCH_LIMIT_RADIANS: float = PI * 24.0 / 180.0
const TURN_TIME: float = 0.075
const EXHAUST_LENGTH: float = 0.65
var outer_material: ShaderMaterial
var inner_material: ShaderMaterial
var current_strength: float = 0.0

func _ready() -> void:
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
        delta: float) -> void:
    if outer_material == null or inner_material == null:
        return
    # No grace when BOOST/STEP/homing stops: SLIDE and idle never show FX.
    visible = enabled
    if not enabled:
        current_strength = 0.0
        return
    current_strength = lerpf(current_strength, 1.0,
        1.0 - exp(-maxf(delta, 0.0) / 0.045))
    if world_exhaust_direction.length_squared() > 0.000001:
        # Inverse parent basis: rotating the effect itself must NOT feed back
        # into the requested angle. The parent inherits animated Chest pivots.
        var nozzle: Node3D = get_parent() as Node3D
        var local_dir: Vector3 = (
            nozzle.global_transform.basis.inverse()
            * world_exhaust_direction.normalized()).normalized()
        # Exhaust faces local +Z. A reverse STEP would require 180 degrees;
        # clamp each axis instead to avoid a tube crossing the character.
        # If the request points almost directly ahead of the character,
        # 180 degrees cannot be achieved. Keep the nozzle centered rather
        # than snapping unpredictably to one side of the cone.
        var requested_yaw: float = atan2(local_dir.x, local_dir.z)
        if local_dir.z < 0.0 and absf(local_dir.x) < 0.035:
            requested_yaw = 0.0
        var yaw: float = clampf(requested_yaw,
            -YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS)
        var horizontal: float = sqrt(local_dir.x * local_dir.x + local_dir.z * local_dir.z)
        var pitch: float = clampf(-atan2(local_dir.y, horizontal),
            -PITCH_LIMIT_RADIANS, PITCH_LIMIT_RADIANS)
        var ease: float = 1.0 - exp(-maxf(delta, 0.0) / TURN_TIME)
        rotation.y = lerp_angle(rotation.y, yaw, ease)
        rotation.x = lerp_angle(rotation.x, pitch, ease)
        rotation.z = 0.0
    outer_material.set_shader_parameter("strength", current_strength)
    inner_material.set_shader_parameter("strength", current_strength)

extends Node3D
## Animated, depth-tested energy shells and jagged electrical discharge.
## Visual-only: never changes beam range, player damage or boss rig bones.
## One ImmediateMesh surface per effect; rebuild at <= 20 Hz for Android.

const RIM_SHADER = preload("res://shaders/bittaran_railgun_rim.gdshader")
const FLOW_SHADER = preload("res://shaders/bittaran_railgun_flow.gdshader")
const ARC_INTERVAL: float = 0.055
const ORB_ARC_COUNT: int = 12
const BEAM_ARC_COUNT: int = 18
const ORB_RADIUS: float = 0.612
const ORB_LINE_HALF_WIDTH: float = 0.012
const BEAM_LINE_HALF_WIDTH: float = 0.016

var orb_rim: MeshInstance3D
var orb_arcs: MeshInstance3D
var beam_flow: MeshInstance3D
var beam_arcs: MeshInstance3D
var orb_mesh: ImmediateMesh
var beam_mesh: ImmediateMesh
var muzzle_z: float = 0.0
var beam_length: float = 1.0
var last_orb_tick: int = -1
var last_beam_tick: int = -1


func _glow_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color(0.49, 0.89, 1.0, 0.94)
    mat.emission_enabled = true
    mat.emission = Color(0.34, 0.76, 1.0)
    mat.emission_energy_multiplier = 5.0
    return mat


func _part(part_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = mesh
    part.material_override = mat
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    part.visible = false
    add_child(part)
    return part


func setup(muzzle_local_z: float, local_beam_length: float) -> void:
    muzzle_z = muzzle_local_z
    beam_length = local_beam_length
    var rim_shape := SphereMesh.new()
    rim_shape.radius = 0.652
    rim_shape.height = 1.304
    rim_shape.radial_segments = 24
    rim_shape.rings = 12
    var rim_mat := ShaderMaterial.new()
    rim_mat.shader = RIM_SHADER
    orb_rim = _part("RailgunElectricBlueRim", rim_shape, rim_mat)
    orb_rim.position.z = muzzle_z

    orb_mesh = ImmediateMesh.new()
    orb_arcs = _part("RailgunOrbLightning", orb_mesh, _glow_material())
    orb_arcs.position.z = muzzle_z

    var flow_shape := CylinderMesh.new()
    flow_shape.top_radius = 0.275
    flow_shape.bottom_radius = 0.275
    flow_shape.height = 1.0
    flow_shape.radial_segments = 16
    var flow_mat := ShaderMaterial.new()
    flow_mat.shader = FLOW_SHADER
    beam_flow = _part("RailgunTravelingPlasma", flow_shape, flow_mat)
    beam_flow.rotation.x = -PI * 0.5
    beam_flow.scale = Vector3(1.0, beam_length, 1.0)
    beam_flow.position.z = muzzle_z - beam_length * 0.5

    beam_mesh = ImmediateMesh.new()
    beam_arcs = _part("RailgunBeamLightning", beam_mesh, _glow_material())
    reset_fx()


func reset_fx() -> void:
    last_orb_tick = -1
    last_beam_tick = -1
    for part in [orb_rim, orb_arcs, beam_flow, beam_arcs]:
        if part != null:
            part.visible = false
    if orb_mesh != null:
        orb_mesh.clear_surfaces()
    if beam_mesh != null:
        beam_mesh.clear_surfaces()


func _noise(n: float) -> float:
    # Stateless local flicker: independent from the boss AI/gameplay RNG.
    return fposmod(sin(n * 12.9898 + 78.233) * 43758.5453, 1.0)


func _segment(mesh: ImmediateMesh, a: Vector3, b: Vector3,
        half_width: float) -> void:
    var forward: Vector3 = b - a
    if forward.length_squared() < 0.00001:
        return
    forward = forward.normalized()
    var side: Vector3 = forward.cross(Vector3.UP)
    if side.length_squared() < 0.001:
        side = forward.cross(Vector3.RIGHT)
    side = side.normalized() * half_width
    var other: Vector3 = forward.cross(side).normalized() * half_width
    # Two crossed ribbons keep electric streaks visible from either camera
    # bearing without depth-test bypass or an expensive particle emitter.
    for offset in [side, other]:
        mesh.surface_add_vertex(a - offset)
        mesh.surface_add_vertex(b - offset)
        mesh.surface_add_vertex(a + offset)
        mesh.surface_add_vertex(a + offset)
        mesh.surface_add_vertex(b - offset)
        mesh.surface_add_vertex(b + offset)


func _orb_position(index: int, j: int, seed: int) -> Vector3:
    var a: float = float(index) * 17.0 + float(seed) * 1.31
    var u: float = float(j) / 6.0
    var theta: float = 0.46 + 2.1 * u + 0.18 * _noise(a + float(j))
    var phi: float = TAU * (float(index) / float(ORB_ARC_COUNT))
    phi += 0.88 * (u - 0.5) + (
        _noise(a + float(j) * 3.0) - 0.5) * 0.56
    var radius: float = ORB_RADIUS + (
        _noise(a + float(j) * 4.0 + 4.0) - 0.5) * 0.058
    return Vector3(
        radius * sin(theta) * cos(phi),
        radius * cos(theta),
        radius * sin(theta) * sin(phi))


func _rebuild_orb(seed: int) -> void:
    orb_mesh.clear_surfaces()
    orb_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(ORB_ARC_COUNT):
        var previous: Vector3 = _orb_position(i, 0, seed)
        for j in range(1, 7):
            var point: Vector3 = _orb_position(i, j, seed)
            _segment(orb_mesh, previous, point, ORB_LINE_HALF_WIDTH)
            if j == 3 and i % 2 == 0:
                var branch: Vector3 = point + Vector3(
                    (_noise(float(i * 7 + seed)) - 0.5) * 0.28,
                    0.13,
                    (_noise(float(i * 9 + seed)) - 0.5) * 0.22)
                _segment(orb_mesh, point, branch, ORB_LINE_HALF_WIDTH * 0.7)
            previous = point
    orb_mesh.surface_end()


func _rebuild_beam(seed: int) -> void:
    beam_mesh.clear_surfaces()
    beam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(BEAM_ARC_COUNT):
        var id: float = float(seed * 13 + i * 17)
        var distance: float = fposmod(
            beam_length * (float(i) / float(BEAM_ARC_COUNT))
            + float(seed) * 0.61, maxf(beam_length - 2.2, 0.4))
        var arc_length: float = minf(
            1.75, beam_length - distance - 0.05)
        if arc_length <= 0.01:
            continue
        var phi: float = TAU * _noise(id + 0.5)
        var previous: Vector3 = Vector3(
            0.30 * cos(phi), 0.30 * sin(phi), muzzle_z - distance)
        for j in range(1, 6):
            var f: float = float(j) / 5.0
            var angle: float = phi + (
                _noise(id + float(j) * 5.0) - 0.5) * 1.2
            var radius: float = 0.29 + 0.06 * _noise(
                id + float(j) * 3.0 + 9.0)
            var point: Vector3 = Vector3(
                radius * cos(angle),
                radius * sin(angle),
                muzzle_z - distance - arc_length * f)
            _segment(beam_mesh, previous, point, BEAM_LINE_HALF_WIDTH)
            if j == 3 and i % 3 == 0:
                var fork: Vector3 = point + Vector3(
                    0.15 * cos(angle + 0.8), 0.15 * sin(angle + 0.8),
                    -0.25)
                _segment(beam_mesh, point, fork, BEAM_LINE_HALF_WIDTH * 0.7)
            previous = point
    beam_mesh.surface_end()


func tick(effect_time: float, charging_orb: bool, firing: bool,
        orb_scale: float) -> void:
    orb_rim.visible = charging_orb
    orb_arcs.visible = charging_orb
    beam_flow.visible = firing
    beam_arcs.visible = firing
    if charging_orb:
        orb_rim.scale = Vector3.ONE * orb_scale
        orb_arcs.scale = Vector3.ONE * orb_scale
        var t: int = int(floor(effect_time / ARC_INTERVAL))
        if t != last_orb_tick:
            _rebuild_orb(t)
            last_orb_tick = t
    if firing:
        # A pulsing shell plus moving blue-white jagged discharges across
        # the entire 45m laser, without changing the damage hit cylinder.
        var t: int = int(floor(effect_time / ARC_INTERVAL))
        beam_flow.scale.x = 1.0 + 0.08 * sin(effect_time * 46.0)
        beam_flow.scale.z = 1.0 + 0.08 * sin(effect_time * 46.0)
        if t != last_beam_tick:
            _rebuild_beam(t)
            last_beam_tick = t

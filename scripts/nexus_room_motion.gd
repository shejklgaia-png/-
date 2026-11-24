extends Node3D
const Modules = preload("res://assets/base_command_modules.gd")
signal deployment_pose_changed
## NEXUS room hardware animation. Built once at scene entry; no additional
## viewports, particles, timers, dynamic mesh rebuilding or lights.
## All motion is driven from one 20 Hz sampler and leaves authored selection
## meshes, source Blockbench parts, and the SERA rig untouched.

const UPDATE_STEP: float = 0.05
const FINISH_DARK: Color = Color("#273d4d")
const FINISH_METAL: Color = Color("#5c7688")
const FINISH_EDGE: Color = Color("#91aebd")
const FINISH_GLOW: Color = Color("#64d6ef")

var _accumulator: float = 0.0
var _elapsed: float = 0.0
var _deployment_requested: bool = false
var _door_open_amount: float = 0.0

var _canopy_rotor: Node3D
var _canopy_cyan_rotor: Node3D
var _scanner: Node3D
var _arm_heads: Array[Node3D] = []
var _system_fan: Node3D
var _training_sensor: Node3D
var _vent_rotors: Array[Node3D] = []
var _gate_leaves: Array[MeshInstance3D] = []


func configure(system_at: Vector3, training_at: Vector3,
        gate_at: Vector3, gate_yaw: float, gate_scale: float) -> void:
    name = "NexusRoomWorkingHardware"
    # Nonselectable, opaque metal. Visible RGB-ID object silhouettes are
    # sourced from the unchanged authored NEXUS selection geometry only.
    set_meta("sera_outline_occluder_only", true)
    set_meta("FX_NO_OUTLINE", true)
    var dark: StandardMaterial3D = _mat(FINISH_DARK)
    var metal: StandardMaterial3D = _mat(FINISH_METAL)
    var edge: StandardMaterial3D = _mat(FINISH_EDGE)
    var glow: StandardMaterial3D = _mat(FINISH_GLOW, true)
    _build_ceiling(metal, edge, glow)
    _build_scanner(metal, glow)
    _build_system_fan(system_at, dark, edge)
    _build_training_sensor(training_at, dark, metal, glow)
    _build_wall_vents(dark, edge)
    _build_deployment_shutters(gate_at, gate_yaw, gate_scale, dark, metal)
    set_process(true)


func set_deployment_open(value: bool) -> void:
    _deployment_requested = value

func is_deployment_fully_open() -> bool:
    return _door_open_amount >= 1.0


func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    _accumulator += minf(delta, 0.1)
    if _accumulator < UPDATE_STEP:
        return
    var step: float = _accumulator
    _accumulator = 0.0
    _elapsed += step

    # Constant-speed internal bearing. Outer twelve-segment ceiling support
    # stays fixed; three short radial actuator heads reciprocate independently.
    _canopy_rotor.rotation.y = fposmod(_elapsed * 0.19, TAU)
    # Camera-facing near arc travels to the LEFT. Unlike the stationary cyan
    # Blockbench optics, these are now real moving emissive mesh components.
    _canopy_cyan_rotor.rotation.y = -fposmod(_elapsed * 0.32, TAU)
    for i in range(_arm_heads.size()):
        var phase: float = _elapsed * 0.82 + float(i) * 1.95
        _arm_heads[i].position.y = -0.10 - 0.16 * (
            0.5 + 0.5 * sin(phase))

    # Contactless scan hoop remains outside SERA's equipment/weapon rig.
    _scanner.position.y = 2.11 + 0.44 * sin(_elapsed * 0.73)
    _scanner.rotation.y = 0.12 * sin(_elapsed * 0.41)

    # Small mechanical pivots may sleep offscreen. Their absolute phase
    # still advances; a zoom or editor resumes all before camera movement.
    var planes: Array[Plane] = []
    var interior := Vector3.ZERO
    var host: Node = get_parent()
    var camera: Camera3D = get_viewport().get_camera_3d()
    if is_instance_valid(camera) and is_instance_valid(host) and bool(host.get_meta("sera_nexus_room_budget", false)):
        var moving: bool = bool(host.get("in_transition"))
        for editor_name in ["placement_editor", "camera_angle_editor"]:
            var editor: Node = host.get(editor_name) as Node
            if is_instance_valid(editor) and bool(editor.get("active")):
                moving = true
        if not moving:
            planes = camera.get_frustum()
            interior = camera.project_position(get_viewport().get_visible_rect().size * 0.5,
                (camera.near + camera.far) * 0.5)
    if _motion_may_be_visible(_system_fan, 1.4, planes, interior):
        _system_fan.rotation.z = fposmod(_elapsed * 2.65, TAU)
    if _motion_may_be_visible(_training_sensor, 1.4, planes, interior):
        _training_sensor.rotation.y = 0.28 * sin(_elapsed * 0.66)
        _training_sensor.rotation.x = 0.08 * sin(_elapsed * 0.48)
    for i in range(_vent_rotors.size()):
        if _motion_may_be_visible(_vent_rotors[i], 1.4, planes, interior):
            _vent_rotors[i].rotation.z = fposmod(
                _elapsed * (1.52 + float(i) * 0.22), TAU)

    # Two armored leaves open within the existing full-size gate cheeks on
    # DEPLOYMENT selection, then retract on Back without camera/ID changes.
    var target: float = 1.0 if _deployment_requested else 0.0
    var previous_open: float = _door_open_amount
    _door_open_amount = move_toward(
        _door_open_amount, target, step / 1.25)
    if previous_open != _door_open_amount:
        var ease: float = _door_open_amount * _door_open_amount * (
            3.0 - 2.0 * _door_open_amount)
        for i in range(_gate_leaves.size()):
            var side: float = -1.0 if i == 0 else 1.0
            _gate_leaves[i].position.x = side * (0.84 + 1.15 * ease)
        deployment_pose_changed.emit()


# Frustum-plane rejection of a padded sphere is conservative at all
# camera angles. The moving light-bearing canopy and gate never use it.
func _motion_may_be_visible(pivot: Node3D, radius: float, planes: Array[Plane], interior: Vector3) -> bool:
    if not is_instance_valid(pivot):
        return false
    for plane in planes:
        var side: float = signf(plane.distance_to(interior))
        if side != 0.0 and plane.distance_to(pivot.global_position) * side < -radius:
            return false
    return true


func _build_ceiling(metal: Material, edge: Material,
        glow: Material) -> void:
    _canopy_rotor = Node3D.new()
    _canopy_rotor.name = "CeilingDriveRotor"
    _canopy_rotor.position = Vector3(0.0, 6.92, -4.75)
    add_child(_canopy_rotor)
    _ring(_canopy_rotor, "ServoBearing", 1.22, 1.34, metal)
    _build_canopy_cyan_optics()
    for i in range(3):
        var angle: float = TAU * float(i) / 3.0
        var arm := Node3D.new()
        arm.name = "CeilingServiceActuator%d" % i
        arm.rotation.y = angle
        arm.position = Vector3.ZERO
        _canopy_rotor.add_child(arm)
        _box(arm, "RadialCarriage", Vector3(0.0, -0.03, 0.93),
            Vector3(0.22, 0.15, 0.64), edge)
        var tip := Node3D.new()
        tip.name = "ReciprocatingHead"
        tip.position = Vector3(0.0, -0.10, 1.19)
        arm.add_child(tip)
        _box(tip, "ToolHousing", Vector3.ZERO,
            Vector3(0.18, 0.29, 0.20), metal)
        _box(tip, "WorkLight", Vector3(0.0, -0.16, 0.02),
            Vector3(0.12, 0.027, 0.11), glow)
        _arm_heads.append(tip)


func _build_canopy_cyan_optics() -> void:
    # Rebuild the twelve actual Blockbench luminous segments into rotating
    # MultiMeshes; sizes and offsets remain IDENTICAL to their authored shapes.
    # The original static segments are suppressed by command_nexus._module.
    # Two asymmetrically brighter markers make slow rotation perceptible.
    _canopy_cyan_rotor = Node3D.new()
    _canopy_cyan_rotor.name = "LeftRotatingCyanMaintenanceOptics"
    _canopy_cyan_rotor.position = Vector3(0.0, 7.07, -4.75)
    add_child(_canopy_cyan_rotor)
    var normal: Array[Transform3D] = []
    var markers: Array[Transform3D] = []
    var source: Array = Modules.MODULES["maintenance_canopy"]
    var canopy_origin := Vector3(0.0, 8.0, -8.95)
    for part in source:
        var label: String = str(part[0])
        if not label.begins_with("Overhead cyan maintenance optic "):
            continue
        var lo: Vector3 = _module_vec(part[1]) * Modules.UNIT
        var hi: Vector3 = _module_vec(part[2]) * Modules.UNIT
        var rotation: Vector3 = _module_vec(part[4]) * (PI / 180.0)
        var center: Vector3 = canopy_origin + (lo + hi) * 0.5
        var transform := Transform3D(
            Basis.from_euler(rotation).scaled_local(hi - lo),
            center - _canopy_cyan_rotor.position)
        var segment_index: int = int(label.trim_prefix(
            "Overhead cyan maintenance optic "))
        if segment_index in [0, 5, 9]:
            markers.append(transform)
        else:
            normal.append(transform)
    _optic_multimesh(normal, "CyanRingSegments", FINISH_GLOW)
    _optic_multimesh(markers, "BrighterCyanRotationMarkers",
        Color("#a5f4ff"))


func _optic_multimesh(transforms: Array[Transform3D], label: String,
        tint: Color) -> void:
    if transforms.is_empty():
        return
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = box
    batch.instance_count = transforms.size()
    for i in range(transforms.size()):
        batch.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = batch
    node.material_override = _mat(tint, true)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("FX_NO_OUTLINE", true)
    node.set_meta("sera_outline_occluder_only", true)
    _canopy_cyan_rotor.add_child(node)


func _module_vec(values: Array) -> Vector3:
    return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _build_scanner(metal: Material, glow: Material) -> void:
    _scanner = Node3D.new()
    _scanner.name = "SeraContactlessScanner"
    _scanner.position = Vector3(0.0, 2.11, -4.75)
    add_child(_scanner)
    _ring(_scanner, "ScannerTrack", 1.32, 1.385, metal)
    for side in [-1.0, 1.0]:
        _box(_scanner, "ScanEmitter", Vector3(side * 1.36, 0.0, 0.0),
            Vector3(0.15, 0.10, 0.14), glow)


func _build_system_fan(at: Vector3, dark: Material,
        edge: Material) -> void:
    var anchor := Node3D.new()
    anchor.name = "SystemCabinetMotion"
    anchor.position = at
    anchor.rotation.y = deg_to_rad(18.0)
    add_child(anchor)
    _box(anchor, "CoolingHubHousing", Vector3(-0.33, 0.66, 0.82),
        Vector3(0.57, 0.57, 0.08), dark)
    _system_fan = _rotor(anchor, "SystemCoolingRotor",
        Vector3(-0.33, 0.66, 0.88), 0.22, edge)


func _build_training_sensor(at: Vector3, dark: Material,
        metal: Material, glow: Material) -> void:
    var anchor := Node3D.new()
    anchor.name = "TrainingSensorMotion"
    anchor.position = at
    anchor.rotation.y = deg_to_rad(-14.0)
    add_child(anchor)
    _box(anchor, "GimbalBase", Vector3(0.78, 1.81, -0.30),
        Vector3(0.27, 0.18, 0.25), dark)
    _training_sensor = Node3D.new()
    _training_sensor.name = "TrackingGimbal"
    _training_sensor.position = Vector3(0.78, 1.88, -0.30)
    anchor.add_child(_training_sensor)
    _box(_training_sensor, "AngularSensor", Vector3(0.0, 0.06, 0.0),
        Vector3(0.32, 0.20, 0.28), metal)
    _box(_training_sensor, "OpticalLens", Vector3(0.0, 0.05, 0.15),
        Vector3(0.16, 0.11, 0.028), glow)


func _build_wall_vents(dark: Material, edge: Material) -> void:
    # The wall bays were widened separately; keep the fan units on the
    # expanded left/right facings and out of the 3D gate aperture.
    for side in [-1.0, 1.0]:
        var fixture := Node3D.new()
        fixture.name = "WallVent%d" % int(side)
        fixture.position = Vector3(side * 9.72, 4.16, -5.0)
        fixture.rotation.y = side * PI * 0.5
        add_child(fixture)
        _box(fixture, "VentFrame", Vector3.ZERO,
            Vector3(0.98, 0.98, 0.10), dark)
        _vent_rotors.append(_rotor(fixture, "VentImpeller",
            Vector3(0.0, 0.0, 0.088), 0.34, edge))


func _build_deployment_shutters(at: Vector3, yaw: float,
        scale_factor: float, dark: Material, metal: Material) -> void:
    var root := Node3D.new()
    root.name = "DeploymentSlidingArmor"
    root.position = at
    root.rotation.y = yaw
    add_child(root)
    var shutter_finish := (dark as StandardMaterial3D).duplicate() as StandardMaterial3D
    shutter_finish.albedo_color = Color.WHITE
    shutter_finish.vertex_color_use_as_albedo = true
    shutter_finish.roughness = 0.76
    shutter_finish.metallic = 0.14
    shutter_finish.metallic_specular = 0.14
    for side in [-1.0, 1.0]:
        # One mesh per leaf, with the same mechanical bounds as before.
        # All molded relief moves as part of the leaf; no static ribs can
        # remain across the open aperture.
        var leaf := _mesh(root, "SlidingGateLeaf", _portal_leaf_mesh(side), shutter_finish)
        # Clear rear slide channel: fixed load beam ends at z=-0.9585,
        # first tunnel jamb starts at z=-1.404 (1.35x authored gate).
        # The entire moving leaf occupies z=-1.20..-1.04, independent of x.
        leaf.position = Vector3(side * 0.84, 3.18, -1.12)
        leaf.scale.y = 5.68 / 5.45
        leaf.set_meta("sera_preserve_authored_material", true)
        leaf.set_meta("nexus_panel_leaf", true)
        _gate_leaves.append(leaf)
    # Gate origin, scales and offsets are already world-space metres (the
    # original Blockbench geometry was expanded by scale_factor in _module).
    # Keep this signature so its desired size can track a later gate revision.
    if scale_factor <= 0.0:
        push_warning("NEXUS animated portal requires a positive scale")


# Eight-point door profile with real thickness. An armored rim, recessed
# central panel and shallow reinforcing rails share a single vertex-color
# surface. The moving outer dimensions stay 1.63 x 5.45 x 0.16 m.
func _portal_leaf_mesh(side: float) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var profile := PackedVector2Array([
        Vector2(-0.815, -2.685), Vector2(-0.775, -2.725),
        Vector2(0.775, -2.725), Vector2(0.815, -2.685),
        Vector2(0.815, 2.685), Vector2(0.775, 2.725),
        Vector2(-0.775, 2.725), Vector2(-0.815, 2.685)])
    var rings: Array[PackedVector3Array] = []
    var depths: Array[float] = [-0.08, 0.035, 0.08, 0.08, 0.025]
    var scales: Array[Vector2] = [Vector2.ONE, Vector2.ONE, Vector2(0.96, 0.985),
        Vector2(0.77, 0.91), Vector2(0.73, 0.89)]
    for j in range(depths.size()):
        var ring := PackedVector3Array()
        for p in profile:
            ring.append(Vector3(p.x * scales[j].x, p.y * scales[j].y, depths[j]))
        rings.append(ring)
    var colors: Array[Color] = [Color("#273847"), Color("#8496a4"),
        Color("#526879"), Color("#1e2d39")]
    for j in range(4):
        for i in range(8):
            var k: int = (i + 1) % 8
            var a: Vector3 = rings[j][i]
            var b: Vector3 = rings[j][k]
            var c: Vector3 = rings[j + 1][k]
            var d: Vector3 = rings[j + 1][i]
            var outward := Vector3(a.x + b.x, a.y + b.y, 0.0)
            if j >= 1:
                outward.z = 5.0
            if j == 3:
                outward.x *= -1.0
                outward.y *= -1.0
            _portal_quad(surface, a, b, c, d, outward, colors[j])
    for i in range(1, 7):
        _portal_tri(surface, rings[0][0], rings[0][i], rings[0][i + 1],
            Vector3.FORWARD, Color("#273847"))
        _portal_tri(surface, rings[4][0], rings[4][i], rings[4][i + 1],
            Vector3.BACK, Color("#344c5d"), true)
    # Two stepped load-transfer strips are stamped into the recessed field.
    # These strips stay below the outer lip and away from the meeting seam.
    for offset in [-1.0, 1.0]:
        var y: float = offset * 1.26
        var x: float = side * 0.12
        _portal_quad(surface, Vector3(x-0.39,y-0.12,0.027),
            Vector3(x+0.39,y-0.12,0.027), Vector3(x+0.48,y+0.08,0.062),
            Vector3(x-0.48,y+0.08,0.062), Vector3.BACK, Color("#657b89"))
        _portal_quad(surface, Vector3(x-0.48,y+0.08,0.062),
            Vector3(x+0.48,y+0.08,0.062), Vector3(x+0.39,y+0.15,0.027),
            Vector3(x-0.39,y+0.15,0.027), Vector3.BACK, Color("#293c49"))
    var mesh := surface.commit()
    return mesh


func _portal_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        d: Vector3, outward: Vector3, tint: Color) -> void:
    _portal_tri(surface, a, b, c, outward, tint)
    _portal_tri(surface, a, c, d, outward, tint)


func _portal_tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        outward: Vector3, tint: Color, panel_face: bool = false) -> void:
    var normal: Vector3 = (b - a).cross(c - a).normalized()
    if normal.dot(outward) > 0.0:
        var swap: Vector3 = b
        b = c
        c = swap
    else:
        normal = -normal
    for p in [a,b,c]:
        surface.set_normal(normal)
        surface.set_color(tint)
        var uv := Vector2(0.025,0.025)
        if panel_face:
            # Map only the inset central face; keep the bevel and relief plain.
            uv = Vector2(p.x / (1.63 * 0.73) + 0.5,
                0.5 - p.y / (5.45 * 0.89))
        surface.set_uv(uv.clamp(Vector2.ZERO,Vector2.ONE))
        surface.add_vertex(p)


func _ring(parent: Node3D, label: String, inner: float,
        outer: float, material: Material) -> void:
    var torus := TorusMesh.new()
    torus.inner_radius = inner
    torus.outer_radius = outer
    torus.rings = 24
    torus.ring_segments = 6
    _mesh(parent, label, torus, material)


func _rotor(parent: Node3D, label: String, at: Vector3,
        radius: float, material: Material) -> Node3D:
    var wheel := Node3D.new()
    wheel.name = label
    wheel.position = at
    parent.add_child(wheel)
    for i in range(4):
        var spoke := Node3D.new()
        spoke.rotation.z = float(i) * PI * 0.5
        wheel.add_child(spoke)
        _box(spoke, "ImpellerBlade", Vector3(0.0, radius * 0.47, 0.0),
            Vector3(radius * 0.48, radius * 0.95, 0.045), material)
    _box(wheel, "Axle", Vector3.ZERO,
        Vector3(0.13, 0.13, 0.09), material)
    return wheel


func _box(parent: Node3D, label: String, at: Vector3,
        size: Vector3, material: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var node: MeshInstance3D = _mesh(parent, label, shape, material)
    node.position = at
    return node


func _mesh(parent: Node3D, label: String, geometry: Mesh,
        material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = geometry
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("sera_outline_occluder_only", true)
    node.set_meta("FX_NO_OUTLINE", true)
    parent.add_child(node)
    return node


func _mat(tint: Color, lit: bool = false) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = tint
    result.metallic = 0.41 if not lit else 0.0
    result.roughness = 0.54
    if lit:
        result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        result.emission_enabled = true
        result.emission = tint
        result.emission_energy_multiplier = 1.15
    return result

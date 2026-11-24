extends Node3D
const Modules = preload("res://assets/base_command_modules.gd")
signal deployment_pose_changed
signal scanner_pose_changed

const SCAN_DOCK_Y: float = 6.61
const SCAN_LOW_Y: float = 0.56
const SCAN_CYCLE: float = 24.0
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
var _scan_grid: MeshInstance3D
var _scan_material: ShaderMaterial
var _scan_head_y: float = 4.2
var _scan_radius_scale: float = 1.0
var _scan_last_pose: Vector2 = Vector2(-1,-1)
var _scan_clock: float = 0.0
var _scan_parked_for_customize: bool = false
var _scan_park_elapsed: float = 0.0
var _scan_park_from: Vector3 = Vector3.ZERO
var _scan_fill: float = 0.0
var _launch_scan: Node3D
var _launch_status: Label3D
var _launch_indicator: MeshInstance3D
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
    _build_floor_ring()
    _launch_scan = get_parent().find_child("LaunchAnimatedScan", true, false) as Node3D
    _launch_status = get_parent().find_child("LaunchAnimatedStatus", true, false) as Label3D
    _launch_indicator = get_parent().find_child("LaunchAnimatedIndicator", true, false) as MeshInstance3D
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

    _update_scanner(step)

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
    if _motion_may_be_visible(_launch_scan, 1.5, planes, interior):
        var scan_y: float = 0.05 + 0.36*fposmod(_elapsed*0.55,1.0)
        _launch_scan.position.y = 1.02+scan_y
        _launch_scan.position.z = 6.62-(1.02-0.84)*0.445+0.085-scan_y*0.445
        if is_instance_valid(_launch_status):
            var next_status: String = "READY" if _door_open_amount >= 1.0 else ("UNLOCK" if _deployment_requested else ("STANDBY" if fposmod(_elapsed,3.0)<2.6 else "SYNC"))
            if _launch_status.text != next_status:
                _launch_status.text = next_status
        if is_instance_valid(_launch_indicator):
            _launch_indicator.visible = _deployment_requested or fposmod(_elapsed,1.6)<1.15
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
    _segmented_ring(_canopy_rotor,"ServoBearing", [Vector2(1.13,-0.13),
        Vector2(1.33,-0.13),Vector2(1.42,-0.04),Vector2(1.42,0.18),
        Vector2(1.21,0.18),Vector2(1.13,0.08)],12,0.025,Color("#8195a0"))
    var fixed := Node3D.new()
    fixed.name = "CeilingInspectionCastings"
    fixed.position = Vector3(0,7.07,-4.75)
    add_child(fixed)
    _segmented_ring(fixed,"UpperLoadRing",[Vector2(1.48,0.08),
        Vector2(2.07,0.08),Vector2(2.26,0.24),Vector2(2.26,0.48),
        Vector2(2.07,0.59),Vector2(1.60,0.59),Vector2(1.48,0.40)],12,0.022,Color("#607987"))
    _segmented_ring(fixed,"UpperServiceFlange",[Vector2(1.65,0.57),
        Vector2(2.08,0.57),Vector2(2.12,0.67),Vector2(1.75,0.74),
        Vector2(1.65,0.68)],6,0.045,Color("#465c6d"))
    for i in range(3):
        var spoke := Node3D.new()
        spoke.rotation.y = TAU*float(i)/3.0
        fixed.add_child(spoke)
        _box(spoke,"LoadTransferSpoke",Vector3(0,0.65,0.92),Vector3(0.27,0.19,1.78),metal)
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
    _scanner.position = Vector3(0.0, SCAN_DOCK_Y, -4.75)
    _scanner.set_meta("sera_nexus_scan_depth_only",true)
    add_child(_scanner)
    _segmented_ring(_scanner,"ScannerTrack",[Vector2(1.32,-0.075),
        Vector2(1.46,-0.075),Vector2(1.52,-0.025),Vector2(1.52,0.055),
        Vector2(1.45,0.11),Vector2(1.32,0.075)],8,0.025,Color("#708994"))
    var optic_mat := _mat(Color("#72d9ed"),true)
    for i in range(8):
        var a: float = TAU*float(i)/8.0
        var emitter := Node3D.new()
        emitter.rotation.y = a
        _scanner.add_child(emitter)
        _box(emitter,"InwardScannerOptic",Vector3(0,0.018,1.315),
            Vector3(0.19,0.065,0.025),optic_mat)
        _box(emitter,"ScannerCartridge",Vector3(0,0.045,1.47),
            Vector3(0.21,0.135,0.15),metal)

    # Storage collar sits immediately above the scanner's top at rest,
    # outside the existing servo bearing and tool-head sweep.
    var socket := Node3D.new()
    socket.name = "ScannerDockSocket"
    socket.position = Vector3(0,SCAN_DOCK_Y+0.11,-4.75)
    add_child(socket)
    _segmented_ring(socket,"DockCaptureLip",[Vector2(1.48,0.0),
        Vector2(1.58,0.0),Vector2(1.66,0.08),Vector2(1.66,0.18),
        Vector2(1.54,0.18),Vector2(1.48,0.12)],8,0.012,Color("#728b98"))
    # Connect the fixed socket into the upper load ring without occupying
    # the scanner's radial capture space or the inner rotating tools.
    for i in range(6):
        var mount := Node3D.new()
        mount.rotation.y = TAU*float(i)/6.0
        socket.add_child(mount)
        _box(mount,"DockMountBridge",Vector3(0,0.32,1.62),
            Vector3(0.20,0.40,0.20),metal)
    _build_scan_grid()
    for child in _scanner.get_children():
        if child is GeometryInstance3D:
            child.set_meta("sera_outline_occluder_only",true)
        for sub in child.get_children():
            if sub is GeometryInstance3D:
                sub.set_meta("sera_outline_occluder_only",true)


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
        leaf.set_meta("nexus_corner_only", true)
        leaf.set_meta("sera_outline_role", "facility")
        leaf.set_meta("sera_outline_occluder_only", true)
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


func _build_floor_ring() -> void:
    var base := Node3D.new()
    base.name = "MaintenanceDeckCastings"
    base.position = Vector3(0,0,-4.75)
    add_child(base)
    _segmented_ring(base,"DeckRadialArmor",[Vector2(1.35,0.055),
        Vector2(1.83,0.055),Vector2(1.93,0.145),Vector2(1.93,0.25),
        Vector2(1.80,0.31),Vector2(1.48,0.31),Vector2(1.35,0.23)],12,0.025,Color("#617987"))
    _segmented_ring(base,"DeckLockingCollars",[Vector2(1.78,0.11),
        Vector2(1.98,0.11),Vector2(2.02,0.18),Vector2(1.93,0.27),
        Vector2(1.78,0.27)],6,0.31,Color("#8b9186"))
    _segmented_ring(base,"DeckInnerRetainer",[Vector2(1.23,0.34),
        Vector2(1.43,0.34),Vector2(1.46,0.40),Vector2(1.25,0.43),
        Vector2(1.23,0.40)],12,0.02,Color("#445e6d"))


# Faceted radial cross-section; bevels and seams are real geometry, one
# vertex-colored mesh per assembly, with the aperture never capped.
func _segmented_ring(parent: Node3D,label: String,profile: Array,
        count: int,gap: float,tint: Color) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var shades: Array[float] = [0.61,0.84,1.0,0.78,1.10,0.88,0.70]
    for segment in range(count):
        var start: float = TAU*float(segment)/float(count)+gap*0.5
        var end: float = TAU*float(segment+1)/float(count)-gap*0.5
        for step in range(3):
            var a: float = lerpf(start,end,float(step)/3.0)
            var b: float = lerpf(start,end,float(step+1)/3.0)
            var radial := Vector3(cos((a+b)*0.5),0,sin((a+b)*0.5))
            for j in range(profile.size()):
                var p: Vector2 = profile[j]
                var q: Vector2 = profile[(j+1)%profile.size()]
                var n: Vector3 = radial*(q.y-p.y)+Vector3.UP*(p.x-q.x)
                var color: Color = tint*shades[j%shades.size()]
                color.a = 1.0
                _portal_quad(tool,_ring_point(p,a),_ring_point(p,b),
                    _ring_point(q,b),_ring_point(q,a),n,color)
        for j in range(1,profile.size()-1):
            _portal_tri(tool,_ring_point(profile[0],start),
                _ring_point(profile[j],start),_ring_point(profile[j+1],start),
                Vector3(sin(start),0,-cos(start)),tint.darkened(0.36))
            _portal_tri(tool,_ring_point(profile[0],end),
                _ring_point(profile[j],end),_ring_point(profile[j+1],end),
                Vector3(-sin(end),0,cos(end)),tint.darkened(0.36))
    var mat := _mat(Color.WHITE)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.79
    var node := _mesh(parent,label,tool.commit(),mat)
    node.set_meta("sera_preserve_authored_material",true)


func _ring_point(p: Vector2,a: float) -> Vector3:
    return Vector3(p.x*cos(a),p.y,p.x*sin(a))


# Geometry bounds are measured when the display pose/equipment changes.
# No per-frame rig traversal. The dock remains a fixed physical dimension;
# the ring expands only after clearing it and contracts before docking.
func set_scanner_bounds(top: float, radius: float) -> void:
    _scan_head_y = clampf(top+0.36,2.5,5.90)
    _scan_radius_scale = clampf((radius+0.12)/1.30,1.0,1.62)


func _scan_ease(t: float) -> float:
    var v: float = clampf(t,0.0,1.0)
    return v*v*v*(v*(v*6.0-15.0)+10.0)


# Called on the selection press, not after the camera tween.
func set_customize_scan_parked(value: bool) -> void:
    if _scan_parked_for_customize == value:
        return
    _scan_parked_for_customize = value
    if value:
        _scan_park_elapsed = 0.0
        _scan_park_from = Vector3(_scanner.position.y,_scanner.scale.x,_scan_fill)
    else:
        # A very quick exit may interrupt docking. Finish the same fast
        # docking path before restarting, never teleport the ring.
        _scan_clock = 5.0


func _update_scanner(step: float) -> void:
    if _scan_parked_for_customize or (_scan_park_elapsed < 0.65 and _scan_park_from != Vector3.ZERO):
        _scan_park_elapsed = minf(_scan_park_elapsed+step,0.65)
        # Never shrink around the body. Lift to the measured clear height,
        # then contract and seat into the fixed socket.
        var clear_y: float = maxf(_scan_head_y,_scan_park_from.x)
        var lift: float = _scan_ease(_scan_park_elapsed/0.40)
        var seat: float = _scan_ease((_scan_park_elapsed-0.40)/0.25)
        var y: float = lerpf(lerpf(_scan_park_from.x,clear_y,lift),SCAN_DOCK_Y,seat)
        _apply_scan_pose(y,lerpf(_scan_park_from.y,1.0,seat),
            _scan_park_from.z*(1.0-_scan_ease(_scan_park_elapsed/0.20)))
        return
    var t: float = fposmod(_scan_clock,SCAN_CYCLE)
    _scan_clock = fposmod(_scan_clock+step,SCAN_CYCLE)
    var y: float = SCAN_DOCK_Y
    var radial: float = 1.0
    var fill: float = 0.0
    # 0–5 dock; 5–7 descend; 7–8 settle above head;
    # 8–8.8 deploy; 8.8–14 descend slowly; 14–20 ascend;
    # 20–20.9 retract to rim; 20.9–23.0 glide into socket.
    if t >= 5.0 and t < 7.0:
        var k: float = _scan_ease((t-5.0)/2.0)
        y = lerpf(SCAN_DOCK_Y,_scan_head_y,k)
        radial = lerpf(1.0,_scan_radius_scale,_scan_ease((t-5.5)/1.5))
    elif t >= 7.0 and t < 8.8:
        y = _scan_head_y
        radial = _scan_radius_scale
        fill = _scan_ease((t-8.0)/0.8)
    elif t >= 8.8 and t < 14.0:
        y = lerpf(_scan_head_y,SCAN_LOW_Y,_scan_ease((t-8.8)/5.2))
        radial = _scan_radius_scale
        fill = 1.0
    elif t >= 14.0 and t < 20.0:
        y = lerpf(SCAN_LOW_Y,_scan_head_y,_scan_ease((t-14.0)/6.0))
        radial = _scan_radius_scale
        fill = 1.0
    elif t >= 20.0 and t < 20.9:
        y = _scan_head_y
        radial = _scan_radius_scale
        fill = 1.0-_scan_ease((t-20.0)/0.9)
    elif t >= 20.9 and t < 23.0:
        y = lerpf(_scan_head_y,SCAN_DOCK_Y,_scan_ease((t-20.9)/2.1))
        radial = lerpf(_scan_radius_scale,1.0,_scan_ease((t-20.9)/1.0))
    _apply_scan_pose(y,radial,fill)


func _apply_scan_pose(y: float,radial: float,fill: float) -> void:
    _scanner.position.y = y
    _scanner.scale = Vector3(radial,1.0,radial)
    _scan_fill = fill
    _scan_grid.visible = fill > 0.001
    if _scan_grid.visible:
        _scan_material.set_shader_parameter("coverage",fill)
    var pose := Vector2(y,radial)
    if not pose.is_equal_approx(_scan_last_pose):
        _scan_last_pose = pose
        scanner_pose_changed.emit()


func scanner_occlusion_pose() -> Transform3D:
    return _scanner.global_transform


func _build_scan_grid() -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(2.64,2.64)
    _scan_grid = MeshInstance3D.new()
    _scan_grid.name = "InspectionGridSurface"
    _scan_grid.mesh = plane
    _scan_grid.position.y = 0.022
    _scan_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _scan_grid.set_meta("FX_NO_OUTLINE",true)
    _scan_grid.set_meta("sera_skip_common_id_outline",true)
    _scan_grid.set_meta("sera_nexus_scan_depth_only",true)
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float coverage = 0.0;
void fragment() {
    vec2 p = UV*2.0-1.0;
    float r = length(p);
    float inner = 1.0-coverage;
    if (r > 1.0 || r < inner) { discard; }
    vec2 g = abs(fract((p+1.0)*8.0+0.5)-0.5);
    float line = 1.0-smoothstep(0.012,0.065,min(g.x,g.y));
    float edge = 1.0-smoothstep(0.0,0.045,abs(r-inner));
    float rim = 1.0-smoothstep(0.0,0.025,abs(r-1.0));
    ALBEDO = mix(vec3(0.19,0.60,0.86),vec3(0.72,0.94,1.0),max(line,edge));
    ALPHA = max(0.075,max(line*0.52,max(edge*0.67,rim*0.35)));
}
"""
    _scan_material = ShaderMaterial.new()
    _scan_material.shader = shader
    _scan_grid.material_override = _scan_material
    _scan_grid.hide()
    _scanner.add_child(_scan_grid)

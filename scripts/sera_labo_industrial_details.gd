extends RefCounted
## SERA: industrial detail pass for the three LABO hero environments.
## Custom indexed-looking polygon surfaces are combined into one static
## ArrayMesh per room (plus two rack meshes), with one moving part per room.
## No extra viewport, textures, shadows, physics bodies or per-frame rebuilding.

const ARMOR := Color("#344f5e")
const FRAME := Color("#7896a5")
const EDGE := Color("#a8bac4")
const DARK := Color("#192f3c")
const STEEL := Color("#4a6878")
const COPPER := Color("#a47d5f")
const WARNING := Color("#d7a45b")
const ICE := Color("#62c5d5")
const VIOLET := Color("#9e92c3")

var _skin: StandardMaterial3D
var _fab_drive: Node3D
var _refine_drive: Node3D
var _cargo_shuttle: Node3D

func build(fab: Node3D, refine: Node3D, store: Node3D) -> void:
    _skin = StandardMaterial3D.new()
    _skin.vertex_color_use_as_albedo = true
    _skin.vertex_color_is_srgb = true
    _skin.metallic = 0.38
    _skin.roughness = 0.49
    # A failed subsystem must not hide the existing three backgrounds.
    if fab != null:
        _fabrication(fab)
    if refine != null:
        _refining(refine)
    if store != null:
        _storage(store)

func animate(t: float, section: String) -> void:
    if section == "LABO" and is_instance_valid(_fab_drive):
        _fab_drive.rotation.z = t * 0.37
    elif section in ["SMELTER", "RECYCLER"] and is_instance_valid(_refine_drive):
        _refine_drive.rotation.z = t * (0.38 if section == "SMELTER" else -0.48)
    elif section == "STORAGE" and is_instance_valid(_cargo_shuttle):
        _cargo_shuttle.position.x = 0.42 * sin(t * 0.40)
        _cargo_shuttle.rotation.z = 0.035 * sin(t * 0.55)

func _start() -> SurfaceTool:
    var s := SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    return s

func _tri(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    s.set_color(tint)
    s.add_vertex(a)
    s.add_vertex(b)
    s.add_vertex(c)

func _quad(s: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, tint: Color) -> void:
    _tri(s, a, b, c, tint)
    _tri(s, a, c, d, tint)

func _finish(s: SurfaceTool, parent: Node3D, name: String) -> void:
    s.generate_normals()
    var item := MeshInstance3D.new()
    item.name = name
    item.mesh = s.commit()
    item.material_override = _skin
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    item.set_meta("sera_preserve_authored_material", true)
    parent.add_child(item)

func _pivot(parent: Node3D, name: String, position: Vector3) -> Node3D:
    var part := Node3D.new()
    part.name = name
    part.position = position
    parent.add_child(part)
    return part

# Beveled machine casing. The 8-point contour replaces stacked plain cubes.
func _body(s: SurfaceTool, center: Vector3,
        size: Vector3, bevel: float, tint: Color) -> void:
    var x := size.x * 0.5
    var z := size.z * 0.5
    var b := minf(bevel, minf(x, z) * 0.60)
    var loop: Array[Vector2] = [
        Vector2(-x+b, -z), Vector2(x-b, -z),
        Vector2(x, -z+b), Vector2(x, z-b),
        Vector2(x-b, z), Vector2(-x+b, z),
        Vector2(-x, z-b), Vector2(-x, -z+b)]
    var low: float = center.y - size.y * 0.5
    var high: float = center.y + size.y * 0.5
    for i in range(1, 7):
        _tri(s, Vector3(center.x+loop[0].x, high, center.z+loop[0].y),
            Vector3(center.x+loop[i+1].x, high, center.z+loop[i+1].y),
            Vector3(center.x+loop[i].x, high, center.z+loop[i].y), tint.lightened(0.07))
        _tri(s, Vector3(center.x+loop[0].x, low, center.z+loop[0].y),
            Vector3(center.x+loop[i].x, low, center.z+loop[i].y),
            Vector3(center.x+loop[i+1].x, low, center.z+loop[i+1].y), tint.darkened(0.16))
    for i in range(8):
        var j := (i+1) % 8
        var a := Vector3(center.x+loop[i].x, low, center.z+loop[i].y)
        var btm := Vector3(center.x+loop[j].x, low, center.z+loop[j].y)
        var top := Vector3(center.x+loop[j].x, high, center.z+loop[j].y)
        var d := Vector3(center.x+loop[i].x, high, center.z+loop[i].y)
        _quad(s, a, d, top, btm, tint if i in [0, 3, 4] else tint.darkened(0.075))

# Front-facing octagonal access panel with an actual extruded edge.
func _front(s: SurfaceTool, pos: Vector3,
        width: float, height: float, depth: float, tint: Color) -> void:
    var x := width * 0.5
    var y := height * 0.5
    var k := minf(minf(x, y) * 0.31, 0.18)
    var ring: Array[Vector2] = [
        Vector2(-x+k, -y), Vector2(x-k, -y),
        Vector2(x, -y+k), Vector2(x, y-k),
        Vector2(x-k, y), Vector2(-x+k, y),
        Vector2(-x, y-k), Vector2(-x, -y+k)]
    for i in range(1, 7):
        _tri(s, Vector3(pos.x+ring[0].x, pos.y+ring[0].y, pos.z+depth),
            Vector3(pos.x+ring[i].x, pos.y+ring[i].y, pos.z+depth),
            Vector3(pos.x+ring[i+1].x, pos.y+ring[i+1].y, pos.z+depth), tint)
    for i in range(8):
        var j := (i+1) % 8
        _quad(s, Vector3(pos.x+ring[i].x, pos.y+ring[i].y, pos.z),
            Vector3(pos.x+ring[j].x, pos.y+ring[j].y, pos.z),
            Vector3(pos.x+ring[j].x, pos.y+ring[j].y, pos.z+depth),
            Vector3(pos.x+ring[i].x, pos.y+ring[i].y, pos.z+depth), tint.darkened(0.24))

# General lathed cylinder between arbitrary endpoints, with real end caps.
func _pipe(s: SurfaceTool, a: Vector3, b: Vector3,
        radius: float, tint: Color, segments: int = 10) -> void:
    var axis: Vector3 = b - a
    if axis.length_squared() < 0.00001:
        return
    axis = axis.normalized()
    var reference := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.93 else Vector3.RIGHT
    var u: Vector3 = axis.cross(reference).normalized()
    var v: Vector3 = axis.cross(u).normalized()
    for i in range(segments):
        var t0 := TAU * float(i) / float(segments)
        var t1 := TAU * float(i+1) / float(segments)
        var p0: Vector3 = (u*cos(t0) + v*sin(t0)) * radius
        var p1: Vector3 = (u*cos(t1) + v*sin(t1)) * radius
        _quad(s, a+p0, a+p1, b+p1, b+p0,
            tint.lightened(0.09) if i % 3 == 0 else tint)
        _tri(s, a, a+p1, a+p0, tint.darkened(0.16))
        _tri(s, b, b+p0, b+p1, tint.lightened(0.05))

# Annular machined ring with central void, not a solid-cylinder imitation.
func _ring(s: SurfaceTool, center: Vector3,
        axis: Vector3, inner: float, outer: float, depth: float,
        tint: Color, segments: int = 16) -> void:
    var n: Vector3 = axis.normalized()
    var reference := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.93 else Vector3.RIGHT
    var u: Vector3 = n.cross(reference).normalized()
    var v: Vector3 = n.cross(u).normalized()
    for i in range(segments):
        var a := TAU * float(i) / float(segments)
        var b := TAU * float(i+1) / float(segments)
        var d0: Vector3 = u*cos(a)+v*sin(a)
        var d1: Vector3 = u*cos(b)+v*sin(b)
        var front := center + n * (depth*0.5)
        var back := center - n * (depth*0.5)
        _quad(s, front+d0*outer, front+d1*outer,
            front+d1*inner, front+d0*inner, tint.lightened(0.09))
        _quad(s, back+d0*inner, back+d1*inner,
            back+d1*outer, back+d0*outer, tint.darkened(0.15))
        _quad(s, front+d0*outer, back+d0*outer,
            back+d1*outer, front+d1*outer, tint)
        _quad(s, front+d0*inner, front+d1*inner,
            back+d1*inner, back+d0*inner, tint.darkened(0.2))

func _strut(s: SurfaceTool, a: Vector3, b: Vector3,
        radius: float, tint: Color) -> void:
    _pipe(s, a, b, radius, tint, 6)

func _cable(s: SurfaceTool, points: Array[Vector3],
        radius: float, tint: Color) -> void:
    for i in range(points.size()-1):
        _pipe(s, points[i], points[i+1], radius, tint, 7)

func _industrial_wall(s: SurfaceTool, kind: int) -> void:
    # Room-wide load-bearing wall geometry. STORAGE has its own expanded
    # perimeter; never leave the old 12m structural framework in the aisle.
    var enlarged: bool = kind == 2
    var wall_x: float = 8.42 if enlarged else 5.15
    var rib_z: Array = [-4.20, -1.90, 0.40]
    var duct_start: float = -4.88
    var duct_mid: float = -3.20
    var duct_end: float = -0.90
    if enlarged:
        rib_z = [-6.85, -3.85, -0.85, 2.15]
        duct_start = -7.60
        duct_mid = -4.90
        duct_end = 2.85
    for side in [-1.0, 1.0]:
        var x: float = side*wall_x
        for z in rib_z:
            _strut(s, Vector3(x, 0.28, z),
                Vector3(x, 3.86, z+0.42), 0.07, FRAME)
            _strut(s, Vector3(x, 0.95, z),
                Vector3(x, 3.25, z+1.25), 0.052, STEEL)
            _body(s, Vector3(x, 2.18, z+0.56),
                Vector3(0.34, 0.20, 1.65), 0.07, DARK)
        for y in [1.05, 3.24]:
            _cable(s, [Vector3(x, y, duct_start),
                Vector3(x, y+0.13, duct_mid),
                Vector3(x, y+0.04, duct_end)], 0.036,
                ICE if kind == 0 else COPPER if kind == 1 else FRAME)
    # Deep rear bulkhead with service vents located on the actual rear wall.
    var section_x: Array = [-3.45, 0.0, 3.45]
    var rear_z: float = -4.79
    var vent_z: float = -4.65
    var slat_z: float = -4.57
    if enlarged:
        # Preserve a readable clear lintel and monitor bay between vents.
        section_x = [-6.15, -3.65, 3.65, 6.15]
        rear_z = -7.58
        vent_z = -7.44
        slat_z = -7.36
    for x in section_x:
        _front(s, Vector3(x, 3.15, rear_z), 1.72, 0.92, 0.095, ARMOR)
        _front(s, Vector3(x, 3.15, vent_z), 1.32, 0.48, 0.02, DARK)
        for i in range(5):
            var off: float = -0.48+0.24*float(i)
            _strut(s, Vector3(x+off, 3.00, slat_z),
                Vector3(x+off+0.07, 3.31, slat_z), 0.023, EDGE)
    var beam_x: Array = [-4.30, -2.20, 2.20, 4.30]
    var beam_front: float = 1.35
    var beam_back: float = -4.70
    if enlarged:
        beam_x = [-7.65, -4.25, 4.25, 7.65]
        beam_front = 4.15
        beam_back = -7.55
    for x in beam_x:
        _strut(s, Vector3(x, 4.44, beam_back),
            Vector3(x, 4.44, beam_front), 0.085, FRAME)

func _fabrication(room: Node3D) -> void:
    var gantry: Node3D = room.get_node_or_null("AtlasOpenFramePrinter") as Node3D
    if gantry == null:
        return
    # Architectural relief stays in room coordinates. Printer mechanisms
    # below are authored in the scaled gantry's local coordinates.
    var shell := _start()
    _industrial_wall(shell, 0)
    _finish(shell, room, "FabricationWallStructuralRelief")
    var s := _start()
    # Open-profile gantry: paired bearing rails, exposed nut drives and
    # alternating structural triangular webs behind the traveling head.
    for side in [-1.0, 1.0]:
        var x := side * 1.14
        for z in [-0.52, 0.58]:
            _strut(s, Vector3(x, 0.92, z),
                Vector3(x, 2.52, z), 0.068, EDGE)
            _ring(s, Vector3(x, 2.20, z), Vector3.FORWARD,
                0.115, 0.20, 0.09, FRAME)
        for j in range(5):
            var y := 0.96 + j*0.27
            _strut(s, Vector3(x, y, -0.73),
                Vector3(x, y+0.22, 0.65), 0.024, STEEL)
    for z in [-0.50, 0.55]:
        _strut(s, Vector3(-1.22, 2.18, z),
            Vector3(1.22, 2.18, z), 0.079, FRAME)
        for i in range(12):
            var x := -1.11+i*0.20
            _body(s, Vector3(x, 2.24, z),
                Vector3(0.10, 0.068, 0.082), 0.014, STEEL)
    _body(s, Vector3(0.02, 1.85, 0.76),
        Vector3(0.74, 0.32, 0.20), 0.07, ARMOR)
    _front(s, Vector3(0.02, 1.85, 0.88), 0.48, 0.19, 0.035, FRAME)
    # Cable chain along the back rail and flexible feed hoses.
    for i in range(12):
        var x := -1.04+i*0.18
        _ring(s, Vector3(x, 2.47, -0.60),
            Vector3.RIGHT, 0.09, 0.15, 0.06, DARK, 8)
    _cable(s, [Vector3(1.21, 2.64, -0.62),
        Vector3(0.77, 2.67, -0.52), Vector3(0.40, 2.42, -0.24),
        Vector3(0.15, 2.23, 0.17)], 0.037, COPPER)
    # Machined front service panel and angular braced exhaust manifold.
    _front(s, Vector3(-1.00, 0.42, 1.105), 0.60, 0.32, 0.07, FRAME)
    for i in range(6):
        _strut(s, Vector3(-1.22+i*0.08, 0.34, 1.19),
            Vector3(-1.22+i*0.08, 0.50, 1.19), 0.021, DARK)
    _cable(s, [Vector3(-1.27, 2.58, -0.80),
        Vector3(-1.36, 2.89, -1.09), Vector3(-1.42, 3.18, -1.20),
        Vector3(-1.66, 3.55, -1.30)], 0.13, STEEL)
    _finish(s, gantry, "DetailedFabricatorCasting")
    # Additional tool nozzle hardware rides the EXISTING animated nozzle.
    var nozzle: Node3D = gantry.get_node_or_null("PrinterNozzle") as Node3D
    if nozzle != null:
        var tool := _start()
        for y in [-0.09, -0.22]:
            _ring(tool, Vector3(0, y, 0), Vector3.UP,
                0.10, 0.21, 0.06, EDGE, 12)
        for angle in range(6):
            var a := TAU * angle / 6.0
            _strut(tool, Vector3(cos(a)*0.15, -0.04, sin(a)*0.15),
                Vector3(cos(a)*0.10, -0.29, sin(a)*0.10), 0.025, COPPER)
        _finish(tool, nozzle, "DetailedDepositorToolhead")
    _fab_drive = _pivot(gantry, "MotorizedSpindleDrive", Vector3(1.32, 2.20, 0.73))
    var gear := _start()
    _ring(gear, Vector3.ZERO, Vector3.FORWARD, 0.14, 0.33, 0.12, FRAME, 20)
    _ring(gear, Vector3.ZERO, Vector3.FORWARD, 0.045, 0.125, 0.15, COPPER, 12)
    for i in range(14):
        var a := TAU*i/14.0
        var direction := Vector3(cos(a), sin(a), 0)
        _strut(gear, direction*0.29, direction*0.40, 0.055, EDGE)
    _finish(gear, _fab_drive, "SpurGearWithBearing")
    # Wall-to-printer ducts are room-space, not scaled with the machine.
    var ducts := _start()
    _cable(ducts, [Vector3(-4.15, 4.08, -2.50),
        Vector3(-4.15, 3.68, -2.50), Vector3(-3.90, 3.55, -2.50),
        Vector3(-3.30, 3.56, -2.22)], 0.13, FRAME)
    for i in range(5):
        _ring(ducts, Vector3(-4.15, 3.75+i*0.065, -2.50),
            Vector3.UP, 0.13, 0.20, 0.025, DARK, 12)
    _finish(ducts, room, "WorkshopVentAndCeilingService")

func _refining(room: Node3D) -> void:
    var s := _start()
    _industrial_wall(s, 1)
    var locations: Array[Vector3] = [
        Vector3(-2.65, 0, -0.35), Vector3(-0.15, 0, -1.05),
        Vector3(1.70, 0, -1.60)]
    # Three visible coolant manifolds are physically attached to the
    # existing vessels. Their unique colors identify flow, power, and purity.
    var colors: Array[Color] = [WARNING, ICE, VIOLET]
    for j in range(3):
        var p := locations[j]
        var c: Color = colors[j]
        _ring(s, p+Vector3(0, 2.31, 0), Vector3.UP,
            0.73, 0.86, 0.09, c, 16)
        for i in range(8):
            var a := TAU*i/8.0
            var u := Vector3(cos(a), 0, sin(a))
            _strut(s, p+u*0.83+Vector3(0, 0.78, 0),
                p+u*0.83+Vector3(0, 2.41, 0), 0.041, FRAME)
            _body(s, p+u*0.81+Vector3(0, 1.10+i%2*0.09, 0),
                Vector3(0.12, 0.27, 0.13), 0.023, STEEL)
        _cable(s, [p+Vector3(-0.80, 2.58, 0),
            p+Vector3(-1.05, 2.69, 0),
            p+Vector3(-1.10, 3.22, -0.22),
            p+Vector3(-1.13, 3.58, -0.82)], 0.078, COPPER)
        _cable(s, [p+Vector3(0.76, 0.98, 0.12),
            p+Vector3(1.01, 1.00, 0.29),
            p+Vector3(1.01, 0.53, 0.42)], 0.065, c)
        _front(s, p+Vector3(0, 0.48, 0.93), 0.58, 0.32, 0.065, ARMOR)
        for i in range(4):
            _strut(s, p+Vector3(-0.20+i*0.13, 0.39, 1.02),
                p+Vector3(-0.20+i*0.13, 0.57, 1.02), 0.018, c)
    # A separate functional side centrifuge, facing the portrait camera.
    # Keep it behind the near receiving bins and clear of CRATE's path.
    _body(s, Vector3(3.83, 0.43, -2.66),
        Vector3(1.34, 0.72, 1.30), 0.22, DARK)
    _body(s, Vector3(3.83, 1.54, -2.77),
        Vector3(1.55, 1.60, 0.58), 0.23, ARMOR)
    _ring(s, Vector3(3.83, 1.64, -2.39),
        Vector3.FORWARD, 0.56, 0.77, 0.15, EDGE, 22)
    for i in range(12):
        var a := TAU*i/12.0
        _strut(s, Vector3(3.83+cos(a)*0.67, 1.64+sin(a)*0.67, -2.35),
            Vector3(3.83+cos(a)*0.75, 1.64+sin(a)*0.75, -2.35), 0.038, WARNING)
    _cable(s, [Vector3(3.42, 2.42, -2.90),
        Vector3(3.28, 2.95, -3.00), Vector3(2.71, 3.27, -3.25),
        Vector3(1.82, 3.54, -3.55)], 0.10, COPPER)
    _front(s, Vector3(3.84, 0.43, -1.98), 0.82, 0.28, 0.075, FRAME)
    _finish(s, room, "RefineryPressureLineAndCentrifugeHousing")
    _refine_drive = _pivot(room, "CentrifugeRotor", Vector3(3.83, 1.64, -2.32))
    var rotor := _start()
    _ring(rotor, Vector3.ZERO, Vector3.FORWARD,
        0.16, 0.52, 0.14, COPPER, 18)
    _ring(rotor, Vector3.ZERO, Vector3.FORWARD,
        0.07, 0.18, 0.21, EDGE, 12)
    for i in range(6):
        var a := TAU*i/6.0
        _strut(rotor, Vector3(cos(a)*0.14, sin(a)*0.14, 0),
            Vector3(cos(a)*0.47, sin(a)*0.47, 0), 0.09, FRAME)
        _body(rotor, Vector3(cos(a)*0.40, sin(a)*0.40, 0),
            Vector3(0.16, 0.19, 0.14), 0.03, WARNING)
    _finish(rotor, _refine_drive, "VisibleSixCellSeparatorRotor")

func _storage(room: Node3D) -> void:
    var s := _start()
    _industrial_wall(s, 2)
    # Industrial overhead transporter keeps the open central walkway and
    # existing CRATE motion clear while making the store visibly automated.
    for z in [-2.72, -1.54]:
        _strut(s, Vector3(-1.60, 3.92, z),
            Vector3(2.18, 3.92, z), 0.12, FRAME)
        for i in range(13):
            var x := -1.49+i*0.29
            _strut(s, Vector3(x, 3.80, z),
                Vector3(x+0.13, 3.98, z), 0.037, STEEL)
    for x in [-1.51, 2.09]:
        _strut(s, Vector3(x, 3.79, -2.79),
            Vector3(x, 3.79, -1.49), 0.09, EDGE)
        _strut(s, Vector3(x, 3.80, -2.70),
            Vector3(x+0.30, 4.36, -2.70), 0.062, STEEL)
    # Receiving/delivery docking bed near the back, not at the front aisle.
    _body(s, Vector3(0.18, 0.25, -3.78),
        Vector3(2.20, 0.31, 1.12), 0.18, ARMOR)
    for i in range(8):
        var x := -0.68+i*0.24
        _pipe(s, Vector3(x, 0.48, -4.16),
            Vector3(x, 0.48, -3.42), 0.073, FRAME, 8)
    for side in [-1.0, 1.0]:
        _strut(s, Vector3(side*1.07, 0.38, -4.15),
            Vector3(side*1.07, 0.38, -3.41), 0.070, WARNING)
    _finish(s, room, "OverheadFreightGantryAndRollerDock")
    _cargo_shuttle = _pivot(room, "MovingOverheadShuttle",
        Vector3(0.30, 3.85, -2.15))
    var c := _start()
    _body(c, Vector3.ZERO, Vector3(0.70, 0.32, 0.76), 0.12, FRAME)
    for z in [-0.35, 0.35]:
        _ring(c, Vector3(0, -0.05, z),
            Vector3.RIGHT, 0.09, 0.18, 0.07, DARK, 12)
    _strut(c, Vector3(0, -0.25, 0),
        Vector3(0, -0.80, 0), 0.083, EDGE)
    _ring(c, Vector3(0, -0.72, 0), Vector3.UP,
        0.18, 0.29, 0.08, STEEL, 14)
    for side in [-1.0, 1.0]:
        _strut(c, Vector3(side*0.24, -0.78, 0),
            Vector3(side*0.35, -1.07, 0.03), 0.065, FRAME)
        _strut(c, Vector3(side*0.35, -1.07, 0.03),
            Vector3(side*0.18, -1.19, 0.05), 0.054, WARNING)
    _finish(c, _cargo_shuttle, "HoistWheelsAndTwoFingerClamp")
    # Rack corners are individually reinforced, not simply covered by a
    # repeated front box. Static fittings merge per rack into one draw surface.
    for rack_name in ["CargoRackPort", "CargoRackStarboard",
            "CargoRackPortRear", "CargoRackStarboardRear"]:
        var rack: Node3D = room.get_node_or_null(rack_name) as Node3D
        if rack == null:
            continue
        var r := _start()
        for y in [0.42, 1.47, 2.52, 3.57]:
            _strut(r, Vector3(-1.25, y, 0.75),
                Vector3(1.25, y, 0.75), 0.049, FRAME)
        for col in range(3):
            var x := -0.84 + col*0.84
            for row in range(3):
                var y := 0.78 + row*1.05
                var depth := 0.54 if (row+col) % 3 == 0 else 0.42
                # Stamped diagonal tie bars and die-cast central latch.
                _strut(r, Vector3(x-0.25, y-0.26, depth),
                    Vector3(x+0.25, y+0.22, depth), 0.024, DARK)
                _strut(r, Vector3(x-0.23, y+0.25, depth),
                    Vector3(x+0.23, y-0.23, depth), 0.018, FRAME)
                _front(r, Vector3(x, y-0.10, depth+0.02),
                    0.23, 0.12, 0.035, WARNING)
                for side in [-1.0, 1.0]:
                    _pipe(r, Vector3(x+side*0.28, y-0.21, depth),
                        Vector3(x+side*0.28, y+0.19, depth),
                        0.029, EDGE, 6)
        # Vertical aisle protection bars on the forward rack corners.
        for x in [-1.39, 1.39]:
            _strut(r, Vector3(x, 0.18, 0.70),
                Vector3(x, 4.43, 0.70), 0.082, WARNING)
        _finish(r, rack, "ReinforcedRackCargoLatches")

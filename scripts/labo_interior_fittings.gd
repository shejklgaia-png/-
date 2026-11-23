extends RefCounted
## Local-space fittings. Each mount submits its painted steelwork in at most
## two batches, regardless of the number of clamps, braces or shelf fittings.
const STEEL := Color("#8099a7")
const DARK := Color("#243b49")
const ARMOR := Color("#536d7a")
const COPPER := Color("#b98254")
const SAFETY := Color("#e0b25e")
var boxes: Array[Transform3D] = []
var box_colors: Array[Color] = []
var pipes: Array[Transform3D] = []
var pipe_colors: Array[Color] = []

func plate(at: Vector3, size: Vector3, color: Color, tilt: float = 0.0) -> void:
    boxes.append(Transform3D(Basis(Vector3.BACK, tilt).scaled_local(size), at))
    box_colors.append(color)

func tube(a: Vector3, b: Vector3, radius: float, color: Color) -> void:
    var axis := b - a
    var rotation := Basis(Quaternion(Vector3.UP, axis.normalized()))
    pipes.append(Transform3D(rotation.scaled_local(Vector3(radius, axis.length(), radius)), (a+b)*0.5))
    pipe_colors.append(color)

func flush(parent: Node3D) -> void:
    var tube_mesh := CylinderMesh.new()
    tube_mesh.top_radius = 1.0
    tube_mesh.bottom_radius = 1.0
    tube_mesh.height = 1.0
    tube_mesh.radial_segments = 8
    tube_mesh.rings = 0
    batch(parent, "FabricatedPlates", BoxMesh.new(), boxes, box_colors)
    batch(parent, "Pipework", tube_mesh, pipes, pipe_colors)

func batch(parent: Node3D, label: String, mesh: Mesh, poses: Array[Transform3D], colors: Array[Color]) -> void:
    if poses.is_empty():
        return
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.vertex_color_is_srgb = true
    material.roughness = 0.74
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.use_colors = true
    instances.mesh = mesh
    instances.instance_count = poses.size()
    for i in range(poses.size()):
        instances.set_instance_transform(i, poses[i])
        instances.set_instance_color(i, colors[i])
    var draw := MultiMeshInstance3D.new()
    draw.name = label
    draw.multimesh = instances
    draw.material_override = material
    draw.set_meta("sera_preserve_authored_material", true)
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(draw)

func printer(parent: Node3D) -> void:
    # Bed clamp shoes, gantry guideways and a guarded material-feed reel.
    for side in [-1.0, 1.0]:
        var x: float = side*1.30
        plate(Vector3(x,1.62,0.95), Vector3(0.20,1.92,0.10), DARK)
        tube(Vector3(x,0.75,1.02),Vector3(x,2.40,1.02),0.036,STEEL)
        for y in [0.80,1.78,2.30]:
            plate(Vector3(x,y,1.04),Vector3(0.20,0.10,0.09),ARMOR)
        plate(Vector3(side*0.90,0.69,0.58),Vector3(0.34,0.10,0.25),DARK)
        plate(Vector3(side*0.90,0.77,0.58),Vector3(0.20,0.055,0.17),SAFETY)
    var hub := Vector3(1.57,1.66,0.18)
    tube(hub,hub+Vector3(0.04,0,0),0.43,DARK)
    tube(hub+Vector3(0.04,0,0),hub+Vector3(0.18,0,0),0.39,COPPER)
    tube(hub+Vector3(0.19,0,0),hub+Vector3(0.24,0,0),0.38,ARMOR)
    tube(hub+Vector3(0.24,0,0),hub+Vector3(0.28,0,0),0.13,STEEL)
    for i in range(6):
        var angle := TAU*float(i)/6.0
        var rib := Vector3(0,sin(angle),cos(angle))
        tube(hub+Vector3(0.25,0,0)+rib*0.14,hub+Vector3(0.25,0,0)+rib*0.33,0.025,STEEL)
    for i in range(8):
        plate(Vector3(-0.92+i*0.25,2.91,0.94),Vector3(0.17,0.11,0.08),DARK,-0.27)
    flush(parent)

func refinery(parent: Node3D, tanks: Array[Vector3], colors: Array[Color]) -> void:
    # Each pressure vessel feeds a common overhead return manifold.
    tube(Vector3(-3.15,3.72,-2.40),Vector3(2.28,3.72,-2.40),0.115,ARMOR)
    for i in range(tanks.size()):
        var at := tanks[i]
        var x := at.x
        tube(at+Vector3.UP*3.45,at+Vector3.UP*3.72,0.11,STEEL)
        tube(at+Vector3.UP*3.72,Vector3(x,3.72,-2.40),0.105,COPPER)
        tube(Vector3(x-0.09,3.72,-2.40),Vector3(x+0.09,3.72,-2.40),0.17,STEEL)
        for side in [-1.0,1.0]:
            var rail := at+Vector3(side*0.64,0,0.31)
            tube(rail+Vector3.UP*0.78,rail+Vector3.UP*2.39,0.042,STEEL)
            for y in [0.80,2.35]:
                plate(rail+Vector3.UP*y,Vector3(0.20,0.13,0.22),DARK)
        var gauge := at+Vector3(-0.42,0.55,0.68)
        tube(gauge,gauge+Vector3.BACK*0.16,0.155,ARMOR)
        tube(gauge+Vector3.BACK*0.16,gauge+Vector3.BACK*0.18,0.12,colors[i])
        plate(gauge+Vector3.BACK*0.19,Vector3(0.034,0.16,0.02),DARK,-0.55+i*0.48)
    flush(parent)

func rack(parent: Node3D, bank: int) -> void:
    # Cargo front fittings sit behind the projecting shelf-identification plates.
    for row in range(3):
        var y := 0.76+row*1.03
        for col in range(3):
            var x := -0.82+col*0.82
            var finish := COPPER if (row+col+bank)%3 == 0 else ARMOR
            plate(Vector3(x,y-0.02,0.278),Vector3(0.56,0.34,0.035),finish)
            for side in [-1.0,1.0]:
                plate(Vector3(x+side*0.23,y-0.02,0.306),Vector3(0.045,0.36,0.032),STEEL)
            plate(Vector3(x,y-0.03,0.31),Vector3(0.20,0.065,0.035),DARK)
        for edge in [-1.32,1.32]:
            plate(Vector3(edge,y-0.18,0.24),Vector3(0.12,0.46,0.11),SAFETY)
            tube(Vector3(edge,y-0.29,0.50),Vector3(edge,y-0.02,0.08),0.055,ARMOR)
    flush(parent)

func freight_door(parent: Node3D) -> void:
    # A recessed-looking freight shutter at the aisle's vanishing point.
    var x := -0.98
    plate(Vector3(x,1.72,-4.88),Vector3(2.25,3.45,0.12),DARK)
    for i in range(10):
        plate(Vector3(x,0.21+i*0.31,-4.78),Vector3(2.03,0.27,0.09),ARMOR)
    for side in [-1.0,1.0]:
        plate(Vector3(x+side*1.11,1.67,-4.72),Vector3(0.14,3.35,0.18),STEEL)
    plate(Vector3(x,3.34,-4.70),Vector3(2.48,0.24,0.22),DARK)
    for i in range(5):
        plate(Vector3(x-0.61+i*0.30,3.35,-4.56),Vector3(0.16,0.12,0.05),SAFETY,-0.35)
    flush(parent)

func feedstock(parent: Node3D, palette: Array[Color]) -> void:
    for bin in range(4):
        var center := -2.65+float(bin)*1.41
        for row in range(2):
            for col in range(3):
                var at := Vector3(center-0.35+col*0.35,0.60,-0.20+row*0.35)
                var stagger := (col+row)%3
                match bin:
                    0: # Cut salvage stock, stacked at opposing angles.
                        plate(at,Vector3(0.26,0.12,0.29),palette[bin],0.14*stagger)
                        plate(at+Vector3(0,0.10,0.02),Vector3(0.18,0.08,0.26),COPPER,-0.19)
                    1: # Faceted metal billets with exposed end faces.
                        tube(at,at+Vector3(0.05,0.17+0.04*stagger,0.05),0.12,palette[bin])
                    2: # Component carriers with raised connector strips.
                        plate(at,Vector3(0.29,0.10,0.28),DARK)
                        plate(at+Vector3.UP*0.08,Vector3(0.20,0.08,0.17),palette[bin])
                        plate(at+Vector3(0,0.08,0.11),Vector3(0.19,0.06,0.04),COPPER)
                    3: # Short capped specimen cartridges nested in the tray.
                        tube(at,at+Vector3.UP*0.22,0.105,palette[bin])
                        tube(at+Vector3.UP*0.22,at+Vector3.UP*0.27,0.11,STEEL)
    flush(parent)

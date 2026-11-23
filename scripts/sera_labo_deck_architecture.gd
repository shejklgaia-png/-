extends RefCounted
## Three bespoke low-draw-call LABO floor/ceiling assemblies.
## Each room uses one vertex-colored ArrayMesh, built once at scene creation.
## No textures, additional light nodes, collision, shaders or animated tiles.

const DARK := Color("#152b39")
const DEEP := Color("#203847")
const PLATE := Color("#355363")
const STEEL := Color("#607f8e")
const EDGE := Color("#95afba")
const COPPER := Color("#b0885b")
const COOL := Color("#7abfcf")
const WARNING := Color("#c3a062")

var _finish_material: StandardMaterial3D

func build(fabrication: Node3D, refining: Node3D, storage: Node3D) -> void:
    _finish_material = StandardMaterial3D.new()
    _finish_material.vertex_color_use_as_albedo = true
    _finish_material.vertex_color_is_srgb = true
    _finish_material.metallic = 0.30
    _finish_material.roughness = 0.66
    if fabrication != null:
        _assemble(fabrication, 0)
    if refining != null:
        _assemble(refining, 1)
    if storage != null:
        _assemble(storage, 2)

func _tri(s: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, color: Color) -> void:
    s.set_color(color)
    s.add_vertex(a)
    s.add_vertex(b)
    s.add_vertex(c)

func _quad(s: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, color: Color) -> void:
    _tri(s, a, b, c, color)
    _tri(s, a, c, d, color)

func _oct_box(s: SurfaceTool, center: Vector3,
        size: Vector3, bevel: float, color: Color) -> void:
    # An eight-edge stamped plate: the corners are actual missing polygons,
    # not a stack of axis-aligned boxes or a flat decal.
    var half_x: float = size.x * 0.5
    var half_z: float = size.z * 0.5
    var cut: float = minf(bevel, minf(half_x, half_z) * 0.55)
    var loop: Array[Vector2] = [
        Vector2(-half_x+cut, -half_z), Vector2(half_x-cut, -half_z),
        Vector2(half_x, -half_z+cut), Vector2(half_x, half_z-cut),
        Vector2(half_x-cut, half_z), Vector2(-half_x+cut, half_z),
        Vector2(-half_x, half_z-cut), Vector2(-half_x, -half_z+cut)]
    var low: float = center.y-size.y*0.5
    var high: float = center.y+size.y*0.5
    for i in range(1, 7):
        _tri(s, Vector3(center.x+loop[0].x, high, center.z+loop[0].y),
            Vector3(center.x+loop[i+1].x, high, center.z+loop[i+1].y),
            Vector3(center.x+loop[i].x, high, center.z+loop[i].y),
            color.lightened(0.075))
        _tri(s, Vector3(center.x+loop[0].x, low, center.z+loop[0].y),
            Vector3(center.x+loop[i].x, low, center.z+loop[i].y),
            Vector3(center.x+loop[i+1].x, low, center.z+loop[i+1].y),
            color.darkened(0.19))
    for i in range(8):
        var j: int = (i+1)%8
        var p0 := Vector3(center.x+loop[i].x, low, center.z+loop[i].y)
        var p1 := Vector3(center.x+loop[i].x, high, center.z+loop[i].y)
        var p2 := Vector3(center.x+loop[j].x, high, center.z+loop[j].y)
        var p3 := Vector3(center.x+loop[j].x, low, center.z+loop[j].y)
        _quad(s, p0, p1, p2, p3,
            color if i in [1, 2, 5, 6] else color.darkened(0.10))

func _cylinder(s: SurfaceTool, a: Vector3, b: Vector3,
        radius: float, color: Color, segments: int = 8) -> void:
    var direction: Vector3 = b-a
    if direction.length_squared() < 0.00001:
        return
    direction = direction.normalized()
    var ref := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
    var u: Vector3 = direction.cross(ref).normalized()
    var v: Vector3 = direction.cross(u).normalized()
    for i in range(segments):
        var t0: float = TAU*float(i)/float(segments)
        var t1: float = TAU*float(i+1)/float(segments)
        var p0: Vector3 = (cos(t0)*u+sin(t0)*v)*radius
        var p1: Vector3 = (cos(t1)*u+sin(t1)*v)*radius
        _quad(s, a+p0, a+p1, b+p1, b+p0, color)
        _tri(s, a, a+p1, a+p0, color.darkened(0.13))
        _tri(s, b, b+p0, b+p1, color.lightened(0.09))

func _assemble(room: Node3D, kind: int) -> void:
    var width: float = 18.0 if kind == 2 else 12.0
    var depth: float = 13.5 if kind == 2 else 9.7
    var floor_z: float = -1.40 if kind == 2 else -1.28
    var columns: int = 9 if kind == 2 else 6
    var rows: int = 7 if kind == 2 else 5
    var cell_x: float = width/float(columns)
    var cell_z: float = depth/float(rows)
    var s := SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Individual chamfered metallic floor plates, not one featureless plane.
    # Their faces sit only ~3cm above the existing flat underfloor.
    for ix in range(columns):
        for iz in range(rows):
            var x: float = -width*0.5+(float(ix)+0.5)*cell_x
            var z: float = floor_z-depth*0.5+(float(iz)+0.5)*cell_z
            var color: Color = PLATE if (ix+iz)%3 != 0 else DEEP.lightened(0.07)
            if kind == 1:
                color = Color("#465762") if (ix+iz)%3 == 0 else Color("#314d5d")
            elif kind == 2:
                color = DEEP if absf(x) < 2.05 else PLATE
            _oct_box(s, Vector3(x, 0.013, z),
                Vector3(cell_x-0.075, 0.035, cell_z-0.075),
                0.13 if kind == 2 else 0.10, color)
            # Inset cold-rolled inspection slots and exposed anchor bolt heads.
            if absf(x) > (2.20 if kind == 2 else 1.40):
                for side in [-1.0, 1.0]:
                    _oct_box(s, Vector3(x+side*(cell_x*0.32), 0.039, z),
                        Vector3(0.075, 0.016, cell_z*0.24),
                        0.023, DARK)
                if (ix+iz)%2 == 0:
                    _oct_box(s, Vector3(x, 0.037, z),
                        Vector3(cell_x*0.42, 0.019, 0.073),
                        0.019, STEEL.darkened(0.05))
    # Different functional hazard routes: printer carriage, feed lanes,
    # then a deliberately wide uncluttered central warehouse aisle.
    var accent: Color = COOL if kind == 0 else COPPER if kind == 1 else WARNING
    var path_x: float = 1.45 if kind == 0 else 2.15 if kind == 1 else 2.35
    for side in [-1.0, 1.0]:
        _oct_box(s, Vector3(side*path_x, 0.048, floor_z),
            Vector3(0.075, 0.024, depth-0.78), 0.015, accent)
        for j in range(rows+1):
            var z_line: float = floor_z-depth*0.5+0.45+j*(depth-0.90)/float(rows)
            _oct_box(s, Vector3(side*(path_x+0.19), 0.048, z_line),
                Vector3(0.23, 0.018, 0.075), 0.025, EDGE.darkened(0.06))
    # Section-specific recessed service trenches with slotted steel grilles.
    var trench_z: float = -1.15 if kind == 0 else -2.58 if kind == 1 else -5.42
    var trench_length: float = 3.50 if kind == 2 else 2.35
    _oct_box(s, Vector3(0, 0.049, trench_z),
        Vector3(trench_length, 0.018, 0.47), 0.055, DARK)
    for j in range(14):
        var tx: float = (-trench_length*0.5+0.19+
            float(j)*(trench_length-0.38)/13.0)
        _oct_box(s, Vector3(tx, 0.062, trench_z),
            Vector3(0.061, 0.013, 0.37), 0.012, STEEL)
    # Deep exposed roof trusses. Different spans and purlins for each hall.
    var ceiling_rows: int = 6 if kind == 2 else 5
    for j in range(ceiling_rows):
        var zc: float = (floor_z-depth*0.5+1.1+
            float(j)*(depth-2.2)/float(ceiling_rows-1))
        _oct_box(s, Vector3(0, 4.68, zc),
            Vector3(width-0.65, 0.20, 0.23), 0.06, STEEL)
        for side in [-1.0, 1.0]:
            var xw: float = side*(width*0.5-0.58)
            _cylinder(s, Vector3(xw, 4.42, zc),
                Vector3(xw-side*0.78, 3.98, zc-0.35),
                0.065, EDGE)
            _cylinder(s, Vector3(xw-side*0.78, 3.98, zc-0.35),
                Vector3(xw-side*1.46, 4.63, zc-0.35),
                0.047, STEEL)
    for side in [-1.0, 1.0]:
        var edge_x: float = side*(width*0.5-0.70)
        for track in [0.0, 1.1]:
            _oct_box(s, Vector3(edge_x-side*track, 4.70, floor_z),
                Vector3(0.17, 0.18, depth-0.55), 0.048, DEEP)
            _oct_box(s, Vector3(edge_x-side*track, 4.58, floor_z),
                Vector3(0.058, 0.045, depth-0.64), 0.014, EDGE)
    # Suspended slab cassettes with trapezoidal outline under the ceiling.
    # The center stays open enough for the room camera and crane motion.
    var light_span: float = 3.8 if kind == 2 else 2.3
    for side in [-1.0, 1.0]:
        var cassette_x: float = side*(width*0.5-2.55)
        for j in range(2 if kind == 2 else 1):
            var cassette_z: float = -3.20 + float(j)*4.4 if kind == 2 else -1.12
            _oct_box(s, Vector3(cassette_x, 4.46, cassette_z),
                Vector3(1.34, 0.14, light_span), 0.17, DEEP)
            for l in range(7):
                var zf: float = cassette_z-light_span*0.40+float(l)*light_span*0.8/6.0
                _oct_box(s, Vector3(cassette_x, 4.36, zf),
                    Vector3(0.93, 0.065, 0.073), 0.018, COOL if kind == 0 else accent)
    if kind == 0:
        # Precision workshop: ceiling extraction boom and feed line.
        for x in [-3.2, -1.9, -0.6]:
            _cylinder(s, Vector3(x, 4.26, -4.30),
                Vector3(x, 4.26, -0.30), 0.092, COPPER)
    elif kind == 1:
        # Process plant: three parallel overhead pressure/cooling manifolds.
        for x in [-2.90, -0.35, 2.2]:
            _cylinder(s, Vector3(x, 4.17, -4.80),
                Vector3(x, 4.17, 0.45), 0.13, COPPER)
            for z in [-3.60, -1.40]:
                _cylinder(s, Vector3(x, 4.12, z),
                    Vector3(x, 3.75, z), 0.056, EDGE)
    else:
        # Enlarged warehouse: central heavy runway with paired hanger webs.
        for x in [-2.10, 2.10]:
            _oct_box(s, Vector3(x, 4.39, -2.2),
                Vector3(0.25, 0.30, 9.40), 0.064, STEEL)
            for z in [-6.25, -3.90, -1.55, 0.80]:
                _cylinder(s, Vector3(x, 4.37, z),
                    Vector3(x+(-0.38 if x > 0 else 0.38), 4.69, z),
                    0.064, EDGE)
    s.generate_normals()
    var render := MeshInstance3D.new()
    render.name = ["FabricationDeckAndRoof", "RefineryDeckAndRoof",
        "ExpandedWarehouseDeckAndRoof"][kind]
    render.mesh = s.commit()
    render.material_override = _finish_material
    render.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    render.set_meta("sera_preserve_authored_material", true)
    room.add_child(render)

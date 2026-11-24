extends Node3D
## Hand-authored service routes. Points below are design coordinates, not
## sampled random positions or pathfinding. Only the terminal ends follow PLACE.
## One low-poly static mesh per route; rebuilt only on a placement event.

const FLOOR_Y: float = 0.159
const SIDES: int = 8
const STEPS: int = 5
var routes: Dictionary = {}
var cable_material: StandardMaterial3D


func build(placements: Dictionary) -> void:
    cable_material = StandardMaterial3D.new()
    cable_material.vertex_color_use_as_albedo = true
    cable_material.albedo_color = Color.WHITE
    cable_material.roughness = 0.88
    cable_material.metallic = 0.0
    cable_material.cull_mode = BaseMaterial3D.CULL_DISABLED

    # SYSTEM: leave the left lower cabinet, curl behind the station and
    # terminate at a flush deck service socket. Avoid the central walkway.
    _add_route("SYSTEM", placements, [
        Vector3(-0.76, 0.27, -0.18), Vector3(-0.94, 0.23, -0.23)], [
        Vector3(-2.80, 0.208, 1.67), Vector3(-3.19, 0.208, 1.46),
        Vector3(-3.30, 0.208, 0.98), Vector3(-3.07, 0.208, 0.49),
        Vector3(-2.89, 0.208, 0.03), Vector3(-3.10, 0.208, -0.43)],
        0.047, Color("#252e37"))

    # TRAINING: independent right-hand route, a broad S between the base
    # and side service lane, with no overlap with the SYSTEM cable.
    _add_route("TRAINING", placements, [
        Vector3(0.64, 0.28, -0.18), Vector3(0.87, 0.23, -0.24)], [
        Vector3(2.81, 0.212, 1.72), Vector3(3.18, 0.212, 1.40),
        Vector3(3.34, 0.212, 0.90), Vector3(3.02, 0.212, 0.38),
        Vector3(2.84, 0.212, -0.18), Vector3(3.13, 0.212, -0.65)],
        0.051, Color("#2c353c"))

    # ARCHIVE: route off the left outer side of its raised balcony, descend
    # outside the deck edge and run along the floor away from the stairs.
    _add_route("DATA ARCHIVE", placements, [
        Vector3(-1.28, 0.22, -0.14), Vector3(-1.49, 0.20, -0.22)], [
        Vector3(-6.64, 2.65, -12.40), Vector3(-6.72, 2.35, -12.53),
        Vector3(-6.75, 1.33, -12.62), Vector3(-6.78, 0.40, -12.70),
        Vector3(-6.98, 0.202, -12.85), Vector3(-7.19, 0.202, -13.24),
        Vector3(-7.00, 0.202, -13.69), Vector3(-7.14, 0.202, -14.14)],
        0.041, Color("#303b43"))

    # DEPLOYMENT: auxiliary kiosk only; never cross the raised gate ramp.
    _add_route("DEPLOYMENT", placements, [
        Vector3(0.50, -0.49, 0.10), Vector3(0.68, -0.57, 0.18)], [
        Vector3(8.20, 0.206, -18.35), Vector3(8.53, 0.206, -18.12),
        Vector3(8.72, 0.206, -17.68), Vector3(8.50, 0.206, -17.24),
        Vector3(8.72, 0.206, -16.78), Vector3(8.99, 0.206, -16.49)],
        0.045, Color("#29353d"))


func _add_route(key: String, placements: Dictionary, local: Array,
        fixed: Array, radius: float, tint: Color) -> void:
    if not placements.has(key):
        return
    var spec: Dictionary = placements[key]
    var node := MeshInstance3D.new()
    node.name = key.replace(" ", "") + "FloorCable"
    node.material_override = cable_material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("nexus_ink_class", "nexus_background")
    node.set_meta("sera_preserve_authored_material", true)
    add_child(node)
    routes[key] = {"node": node, "local": local, "fixed": fixed,
        "radius": radius, "tint": tint}
    set_terminal_pose(key, spec["position"], float(spec["yaw"]))


func set_terminal_pose(key: String, at: Vector3, yaw: float) -> void:
    if not routes.has(key):
        return
    var route: Dictionary = routes[key]
    var basis := Basis(Vector3.UP, yaw)
    var points := PackedVector3Array()
    var radius: float = route["radius"]
    for local_point in route["local"]:
        var p: Vector3 = at + basis * local_point
        p.y = maxf(p.y, FLOOR_Y + radius)
        points.append(p)
    for fixed_point in route["fixed"]:
        points.append(fixed_point)
    var centers := PackedVector3Array()
    # Interpolate only the explicitly authored control points. Clamp each
    # interval's height so the hanging lead cannot overshoot into the floor.
    for i in range(points.size() - 1):
        var a: Vector3 = points[maxi(0, i - 1)]
        var b: Vector3 = points[i]
        var c: Vector3 = points[i + 1]
        var d: Vector3 = points[mini(points.size() - 1, i + 2)]
        for j in range(STEPS):
            var t: float = float(j) / float(STEPS)
            var p: Vector3 = b.cubic_interpolate(c, a, d, t)
            p.y = clampf(p.y, minf(b.y, c.y), maxf(b.y, c.y))
            if centers.is_empty() or centers[-1].distance_squared_to(p) > 0.000001:
                centers.append(p)
    if centers[-1].distance_squared_to(points[-1]) > 0.000001:
        centers.append(points[-1])
    var node: MeshInstance3D = route["node"]
    # Retain the same mesh resource (ID/depth compositor shares it).
    var mesh: ArrayMesh = node.mesh as ArrayMesh
    if mesh == null:
        mesh = ArrayMesh.new()
        node.mesh = mesh
    mesh.clear_surfaces()
    _write_mesh(mesh, centers, radius, route["tint"])


func _write_mesh(mesh: ArrayMesh, centers: PackedVector3Array,
        radius: float, tint: Color) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array[PackedVector3Array] = []
    var ring_normals: Array[PackedVector3Array] = []
    var frame := Vector3.UP
    for i in range(centers.size()):
        var tangent: Vector3 = (centers[mini(i + 1, centers.size() - 1)] -
            centers[maxi(i - 1, 0)]).normalized()
        if tangent.length_squared() < 0.001:
            tangent = Vector3.FORWARD
        frame = frame - tangent * frame.dot(tangent)
        if frame.length_squared() < 0.001:
            frame = Vector3.RIGHT - tangent * Vector3.RIGHT.dot(tangent)
        if frame.length_squared() < 0.001:
            frame = Vector3.FORWARD - tangent * Vector3.FORWARD.dot(tangent)
        frame = frame.normalized()
        var cross_axis: Vector3 = tangent.cross(frame).normalized()
        # Metal collars at the terminal and the fixed floor inlet.
        var outer: float = radius * (1.24 if i == 0 or i >= centers.size() - 2 else 1.0)
        var ring := PackedVector3Array()
        var normals := PackedVector3Array()
        for side in range(SIDES):
            var theta: float = TAU * float(side) / float(SIDES)
            var normal: Vector3 = frame * cos(theta) + cross_axis * sin(theta)
            ring.append(centers[i] + normal * outer)
            normals.append(normal)
        rings.append(ring)
        ring_normals.append(normals)
    for i in range(rings.size() - 1):
        var color: Color = Color("#52606a") if i == 0 or i >= rings.size() - 2 else tint
        for j in range(SIDES):
            var k: int = (j + 1) % SIDES
            _vertex(surface, rings[i][j], ring_normals[i][j], color)
            _vertex(surface, rings[i + 1][j], ring_normals[i + 1][j], color)
            _vertex(surface, rings[i][k], ring_normals[i][k], color)
            _vertex(surface, rings[i][k], ring_normals[i][k], color)
            _vertex(surface, rings[i + 1][j], ring_normals[i + 1][j], color)
            _vertex(surface, rings[i + 1][k], ring_normals[i + 1][k], color)
    for endpoint in [0, rings.size() - 1]:
        var end: int = int(endpoint)
        var adjacent: int = 1 if end == 0 else end - 1
        var outward: Vector3 = (centers[end] - centers[adjacent]).normalized()
        for j in range(SIDES):
            _vertex(surface, centers[end], outward, Color("#52606a"))
            _vertex(surface, rings[end][j], outward, Color("#52606a"))
            _vertex(surface, rings[end][(j + 1) % SIDES], outward, Color("#52606a"))
    _floor_socket(surface, centers[-1], radius)
    surface.commit(mesh)


func _vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, tint: Color) -> void:
    surface.set_normal(normal)
    surface.set_color(tint)
    surface.add_vertex(point)

# The fixed end seats in a low-profile steel deck inlet, not a loose tip.
# This flange is included in the same surface and stays at the authored end.
func _floor_socket(surface: SurfaceTool, endpoint: Vector3, radius: float) -> void:
    var base := Vector3(endpoint.x, FLOOR_Y, endpoint.z)
    var lower: float = FLOOR_Y - 0.008
    var top: float = endpoint.y + radius * 0.35
    var width: float = radius * 1.85
    var steel := Color("#53616a")
    for i in range(SIDES):
        var a: float = TAU * float(i) / float(SIDES)
        var b: float = TAU * float(i + 1) / float(SIDES)
        var na := Vector3(cos(a), 0.0, sin(a))
        var nb := Vector3(cos(b), 0.0, sin(b))
        var p: Vector3 = base + na * width
        var q: Vector3 = base + nb * width
        var lo_a := Vector3(p.x, lower, p.z)
        var lo_b := Vector3(q.x, lower, q.z)
        var hi_a := Vector3(p.x, top, p.z)
        var hi_b := Vector3(q.x, top, q.z)
        _vertex(surface, lo_a, na, steel)
        _vertex(surface, lo_b, nb, steel)
        _vertex(surface, hi_a, na, steel)
        _vertex(surface, hi_a, na, steel)
        _vertex(surface, lo_b, nb, steel)
        _vertex(surface, hi_b, nb, steel)
        _vertex(surface, Vector3(base.x, top, base.z), Vector3.UP, steel)
        _vertex(surface, hi_a, Vector3.UP, steel)
        _vertex(surface, hi_b, Vector3.UP, steel)

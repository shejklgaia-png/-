extends RefCounted
## CRATE — reference silhouette and mechanical armor refinement (2026-11-25).
## Shared production geometry for BASE and all three LABO backgrounds.
## Forward is -Z.  Keep HeadPivot/LeftArmPivot/RightArmPivot animation API.
## All detailed surfaces are welded into per-material meshes: no runtime CSG,
## per-frame rebuilding, textures, facial glyphs or independent light sources.

const COLORS := {
    "porcelain": "#e3ded9",
    "shell": "#d2cdca",
    "warm_white": "#eee8df",
    "armor": "#a5a4aa",
    "armor_shadow": "#7b8896",
    "steel": "#65717f",
    "trim": "#485461",
    "black": "#282e38",
    "rubber": "#262b32",
    "tread": "#3c424b",
    "tread_edge": "#606873",
    "joint": "#3d4652",
    "hub": "#89939b",
    "chrome": "#b6c1c6",
    "amber": "#d88b32",
    "amber_edge": "#ffc277",
    "visor": "#111720",
    "glass": "#17212b",
    "cyan": "#78eaff",
    "cyan_dim": "#3f9ba9",
}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


class Batch:
    var surfaces: Dictionary = {}
    var form_scale: Vector3 = Vector3.ONE

    func triangle(style: String, a: Vector3, b: Vector3, c: Vector3) -> void:
        # Scale authored local geometry before computing outward normals.
        a *= form_scale
        b *= form_scale
        c *= form_scale
        var n: Vector3 = (b - a).cross(c - a)
        if n.length_squared() < 0.000000001:
            return
        n = n.normalized()
        var st: SurfaceTool = surfaces.get(style) as SurfaceTool
        if st == null:
            st = SurfaceTool.new()
            st.begin(Mesh.PRIMITIVE_TRIANGLES)
            surfaces[style] = st
        # Helpers define OUTWARD normals with (b - a).cross(c - a).
        # Godot treats CLOCKWISE triangles (viewed from outside) as
        # front-facing. The former a,b,c order therefore exposed the
        # interior and culled large portions of the visible armor.
        # Reverse only the submitted winding, NOT the authored normal:
        # lighting stays exterior-facing and default back-face culling
        # remains enabled (no costly double-sided material workaround).
        for p in [a, c, b]:
            st.set_normal(n)
            st.add_vertex(p)

    func quad(style: String, a: Vector3, b: Vector3,
            c: Vector3, d: Vector3) -> void:
        triangle(style, a, b, c)
        triangle(style, a, c, d)


static func _mat(style: String) -> StandardMaterial3D:
    if _materials.has(style):
        return _materials[style] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(str(COLORS.get(style, "#808080")))
    m.metallic = 0.37
    m.roughness = 0.51
    if style in ["porcelain", "warm_white", "shell"]:
        m.metallic = 0.18
        m.roughness = 0.61
    elif style in ["rubber", "tread", "tread_edge"]:
        m.metallic = 0.06
        m.roughness = 0.76
    elif style == "glass" or style == "visor":
        m.roughness = 0.32
    elif style in ["chrome", "hub"]:
        m.metallic = 0.68
        m.roughness = 0.34
    if style in ["cyan", "cyan_dim"]:
        m.emission_enabled = true
        m.emission = m.albedo_color
        m.emission_energy_multiplier = 1.55 if style == "cyan" else 0.75
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _materials[style] = m
    return m


static func _emit(parent: Node3D, label: String, batch: Batch) -> void:
    # The same immutable ArrayMesh resources are reused by BASE and LABO.
    if not _meshes.has(label):
        var parts: Dictionary = {}
        for key in batch.surfaces.keys():
            var tool: SurfaceTool = batch.surfaces[key] as SurfaceTool
            parts[key] = tool.commit()
        _meshes[label] = parts
    var meshes: Dictionary = _meshes[label]
    for key in meshes.keys():
        var part := MeshInstance3D.new()
        part.name = "%s_%s" % [label, str(key)]
        part.mesh = meshes[key] as ArrayMesh
        part.material_override = _mat(str(key))
        parent.add_child(part)


static func _box(b: Batch, style: String, p: Vector3, s: Vector3) -> void:
    var x: float = s.x * 0.5
    var y: float = s.y * 0.5
    var z: float = s.z * 0.5
    var a := Vector3(p.x - x, p.y - y, p.z - z)
    var c := Vector3(p.x + x, p.y - y, p.z - z)
    var d := Vector3(p.x + x, p.y + y, p.z - z)
    var e := Vector3(p.x - x, p.y + y, p.z - z)
    var f := Vector3(p.x - x, p.y - y, p.z + z)
    var g := Vector3(p.x + x, p.y - y, p.z + z)
    var h := Vector3(p.x + x, p.y + y, p.z + z)
    var i := Vector3(p.x - x, p.y + y, p.z + z)
    b.quad(style, a, e, d, c) # -Z
    b.quad(style, f, g, h, i) # +Z
    b.quad(style, a, f, i, e) # -X
    b.quad(style, c, d, h, g) # +X
    b.quad(style, e, i, h, d) # +Y
    b.quad(style, a, c, g, f) # -Y


static func _profile(w: float, h: float, corner: float) -> Array[Vector2]:
    var x: float = w * 0.5
    var y: float = h * 0.5
    var r: float = minf(corner, minf(x, y) * 0.85)
    return [
        Vector2(-x + r, -y), Vector2(x - r, -y),
        Vector2(x, -y + r), Vector2(x, y - r),
        Vector2(x - r, y), Vector2(-x + r, y),
        Vector2(-x, y - r), Vector2(-x, -y + r)
    ]


static func _prism_xy(b: Batch, style: String, input: Array[Vector2],
        za: float, zb: float) -> void:
    var polygon: Array[Vector2] = input.duplicate()
    var area: float = 0.0
    for i in range(polygon.size()):
        var a: Vector2 = polygon[i]
        var c: Vector2 = polygon[(i + 1) % polygon.size()]
        area += a.x * c.y - c.x * a.y
    if area < 0.0:
        polygon.reverse()
    var center := Vector2.ZERO
    for p in polygon:
        center += p
    center /= float(polygon.size())
    for i in range(polygon.size()):
        var p: Vector2 = polygon[i]
        var q: Vector2 = polygon[(i + 1) % polygon.size()]
        b.triangle(style, Vector3(center.x, center.y, za),
            Vector3(q.x, q.y, za), Vector3(p.x, p.y, za))
        b.triangle(style, Vector3(center.x, center.y, zb),
            Vector3(p.x, p.y, zb), Vector3(q.x, q.y, zb))
        b.quad(style, Vector3(p.x, p.y, za),
            Vector3(q.x, q.y, za), Vector3(q.x, q.y, zb),
            Vector3(p.x, p.y, zb))


static func _bevel(b: Batch, style: String, p: Vector3,
        size: Vector3, radius: float) -> void:
    # Four concentric chamfered octagonal rings replace a square box hull.
    var cut: float = minf(radius, minf(size.x, size.y) * 0.28)
    var end_cut: float = minf(cut * 0.54, size.z * 0.23)
    var outer: Array[Vector2] = _profile(size.x, size.y, cut)
    var inset: Array[Vector2] = _profile(
        size.x - 2.0 * end_cut, size.y - 2.0 * end_cut, cut * 0.67)
    var z_front: float = p.z - size.z * 0.5
    var z_back: float = p.z + size.z * 0.5
    var rings: Array = [
        [inset, z_front],
        [outer, z_front + end_cut],
        [outer, z_back - end_cut],
        [inset, z_back]
    ]
    for idx in range(8):
        var j: int = (idx + 1) % 8
        b.triangle(style, Vector3(p.x, p.y, z_front),
            Vector3(p.x + inset[j].x, p.y + inset[j].y, z_front),
            Vector3(p.x + inset[idx].x, p.y + inset[idx].y, z_front))
        b.triangle(style, Vector3(p.x, p.y, z_back),
            Vector3(p.x + inset[idx].x, p.y + inset[idx].y, z_back),
            Vector3(p.x + inset[j].x, p.y + inset[j].y, z_back))
        for step in range(3):
            var lo: Array = rings[step]
            var hi: Array = rings[step + 1]
            var shape_lo: Array = lo[0]
            var shape_hi: Array = hi[0]
            var z0: float = lo[1]
            var z1: float = hi[1]
            b.quad(style,
                Vector3(p.x + shape_lo[idx].x, p.y + shape_lo[idx].y, z0),
                Vector3(p.x + shape_lo[j].x, p.y + shape_lo[j].y, z0),
                Vector3(p.x + shape_hi[j].x, p.y + shape_hi[j].y, z1),
                Vector3(p.x + shape_hi[idx].x, p.y + shape_hi[idx].y, z1))


# Explicit profile loft: each ring is [width, height, corner, center_y, z].
# All profiles are CCW in XY. Batch converts outward geometry to Godot CW.
static func _loft_armor(b: Batch, style: String, rings: Array,
        front_cap: bool = true, back_cap: bool = true, inward: bool = false) -> void:
    var points: Array = []
    for r in rings:
        var ring: Array[Vector3] = []
        for p in _profile(float(r[0]), float(r[1]), float(r[2])):
            ring.append(Vector3(p.x, p.y + float(r[3]), float(r[4])))
        points.append(ring)
    for j in range(points.size() - 1):
        for i in range(8):
            var k: int = (i + 1) % 8
            if inward:
                b.quad(style, points[j][i], points[j + 1][i],
                    points[j + 1][k], points[j][k])
            else:
                b.quad(style, points[j][i], points[j][k],
                    points[j + 1][k], points[j + 1][i])
    for i in range(8):
        var k: int = (i + 1) % 8
        if front_cap:
            b.triangle(style, Vector3(0, rings[0][3], rings[0][4]),
                points[0][k], points[0][i])
        if back_cap:
            var last: int = points.size() - 1
            b.triangle(style, Vector3(0, rings[last][3], rings[last][4]),
                points[last][i], points[last][k])


# Reference side view: the sloped breastplate projects forward at its foot.
static func _chest_plate(b: Batch, style: String, outline: Array[Vector2],
        offset: float, thickness: float) -> void:
    var center := Vector2.ZERO
    for p in outline:
        center += p
    center /= float(outline.size())
    var cf := Vector3(center.x, center.y, -0.53 + (center.y - 0.65) * 0.23 + offset)
    for i in range(outline.size()):
        var p: Vector2 = outline[i]
        var q: Vector2 = outline[(i + 1) % outline.size()]
        var a := Vector3(p.x, p.y, -0.53 + (p.y - 0.65) * 0.23 + offset)
        var c := Vector3(q.x, q.y, -0.53 + (q.y - 0.65) * 0.23 + offset)
        var back := Vector3(0, 0, thickness)
        b.triangle(style, cf, c, a)
        b.triangle(style, cf + back, a + back, c + back)
        b.quad(style, a, c, c + back, a + back)


# Swept, faceted rectangular claw, not a chain of cylindrical rods.
static func _finger(b: Batch, radial: Vector3) -> void:
    var crosswise: Vector3 = Vector3.FORWARD.cross(radial).normalized()
    var stations: Array[Vector2] = [
        Vector2(0.105, -0.012), Vector2(0.162, -0.077),
        Vector2(0.177, -0.145), Vector2(0.134, -0.218),
        Vector2(0.081, -0.243), Vector2(0.060, -0.228)
    ]
    var rings: Array = []
    for i in range(stations.size()):
        var a: Vector2 = stations[maxi(i - 1, 0)]
        var c: Vector2 = stations[mini(i + 1, stations.size() - 1)]
        var tangent: Vector3 = (radial * (c.x - a.x) + Vector3(0, 0, c.y - a.y)).normalized()
        var u: Vector3 = crosswise
        var v: Vector3 = tangent.cross(u).normalized()
        var center: Vector3 = radial * stations[i].x + Vector3(0, 0, stations[i].y)
        var w: float = 0.058 if i < 4 else 0.048
        var h: float = 0.048 if i < 4 else 0.037
        var ring: Array[Vector3] = []
        for p in _profile(w * 2.0, h * 2.0, 0.014):
            ring.append(center + u * p.x + v * p.y)
        rings.append(ring)
    for j in range(rings.size() - 1):
        var style: String = "porcelain" if j < 2 else ("trim" if j == 2 else "amber")
        for i in range(8):
            var k: int = (i + 1) % 8
            b.quad(style, rings[j][i], rings[j][k],
                rings[j + 1][k], rings[j + 1][i])
    var last: int = rings.size() - 1
    var start: Vector3 = radial * stations[0].x + Vector3(0, 0, stations[0].y)
    var end: Vector3 = radial * stations[last].x + Vector3(0, 0, stations[last].y)
    for i in range(8):
        var k: int = (i + 1) % 8
        b.triangle("joint", start, rings[0][k], rings[0][i])
        b.triangle("trim", end, rings[last][i], rings[last][k])


static func _disk_x(b: Batch, style: String, p: Vector3,
        radius: float, width: float, segments: int = 16) -> void:
    var x0: float = p.x - width * 0.5
    var x1: float = p.x + width * 0.5
    for i in range(segments):
        var a: float = TAU * float(i) / float(segments)
        var c: float = TAU * float(i + 1) / float(segments)
        var y0: float = p.y + cos(a) * radius
        var y1: float = p.y + cos(c) * radius
        var z0: float = p.z + sin(a) * radius
        var z1: float = p.z + sin(c) * radius
        b.triangle(style, Vector3(x0, p.y, p.z),
            Vector3(x0, y1, z1), Vector3(x0, y0, z0))
        b.triangle(style, Vector3(x1, p.y, p.z),
            Vector3(x1, y0, z0), Vector3(x1, y1, z1))
        b.quad(style, Vector3(x0, y0, z0),
            Vector3(x0, y1, z1), Vector3(x1, y1, z1),
            Vector3(x1, y0, z0))


static func _rod(b: Batch, style: String, a: Vector3,
        c: Vector3, radius: float, segments: int = 7) -> void:
    var axis: Vector3 = (c - a).normalized()
    if axis.length_squared() < 0.9:
        return
    var first: Vector3 = axis.cross(Vector3.UP)
    if first.length_squared() < 0.001:
        first = axis.cross(Vector3.RIGHT)
    first = first.normalized()
    var second: Vector3 = axis.cross(first).normalized()
    for i in range(segments):
        var ang0: float = TAU * float(i) / float(segments)
        var ang1: float = TAU * float(i + 1) / float(segments)
        var v0: Vector3 = (first * cos(ang0) + second * sin(ang0)) * radius
        var v1: Vector3 = (first * cos(ang1) + second * sin(ang1)) * radius
        b.quad(style, a + v0, a + v1, c + v1, c + v0)
        b.triangle(style, a, a + v1, a + v0)
        b.triangle(style, c, c + v0, c + v1)


static func _outline_track() -> Array[Vector2]:
    # Clockwise perimeter in (z,y); reverse to make the prism endcap face -X.
    var shape: Array[Vector2] = []
    for i in range(11):
        shape.append(Vector2(-0.36 + float(i) * 0.072, 0.52))
    for i in range(1, 8):
        var a: float = PI * 0.5 - PI * float(i) / 7.0
        shape.append(Vector2(0.36 + cos(a) * 0.21, 0.31 + sin(a) * 0.21))
    for i in range(1, 11):
        shape.append(Vector2(0.36 - float(i) * 0.072, 0.10))
    for i in range(1, 8):
        var a: float = -PI * 0.5 - PI * float(i) / 7.0
        shape.append(Vector2(-0.36 + cos(a) * 0.21, 0.31 + sin(a) * 0.21))
    shape.reverse()
    return shape


static func _prism_yz(b: Batch, style: String,
        polygon: Array[Vector2], x0: float, x1: float) -> void:
    var center := Vector2.ZERO
    for p in polygon:
        center += p
    center /= float(polygon.size())
    for i in range(polygon.size()):
        var q: Vector2 = polygon[i]
        var r: Vector2 = polygon[(i + 1) % polygon.size()]
        b.triangle(style, Vector3(x0, center.y, center.x),
            Vector3(x0, q.y, q.x), Vector3(x0, r.y, r.x))
        b.triangle(style, Vector3(x1, center.y, center.x),
            Vector3(x1, r.y, r.x), Vector3(x1, q.y, q.x))
        b.quad(style, Vector3(x0, q.y, q.x),
            Vector3(x1, q.y, q.x),
            Vector3(x1, r.y, r.x),
            Vector3(x0, r.y, r.x))


static func _tread(b: Batch, a: Vector2, c: Vector2) -> void:
    if a.distance_squared_to(c) < 0.0001:
        return
    var mid: Vector2 = (a + c) * 0.5
    var outside := Vector2(mid.x - clampf(mid.x, -0.36, 0.36),
        mid.y - 0.31).normalized()
    var delta: Vector2 = (c - a).normalized() * 0.011
    var start: Vector2 = a + delta
    var finish: Vector2 = c - delta
    var inner: Vector2 = outside * 0.008
    var outer: Vector2 = outside * 0.039
    # One dark rubber pad with visible squared-off raised tread shoulders.
    var w: float = 0.165
    var x0: float = -w
    var x1: float = w
    var p0 := Vector3(x0, start.y + inner.y, start.x + inner.x)
    var p1 := Vector3(x1, start.y + inner.y, start.x + inner.x)
    var p2 := Vector3(x1, finish.y + inner.y, finish.x + inner.x)
    var p3 := Vector3(x0, finish.y + inner.y, finish.x + inner.x)
    var p4 := Vector3(x0, start.y + outer.y, start.x + outer.x)
    var p5 := Vector3(x1, start.y + outer.y, start.x + outer.x)
    var p6 := Vector3(x1, finish.y + outer.y, finish.x + outer.x)
    var p7 := Vector3(x0, finish.y + outer.y, finish.x + outer.x)
    b.quad("rubber", p4, p5, p6, p7)
    for lane in range(3):
        var left: float = float(lane) / 3.0 + 0.012
        var right: float = float(lane + 1) / 3.0 - 0.012
        var lift := Vector3(0, outside.y, outside.x) * 0.009
        var q0: Vector3 = p4.lerp(p5, left)
        var q1: Vector3 = p4.lerp(p5, right)
        var q2: Vector3 = p7.lerp(p6, right)
        var q3: Vector3 = p7.lerp(p6, left)
        b.quad("tread", q0 + lift, q1 + lift, q2 + lift, q3 + lift)
        b.quad("tread", q0, q1, q1 + lift, q0 + lift)
        b.quad("tread", q1, q2, q2 + lift, q1 + lift)
        b.quad("tread", q2, q3, q3 + lift, q2 + lift)
        b.quad("tread", q3, q0, q0 + lift, q3 + lift)
    b.quad("tread_edge", p0, p4, p7, p3)
    b.quad("tread_edge", p1, p2, p6, p5)
    b.quad("tread_edge", p0, p1, p5, p4)
    b.quad("tread_edge", p3, p7, p6, p2)


static func _make_tracks(robot: Node3D) -> void:
    for side in [-1, 1]:
        var s: float = float(side)
        var pivot := Node3D.new()
        pivot.name = "LeftTrack" if side < 0 else "RightTrack"
        pivot.position.x = s * 0.49
        robot.add_child(pivot)
        var b := Batch.new()
        # Compact wheelbase and less protruding maintenance hubs.
        b.form_scale = Vector3(0.87, 1.0, 0.90)
        var outside: float = s * 0.198
        var outline: Array[Vector2] = _outline_track()
        _prism_yz(b, "rubber", outline, -0.168, 0.168)
        for i in range(outline.size()):
            _tread(b, outline[i], outline[(i + 1) % outline.size()])
        _bevel(b, "armor_shadow", Vector3(s * 0.195, 0.34, 0.0),
            Vector3(0.11, 0.33, 0.85), 0.07)
        _box(b, "black", Vector3(s * 0.239, 0.31, 0.0),
            Vector3(0.022, 0.205, 0.69))
        for z in [-0.36, 0.0, 0.36]:
            _disk_x(b, "joint", Vector3(outside, 0.31, z), 0.153, 0.064)
            _disk_x(b, "hub", Vector3(outside + s * 0.043, 0.31, z),
                0.112, 0.036)
            _disk_x(b, "trim", Vector3(outside + s * 0.071, 0.31, z),
                0.066, 0.027)
            _disk_x(b, "chrome", Vector3(outside + s * 0.090, 0.31, z),
                0.029, 0.015, 12)
        # Distinct high-contrast side maintenance panel from the drawing.
        var panel: Array[Vector2] = [
            Vector2(0.015, 0.18), Vector2(0.28, 0.18), Vector2(0.31, 0.21),
            Vector2(0.31, 0.35), Vector2(0.28, 0.38), Vector2(0.015, 0.38),
            Vector2(-0.015, 0.35), Vector2(-0.015, 0.21)
        ]
        var panel_x: float = s * 0.292
        _prism_yz(b, "porcelain", panel, panel_x - 0.035, panel_x + 0.035)
        _box(b, "trim", Vector3(s * 0.333, 0.28, 0.15),
            Vector3(0.009, 0.045, 0.135))
        for z in [0.035, 0.26]:
            _disk_x(b, "joint", Vector3(s * 0.331, 0.33, z), 0.014, 0.009, 8)
        _box(b, "amber", Vector3(s * 0.327, 0.33, -0.26),
            Vector3(0.007, 0.035, 0.14))
        _emit(pivot, "LeftTrack" if side < 0 else "RightTrack", b)


static func _make_body(robot: Node3D) -> void:
    var b := Batch.new()
    _bevel(b, "joint", Vector3(0.0, 0.48, 0.045),
        Vector3(0.90, 0.32, 0.78), 0.09)
    _bevel(b, "shell", Vector3(0, 0.705, 0.005),
        Vector3(0.95, 0.52, 0.83), 0.13)
    # Broad shoulders, tapering chest and a separate dark lower keel.
    _chest_plate(b, "armor", [
        Vector2(-0.25, 0.43), Vector2(0.25, 0.43), Vector2(0.39, 0.73),
        Vector2(0.35, 0.88), Vector2(-0.35, 0.88), Vector2(-0.39, 0.73)
    ], -0.008, 0.085)
    _chest_plate(b, "warm_white", [
        Vector2(-0.20, 0.52), Vector2(0.20, 0.52), Vector2(0.31, 0.75),
        Vector2(0.30, 0.87), Vector2(-0.30, 0.87), Vector2(-0.31, 0.75)
    ], -0.026, 0.028)
    _chest_plate(b, "steel", [
        Vector2(-0.10, 0.46), Vector2(0.10, 0.46), Vector2(0.135, 0.65),
        Vector2(-0.135, 0.65)
    ], -0.043, 0.026)
    _chest_plate(b, "amber", [
        Vector2(-0.105, 0.62), Vector2(0.105, 0.62), Vector2(0.125, 0.68),
        Vector2(-0.125, 0.68)
    ], -0.057, 0.018)
    for side in [-1, 1]:
        var sign_x: float = float(side)
        var seam: Array[Vector2] = [
            Vector2(sign_x * 0.24, 0.57), Vector2(sign_x * 0.265, 0.57),
            Vector2(sign_x * 0.34, 0.79), Vector2(sign_x * 0.315, 0.79)
        ]
        if side < 0:
            seam.reverse()
        _chest_plate(b, "amber", seam, -0.049, 0.009)
    for side in [-1, 1]:
        var s: float = float(side)
        _bevel(b, "porcelain", Vector3(s * 0.46, 0.81, 0.03),
            Vector3(0.23, 0.34, 0.64), 0.07)
        _box(b, "steel", Vector3(s * 0.552, 0.79, 0.16),
            Vector3(0.030, 0.22, 0.20))
        _chest_plate(b, "cyan_dim", [
            Vector2(s * 0.225 - 0.016, 0.52), Vector2(s * 0.225 + 0.016, 0.52),
            Vector2(s * 0.225 + 0.016, 0.565), Vector2(s * 0.225 - 0.016, 0.565)
        ], -0.052, 0.009)
        _disk_x(b, "black", Vector3(s * 0.55, 0.84, -0.14),
            0.125, 0.042)
        _disk_x(b, "steel", Vector3(s * 0.57, 0.84, -0.14),
            0.091, 0.031)
    _box(b, "trim", Vector3(0, 0.91, -0.16),
        Vector3(0.52, 0.042, 0.39))
    _box(b, "shell", Vector3(0, 0.97, -0.14),
        Vector3(0.49, 0.09, 0.43))
    # High-visibility rear cargo/maintenance battery with cyan-lit recess.
    _bevel(b, "steel", Vector3(0, 0.76, 0.435),
        Vector3(0.66, 0.48, 0.28), 0.064)
    _bevel(b, "amber", Vector3(0, 0.78, 0.583),
        Vector3(0.51, 0.42, 0.092), 0.048)
    _bevel(b, "joint", Vector3(0, 0.78, 0.647),
        Vector3(0.42, 0.32, 0.035), 0.024)
    # Twin removable rear cartridges on an exposed dark mounting spine.
    _bevel(b, "black", Vector3(0, 0.80, 0.685),
        Vector3(0.065, 0.32, 0.035), 0.012)
    for s in [-1.0, 1.0]:
        _bevel(b, "porcelain", Vector3(s * 0.116, 0.78, 0.681),
            Vector3(0.155, 0.285, 0.063), 0.021)
        _bevel(b, "glass", Vector3(s * 0.116, 0.80, 0.718),
            Vector3(0.059, 0.192, 0.016), 0.009)
        _box(b, "cyan", Vector3(s * 0.116, 0.80, 0.729),
            Vector3(0.028, 0.157, 0.008))
        _box(b, "cyan_dim", Vector3(s * 0.20, 0.87, 0.684),
            Vector3(0.026, 0.060, 0.010))
        _disk_x(b, "steel", Vector3(s * 0.34, 0.70, 0.40),
            0.11, 0.048)
        _box(b, "amber_edge", Vector3(s * 0.24, 0.99, 0.47),
            Vector3(0.061, 0.025, 0.17))
    for x in [-0.22, 0.22]:
        _bevel(b, "amber", Vector3(x, 0.96, 0.55), Vector3(0.10, 0.08, 0.20), 0.02)
        _bevel(b, "trim", Vector3(x, 0.61, 0.61), Vector3(0.08, 0.08, 0.08), 0.014)
        _box(b, "steel", Vector3(x, 0.94, 0.20),
            Vector3(0.052, 0.055, 0.25))
    _emit(robot, "Body", b)


static func _make_head(robot: Node3D) -> void:
    var pivot := Node3D.new()
    pivot.name = "HeadPivot"
    pivot.position = Vector3(0.0, 1.01, -0.06)
    robot.add_child(pivot)
    var b := Batch.new()
    # Broad overhanging head and rounded wedge from the orthographic sheet.
    # Keep the animated neck pivot and all attachment transforms intact.
    b.form_scale = Vector3(1.13, 1.0, 1.12)
    _disk_x(b, "black", Vector3(0, 0.018, 0.02),
        0.185, 0.40)
    _bevel(b, "joint", Vector3(0, 0.12, 0.02),
        Vector3(0.58, 0.20, 0.49), 0.065)
    # Recessed visor housing: silhouette follows the side-view sloping
    # forehead rather than stacking plates on a closed rectangular head.
    _loft_armor(b, "porcelain", [
        [0.94, 0.40, 0.075, 0.30, -0.455],
        [1.055, 0.53, 0.105, 0.345, -0.345],
        [1.065, 0.56, 0.105, 0.355, -0.065],
        [1.045, 0.54, 0.10, 0.35, 0.275],
        [0.91, 0.48, 0.075, 0.35, 0.40]
    ], false, true)
    # Front lip, chamfer into screen well, dark inner wall, recessed glass.
    _loft_armor(b, "armor", [
        [0.94, 0.40, 0.075, 0.30, -0.455],
        [0.83, 0.31, 0.054, 0.30, -0.458]
    ], false, false, true)
    _loft_armor(b, "visor", [
        [0.83, 0.31, 0.054, 0.30, -0.458],
        [0.77, 0.255, 0.035, 0.30, -0.412]
    ], false, false, true)
    _loft_armor(b, "glass", [
        [0.77, 0.255, 0.035, 0.30, -0.412],
        [0.77, 0.255, 0.035, 0.30, -0.409]
    ], true, false)
    # One continuous illuminated optical slit, no facial glyphs.
    _bevel(b, "cyan_dim", Vector3(0, 0.297, -0.420),
        Vector3(0.565, 0.061, 0.013), 0.021)
    _bevel(b, "cyan", Vector3(0, 0.297, -0.430),
        Vector3(0.525, 0.034, 0.012), 0.012)
    _bevel(b, "warm_white", Vector3(0, 0.629, 0.037),
        Vector3(0.48, 0.038, 0.32), 0.025)
    _bevel(b, "armor_shadow", Vector3(0, 0.35, 0.413),
        Vector3(0.33, 0.26, 0.05), 0.038)
    for x in [-0.28, 0.28]:
        _box(b, "amber", Vector3(x, 0.615, 0.23),
            Vector3(0.043, 0.017, 0.13))
    for side in [-1, 1]:
        var s: float = float(side)
        # Rear-set rectangular motor enclosure supports the circular ear servo.
        _bevel(b, "trim", Vector3(s * 0.505, 0.35, 0.28),
            Vector3(0.15, 0.38, 0.29), 0.035)
        _bevel(b, "armor_shadow", Vector3(s * 0.575, 0.35, 0.29),
            Vector3(0.055, 0.29, 0.19), 0.026)
        # Bulky ear-mounted rotary servo, layered metallic hub and gold bezel.
        _disk_x(b, "joint", Vector3(s * 0.522, 0.35, 0.115),
            0.235, 0.115, 18)
        _disk_x(b, "amber", Vector3(s * 0.594, 0.35, 0.115),
            0.214, 0.045, 18)
        _disk_x(b, "chrome", Vector3(s * 0.632, 0.35, 0.115),
            0.162, 0.037, 18)
        _disk_x(b, "joint", Vector3(s * 0.654, 0.35, 0.115),
            0.122, 0.027, 18)
        _disk_x(b, "hub", Vector3(s * 0.677, 0.35, 0.115),
            0.082, 0.021, 14)
        _box(b, "cyan_dim", Vector3(s * 0.515, 0.29, -0.233),
            Vector3(0.018, 0.055, 0.092))
        # Side-view swept antenna blades: upright in front view, raked
        # backwards in side view. No sideways splay.
        var ear: Array[Vector2] = [
            Vector2(0.08, 0.58), Vector2(0.23, 0.58),
            Vector2(0.43, 0.99), Vector2(0.41, 1.045),
            Vector2(0.34, 1.04), Vector2(0.09, 0.71)
        ]
        var ear_x: float = s * 0.37
        _prism_yz(b, "joint", ear, ear_x - 0.047, ear_x + 0.047)
        var stripe: Array[Vector2] = [
            Vector2(0.095, 0.70), Vector2(0.135, 0.70),
            Vector2(0.385, 1.015), Vector2(0.346, 1.027)
        ]
        var stripe_x: float = ear_x + s * 0.048
        _prism_yz(b, "amber", stripe, stripe_x - 0.006, stripe_x + 0.006)
        _disk_x(b, "steel", Vector3(ear_x, 0.62, 0.18), 0.085, 0.11, 12)
        _disk_x(b, "trim", Vector3(ear_x + s * 0.065, 0.62, 0.18),
            0.035, 0.015, 10)
        # Small amber registration mark; no large floating decorative stripe.
        _box(b, "amber", Vector3(s * 0.515, 0.415, -0.20),
            Vector3(0.014, 0.048, 0.042))
    _emit(pivot, "Head", b)


static func _make_arms(robot: Node3D) -> void:
    for side in [-1, 1]:
        var s: float = float(side)
        var pivot := Node3D.new()
        pivot.name = "LeftArmPivot" if side < 0 else "RightArmPivot"
        pivot.position = Vector3(s * 0.555, 0.83, -0.105)
        robot.add_child(pivot)
        var b := Batch.new()
        _disk_x(b, "joint", Vector3(s * 0.06, 0.01, 0.0),
            0.195, 0.187)
        _disk_x(b, "hub", Vector3(s * 0.145, 0.01, 0.0),
            0.134, 0.061)
        _disk_x(b, "trim", Vector3(s * 0.18, 0.01, 0.0),
            0.092, 0.027)
        _rod(b, "joint", Vector3(s * 0.14, 0.0, -0.03),
            Vector3(s * 0.28, -0.06, -0.245), 0.131, 9)
        _bevel(b, "porcelain", Vector3(s * 0.255, -0.04, -0.125),
            Vector3(0.23, 0.28, 0.30), 0.068)
        _box(b, "amber", Vector3(s * 0.356, 0.038, -0.147),
            Vector3(0.026, 0.043, 0.155))
        _disk_x(b, "steel", Vector3(s * 0.296, -0.067, -0.266),
            0.114, 0.13)
        _disk_x(b, "chrome", Vector3(s * 0.363, -0.067, -0.266),
            0.058, 0.026)
        _rod(b, "joint", Vector3(s * 0.30, -0.065, -0.270),
            Vector3(s * 0.31, -0.065, -0.516), 0.112, 9)
        _bevel(b, "porcelain", Vector3(s * 0.31, -0.061, -0.412),
            Vector3(0.24, 0.22, 0.31), 0.053)
        _box(b, "steel", Vector3(s * 0.310, 0.034, -0.415),
            Vector3(0.145, 0.029, 0.22))
        _disk_x(b, "trim", Vector3(s * 0.31, -0.068, -0.579),
            0.115, 0.12)
        _disk_x(b, "hub", Vector3(s * 0.31, -0.068, -0.592),
            0.074, 0.10)
        _emit(pivot, "LeftArm" if side < 0 else "RightArm", b)
        # Separate the existing hand geometry at the wrist hub. The shared
        # BASE model retains its identical neutral silhouette and arm API.
        var wrist := Node3D.new()
        wrist.name = "WristPivot"
        wrist.position = Vector3(s*0.31,-0.065,-0.592)
        pivot.add_child(wrist)
        b = Batch.new()
        # Three mechanically shaped hooked fingers; two upper fingers and
        # a lower opposing thumb. Wrist origin and external API unchanged.
        _bevel(b, "joint", Vector3(0, 0, -0.015),
            Vector3(0.21, 0.20, 0.12), 0.045)
        _bevel(b, "black", Vector3(0, 0, -0.078),
            Vector3(0.15, 0.15, 0.045), 0.031)
        _bevel(b, "steel", Vector3(0, 0, -0.105),
            Vector3(0.091, 0.091, 0.019), 0.021)
        var directions: Array[Vector3] = [
            Vector3(-0.42, 0.91, 0).normalized(),
            Vector3(0.42, 0.91, 0).normalized(),
            Vector3(0, -1, 0)
        ]
        for radial in directions:
            _disk_x(b, "joint", radial * 0.105, 0.052, 0.072, 10)
            _finger(b, radial)
        _emit(wrist, "LeftHand" if side < 0 else "RightHand", b)


static func create_model() -> Node3D:
    var robot := Node3D.new()
    robot.name = "CRATE"
    # Character 4px outside/0px inside/2px mesh seam; no convex outlines.
    robot.set_meta("sera_outline_role", "crate")
    robot.set_meta("sera_graphics_outline_category", "character")
    _make_tracks(robot)
    _make_body(robot)
    _make_head(robot)
    _make_arms(robot)
    return robot

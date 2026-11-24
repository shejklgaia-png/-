extends RefCounted
## SERA BASE physically sculpted meshes, assembled from explicit triangles.
## Meshes are immutable shared unit shapes: facility transforms supply size.
## Materials and primitive geometry are reused across MultiMesh batches.
## No procedural runtime noise, physics, shadows, or per-frame work.

# One immutable ArrayMesh per polygon silhouette, across every BASE facility.
static var _mesh_cache: Dictionary = {}

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, outward: Vector3) -> void:
    var normal: Vector3 = (b - a).cross(c - a)
    if normal.length_squared() < 0.000000001:
        return
    if normal.dot(outward) < 0.0:
        var saved: Vector3 = b
        b = c
        c = saved
        normal = -normal
    normal = normal.normalized()
    # Godot 4 renders CLOCKWISE winding as front-facing. The outward
    # right-handed normal was computed above; reverse submitted vertices
    # but retain that outward normal for correct lighting and textures.
    for point in [a, c, b]:
        var p: Vector3 = point
        var uv: Vector2
        if absf(normal.y) > 0.55:
            uv = Vector2(p.x + 0.5, p.z + 0.5)
        elif absf(normal.x) > absf(normal.z):
            uv = Vector2(p.z + 0.5, 0.5 - p.y)
        else:
            uv = Vector2(p.x + 0.5, 0.5 - p.y)
        # A tiny offline directional light model stored at each actual vertex.
        # This is not a GPU shader or extra light; flat normals remain crisp.
        var shade: float = clampf(
            0.80 + normal.y * 0.18
            + maxf(normal.z, 0.0) * 0.10
            + maxf(normal.x, 0.0) * 0.035,
            0.62, 1.04)
        st.set_normal(normal)
        st.set_uv(uv)
        st.set_color(Color(shade, shade, shade, 1.0))
        st.add_vertex(p)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, outward: Vector3) -> void:
    _triangle(st, a, b, c, outward)
    _triangle(st, a, c, d, outward)

static func _octagonal_ring(y: float, edge: float,
        clip: float) -> Array[Vector3]:
    var e: float = edge
    var inner: float = edge - clip
    return [
        Vector3(-inner, y, -e), Vector3(inner, y, -e),
        Vector3(e, y, -inner), Vector3(e, y, inner),
        Vector3(inner, y, e), Vector3(-inner, y, e),
        Vector3(-e, y, inner), Vector3(-e, y, -inner),
    ]

static func _octagonal_slew(st: SurfaceTool) -> void:
    # Eight genuine planar wrench flats, with relieved neck and stepped
    # bearing shoulders. The actual shaft is an octagon, not a twenty-tooth
    # gear or a smooth cylinder with a decorative outline.
    var profiles: Array[Vector2] = [
        Vector2(-0.50, 0.42), Vector2(-0.37, 0.50),
        Vector2(-0.25, 0.50), Vector2(-0.20, 0.35),
        Vector2(0.22, 0.35), Vector2(0.30, 0.47),
        Vector2(0.50, 0.47),
    ]
    var rings: Array = []
    for profile in profiles:
        var edge: float = profile.y
        # 0.585786 * half-extent gives eight equal planar edges.
        rings.append(_octagonal_ring(profile.x, edge,
            edge * 0.58578644))
    for layer in range(rings.size() - 1):
        var bottom: Array = rings[layer]
        var top: Array = rings[layer + 1]
        for side in range(8):
            var next_side: int = (side + 1) % 8
            var middle: Vector3 = (bottom[side] + bottom[next_side] +
                top[side] + top[next_side]) * 0.25
            _quad(st, bottom[side], bottom[next_side],
                top[next_side], top[side],
                Vector3(middle.x, 0.0, middle.z))
    var lower: Array = rings[0]
    var upper: Array = rings[rings.size() - 1]
    for side in range(8):
        var next_side: int = (side + 1) % 8
        _triangle(st, Vector3(0, -0.5, 0),
            lower[next_side], lower[side], Vector3.DOWN)
        _triangle(st, Vector3(0, 0.5, 0),
            upper[side], upper[next_side], Vector3.UP)


static func _beveled(st: SurfaceTool, deck: bool, shallow: bool = false) -> void:
    # 8-sided footprint, stepped top lip, individually triangulated bevels.
    # Plate top remains +0.5 so world Y=-0.03 floor level stays unchanged.
    # NEXUS roof armor retains a narrow real chamfer on the same bounds.
    var clip: float = 0.055 if shallow else (0.045 if deck else 0.13)
    var inset: float = 0.027 if shallow else (0.028 if deck else 0.075)
    var lower: Array[Vector3] = _octagonal_ring(-0.5, 0.5, clip)
    var shoulder: Array[Vector3] = _octagonal_ring(
        0.44 if shallow else (0.38 if deck else 0.33), 0.5, clip)
    var upper: Array[Vector3] = _octagonal_ring(0.5, 0.5 - inset, clip)
    for i in range(8):
        var j: int = (i + 1) % 8
        var side: Vector3 = shoulder[i] + shoulder[j]
        side.y = 0.0
        _quad(st, lower[i], lower[j], shoulder[j], shoulder[i], side)
        _quad(st, shoulder[i], shoulder[j], upper[j], upper[i],
            Vector3(side.x, 0.10, side.z))
        _triangle(st, Vector3(0, 0.5, 0), upper[i], upper[j], Vector3.UP)
        _triangle(st, Vector3(0, -0.5, 0), lower[j], lower[i], Vector3.DOWN)

static func _hopper(st: SurfaceTool) -> void:
    # Open, sloped steel throat with genuine inner walls and a thick top lip.
    var bottom: Array[Vector3] = [
        Vector3(-0.27, -0.5, -0.27), Vector3(0.27, -0.5, -0.27),
        Vector3(0.27, -0.5, 0.27), Vector3(-0.27, -0.5, 0.27)]
    var top: Array[Vector3] = [
        Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5),
        Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]
    var inside_top: Array[Vector3] = [
        Vector3(-0.40, 0.475, -0.40), Vector3(0.40, 0.475, -0.40),
        Vector3(0.40, 0.475, 0.40), Vector3(-0.40, 0.475, 0.40)]
    var inside_bottom: Array[Vector3] = [
        Vector3(-0.19, -0.26, -0.19), Vector3(0.19, -0.26, -0.19),
        Vector3(0.19, -0.26, 0.19), Vector3(-0.19, -0.26, 0.19)]
    for i in range(4):
        var j: int = (i + 1) % 4
        var outside: Vector3 = top[i] + top[j]
        outside.y = 0.0
        _quad(st, bottom[i], bottom[j], top[j], top[i], outside)
        _quad(st, top[i], top[j], inside_top[j], inside_top[i], Vector3.UP)
        _quad(st, inside_top[i], inside_top[j], inside_bottom[j],
            inside_bottom[i], -outside)
    _quad(st, bottom[0], bottom[1], bottom[2], bottom[3], Vector3.DOWN)

static func _hood(st: SurfaceTool) -> void:
    # Tapered/sloped front housing with six physical facets, not a tilted cube.
    var base: Array[Vector3] = [
        Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5),
        Vector3(0.45, -0.5, 0.5), Vector3(-0.45, -0.5, 0.5)]
    var rim: Array[Vector3] = [
        Vector3(-0.5, -0.08, -0.5), Vector3(0.5, -0.08, -0.5),
        Vector3(0.39, 0.48, 0.5), Vector3(-0.39, 0.48, 0.5)]
    for i in range(4):
        var j: int = (i + 1) % 4
        var out: Vector3 = rim[i] + rim[j]
        out.y = 0.0
        _quad(st, base[i], base[j], rim[j], rim[i], out)
    _quad(st, rim[0], rim[1], rim[2], rim[3], Vector3.UP)
    _quad(st, base[0], base[1], base[2], base[3], Vector3.DOWN)

static func _canopy_y(x: float, z: float) -> float:
    # Raised seams, falling side edges, cross-slope and a few tension creases.
    var ridge: float = 0.13 - 0.10 * (z + 0.5)
    var sag: float = -0.17 * (1.0 - pow(absf(x * 2.0), 1.5))
    var fold: float = 0.045 * sin((x + 0.5) * PI * 3.0)
    return ridge + sag + fold

static func _canvas(st: SurfaceTool, pinned: bool = false) -> void:
    # Top and bottom are actual 4x4 tessellations, hem has real thickness.
    var grid: Array = []
    for iz in range(5):
        var row: Array[Vector3] = []
        var z: float = -0.5 + float(iz) * 0.25
        for ix in range(5):
            var x: float = -0.5 + float(ix) * 0.25
            # Fixed perimeter: scaling this canopy along local Y changes
            # only the inner fabric billow, not its attachment rails.
            var y: float = _canopy_y(x, z)
            if pinned:
                y = 0.46 * (1.0 - 4.0 * x * x) * (1.0 - 4.0 * z * z)
            row.append(Vector3(x, y, z))
        grid.append(row)
    for iz in range(4):
        for ix in range(4):
            var a: Vector3 = grid[iz][ix]
            var c: Vector3 = grid[iz + 1][ix + 1]
            var b: Vector3 = grid[iz][ix + 1]
            var d: Vector3 = grid[iz + 1][ix]
            _quad(st, a, b, c, d, Vector3.UP)
            var depth := Vector3(0, -0.025, 0)
            _quad(st, d + depth, c + depth, b + depth, a + depth,
                Vector3.DOWN)
    for i in range(4):
        var a: Vector3 = grid[0][i]
        var b: Vector3 = grid[0][i + 1]
        _quad(st, a, b, b + Vector3(0, -0.025, 0),
            a + Vector3(0, -0.025, 0), Vector3(0, 0, -1))
        var c: Vector3 = grid[4][i]
        var d: Vector3 = grid[4][i + 1]
        _quad(st, c, d, d + Vector3(0, -0.025, 0),
            c + Vector3(0, -0.025, 0), Vector3(0, 0, 1))
        var e: Vector3 = grid[i][0]
        var f: Vector3 = grid[i + 1][0]
        _quad(st, e, f, f + Vector3(0, -0.025, 0),
            e + Vector3(0, -0.025, 0), Vector3(-1, 0, 0))
        var g: Vector3 = grid[i][4]
        var h: Vector3 = grid[i + 1][4]
        _quad(st, g, h, h + Vector3(0, -0.025, 0),
            g + Vector3(0, -0.025, 0), Vector3(1, 0, 0))

static func _rotor(st: SurfaceTool, teeth: bool) -> void:
    # Tooth profiles and ribs are vertices, not attached box decorations.
    var segments: int = 20 if teeth else 16
    var levels := [-0.5, -0.35, 0.35, 0.5]
    for row in range(3):
        var y0: float = levels[row]
        var y1: float = levels[row + 1]
        for i in range(segments):
            var j: int = (i + 1) % segments
            var a: float = float(i) * TAU / float(segments)
            var b: float = float(j) * TAU / float(segments)
            var outer_i: float = (
                (0.50 if i % 2 == 0 else 0.37) if teeth else
                (0.49 if row == 0 or row == 2 else 0.43))
            var outer_j: float = (
                (0.50 if j % 2 == 0 else 0.37) if teeth else
                (0.49 if row == 0 or row == 2 else 0.43))
            var a0 := Vector3(cos(a) * outer_i, y0, sin(a) * outer_i)
            var b0 := Vector3(cos(b) * outer_j, y0, sin(b) * outer_j)
            var a1 := Vector3(cos(a) * outer_i, y1, sin(a) * outer_i)
            var b1 := Vector3(cos(b) * outer_j, y1, sin(b) * outer_j)
            var outward := Vector3(cos((a + b) * 0.5), 0,
                sin((a + b) * 0.5))
            _quad(st, a0, b0, b1, a1, outward)
    for i in range(segments):
        var j: int = (i + 1) % segments
        var a: float = float(i) * TAU / float(segments)
        var b: float = float(j) * TAU / float(segments)
        var ra: float = (0.50 if i % 2 == 0 else 0.37) if teeth else 0.49
        var rb: float = (0.50 if j % 2 == 0 else 0.37) if teeth else 0.49
        _triangle(st, Vector3(0, -0.5, 0),
            Vector3(cos(b) * rb, -0.5, sin(b) * rb),
            Vector3(cos(a) * ra, -0.5, sin(a) * ra), Vector3.DOWN)
        _triangle(st, Vector3(0, 0.5, 0),
            Vector3(cos(a) * ra, 0.5, sin(a) * ra),
            Vector3(cos(b) * rb, 0.5, sin(b) * rb), Vector3.UP)

# Directly authored 6-sided roof cross section. Both end caps, two sloped
# planes and the eave faces are physical triangles, not layered flat cubes.
static func _roof(st: SurfaceTool) -> void:
    var profile: Array[Vector2] = [
        Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
        Vector2(0.5, -0.18), Vector2(0.105, 0.37),
        Vector2(-0.105, 0.37), Vector2(-0.5, -0.18),
    ]
    for i in range(profile.size()):
        var j: int = (i + 1) % profile.size()
        var a: Vector2 = profile[i]
        var b: Vector2 = profile[j]
        var normal := Vector3(b.y - a.y, a.x - b.x, 0)
        _quad(st, Vector3(a.x, a.y, -0.5),
            Vector3(a.x, a.y, 0.5), Vector3(b.x, b.y, 0.5),
            Vector3(b.x, b.y, -0.5), normal)
        _triangle(st, Vector3(0, -0.13, 0.5),
            Vector3(a.x, a.y, 0.5), Vector3(b.x, b.y, 0.5),
            Vector3(0, 0, 1))
        _triangle(st, Vector3(0, -0.13, -0.5),
            Vector3(b.x, b.y, -0.5), Vector3(a.x, a.y, -0.5),
            Vector3(0, 0, -1))

static func _beam(st: SurfaceTool, minimum: Vector3,
        maximum: Vector3) -> void:
    var l := Vector3(minimum.x, minimum.y, minimum.z)
    var r := Vector3(maximum.x, maximum.y, maximum.z)
    # Explicitly separate outer wall, front rail and inner bevel faces.
    _quad(st, Vector3(l.x,l.y,r.z), Vector3(r.x,l.y,r.z),
        Vector3(r.x,r.y,r.z), Vector3(l.x,r.y,r.z), Vector3(0,0,1))
    _quad(st, Vector3(l.x,l.y,l.z), Vector3(l.x,r.y,l.z),
        Vector3(r.x,r.y,l.z), Vector3(r.x,l.y,l.z), Vector3(0,0,-1))
    _quad(st, Vector3(l.x,r.y,l.z), Vector3(l.x,r.y,r.z),
        Vector3(r.x,r.y,r.z), Vector3(r.x,r.y,l.z), Vector3.UP)
    _quad(st, Vector3(l.x,l.y,l.z), Vector3(r.x,l.y,l.z),
        Vector3(r.x,l.y,r.z), Vector3(l.x,l.y,r.z), Vector3.DOWN)
    _quad(st, Vector3(r.x,l.y,l.z), Vector3(r.x,r.y,l.z),
        Vector3(r.x,r.y,r.z), Vector3(r.x,l.y,r.z), Vector3.RIGHT)
    _quad(st, Vector3(l.x,l.y,l.z), Vector3(l.x,l.y,r.z),
        Vector3(l.x,r.y,r.z), Vector3(l.x,r.y,l.z), Vector3.LEFT)

static func _louver(st: SurfaceTool) -> void:
    # A recessed OPEN housing: exterior frame and five raised sloped blades,
    # all in one cached ArrayMesh, with no overlapping solid rear cube.
    _beam(st, Vector3(-0.5,-0.5,0.06),
        Vector3(-0.36,0.5,0.48))
    _beam(st, Vector3(0.36,-0.5,0.06),
        Vector3(0.5,0.5,0.48))
    _beam(st, Vector3(-0.36,0.36,0.08),
        Vector3(0.36,0.5,0.48))
    _beam(st, Vector3(-0.36,-0.5,0.08),
        Vector3(0.36,-0.36,0.48))
    for slot in range(5):
        var y: float = -0.30 + float(slot) * 0.15
        # The protruding lower lip catches a highlight at isometric view.
        var a := Vector3(-0.34, y + 0.10, 0.13)
        var b := Vector3(0.34, y + 0.10, 0.13)
        var c := Vector3(0.34, y, 0.45)
        var d := Vector3(-0.34, y, 0.45)
        _quad(st, a, b, c, d, Vector3(0, 0.8, 0.6))
        _quad(st, d + Vector3(0,-0.025,0),
            c + Vector3(0,-0.025,0),
            b + Vector3(0,-0.025,0),
            a + Vector3(0,-0.025,0), Vector3(0,-0.8,-0.6))


# The following profiles are authored once, then instanced through BASE's
# existing material MultiMeshes. Their silhouette, cavity and metalwork are
# actual geometry instead of overlapping decorative boxes.
static func _cargo_case(st: SurfaceTool) -> void:
    _beam(st, Vector3(-0.46, -0.49, -0.43),
        Vector3(0.46, 0.34, 0.43))
    _beam(st, Vector3(-0.50, 0.32, -0.48),
        Vector3(0.50, 0.49, 0.48))
    for side in [-1.0, 1.0]:
        var x: float = side * 0.42
        _beam(st, Vector3(x - 0.065, -0.46, 0.41),
            Vector3(x + 0.065, 0.34, 0.50))
        _beam(st, Vector3(x - 0.07, -0.46, -0.49),
            Vector3(x + 0.07, 0.34, -0.41))
    _beam(st, Vector3(-0.48, -0.47, 0.44),
        Vector3(0.48, -0.37, 0.51))


static func _reinforced_tray(st: SurfaceTool) -> void:
    # Open upper face: no slab conceals items placed inside the fabrication bed.
    _beam(st, Vector3(-0.48, -0.50, -0.48),
        Vector3(0.48, -0.34, 0.48))
    for side in [-1.0, 1.0]:
        var x: float = side * 0.445
        var z: float = side * 0.445
        _beam(st, Vector3(x - 0.055, -0.34, -0.49),
            Vector3(x + 0.055, 0.50, 0.49))
        _beam(st, Vector3(-0.49, -0.34, z - 0.055),
            Vector3(0.49, 0.50, z + 0.055))
    for side in [-1.0, 1.0]:
        var x: float = side * 0.28
        _beam(st, Vector3(x - 0.033, -0.33, -0.41),
            Vector3(x + 0.033, -0.25, 0.41))


static func _vent_stack(st: SurfaceTool) -> void:
    # Sixteen-facet hollow steel sleeve with two integrated raised collars.
    # Open end is visible from the angled BASE camera; the cavity is real.
    var segments: int = 16
    for i in range(segments):
        var a: float = TAU * float(i) / float(segments)
        var b: float = TAU * float(i + 1) / float(segments)
        var outward := Vector3(cos((a + b) * 0.5), 0,
            sin((a + b) * 0.5))
        var o0 := Vector3(cos(a) * 0.47, -0.5, sin(a) * 0.47)
        var o1 := Vector3(cos(b) * 0.47, -0.5, sin(b) * 0.47)
        var o2 := Vector3(o1.x, 0.5, o1.z)
        var o3 := Vector3(o0.x, 0.5, o0.z)
        var h0 := Vector3(cos(a) * 0.31, -0.5, sin(a) * 0.31)
        var h1 := Vector3(cos(b) * 0.31, -0.5, sin(b) * 0.31)
        var h2 := Vector3(h1.x, 0.5, h1.z)
        var h3 := Vector3(h0.x, 0.5, h0.z)
        _quad(st, o0, o1, o2, o3, outward)
        _quad(st, h1, h0, h3, h2, -outward)
        _quad(st, h3, o3, o2, h2, Vector3.UP)
        _quad(st, o0, h0, h1, o1, Vector3.DOWN)
        for band in [Vector2(-0.45, -0.36), Vector2(0.37, 0.48)]:
            var a0 := Vector3(cos(a) * 0.54, band.x, sin(a) * 0.54)
            var a1 := Vector3(cos(b) * 0.54, band.x, sin(b) * 0.54)
            var b0 := Vector3(a0.x, band.y, a0.z)
            var b1 := Vector3(a1.x, band.y, a1.z)
            var inner0 := Vector3(cos(a) * 0.47, band.y, sin(a) * 0.47)
            var inner1 := Vector3(cos(b) * 0.47, band.y, sin(b) * 0.47)
            _quad(st, a0, a1, b1, b0, outward)
            _quad(st, b0, b1, inner1, inner0, Vector3.UP)


static func _welded_gusset(st: SurfaceTool) -> void:
    # Rigid triangular web joining machine booms and roof uprights.
    var profile: Array[Vector2] = [
        Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5)]
    for i in range(3):
        var a: Vector2 = profile[i]
        var b: Vector2 = profile[(i + 1) % 3]
        var normal := Vector3(b.y - a.y, a.x - b.x, 0)
        _quad(st, Vector3(a.x, a.y, -0.5),
            Vector3(b.x, b.y, -0.5),
            Vector3(b.x, b.y, 0.5),
            Vector3(a.x, a.y, 0.5), normal)
    _triangle(st, Vector3(-0.5, -0.5, 0.5),
        Vector3(0.5, -0.5, 0.5),
        Vector3(-0.5, 0.5, 0.5), Vector3(0, 0, 1))
    _triangle(st, Vector3(-0.5, 0.5, -0.5),
        Vector3(0.5, -0.5, -0.5),
        Vector3(-0.5, -0.5, -0.5), Vector3(0, 0, -1))


# One continuous extruded U-shaped portal. The inner clipped corners are
# formed by the actual profile, not rotated overlapping rectangular parts.
static func _nexus_portal(st: SurfaceTool) -> void:
    var profile := PackedVector2Array([
        Vector2(-0.50, -0.50), Vector2(-0.50, 0.39),
        Vector2(-0.39, 0.50), Vector2(0.39, 0.50),
        Vector2(0.50, 0.39), Vector2(0.50, -0.50),
        Vector2(0.38, -0.50), Vector2(0.38, 0.30),
        Vector2(0.31, 0.37), Vector2(-0.31, 0.37),
        Vector2(-0.38, 0.30), Vector2(-0.38, -0.50)
    ])
    var triangles := Geometry2D.triangulate_polygon(profile)
    for i in range(0, triangles.size(), 3):
        var a: Vector2 = profile[triangles[i]]
        var b: Vector2 = profile[triangles[i + 1]]
        var c: Vector2 = profile[triangles[i + 2]]
        _triangle(st, Vector3(a.x, a.y, 0.5), Vector3(b.x, b.y, 0.5),
            Vector3(c.x, c.y, 0.5), Vector3.BACK)
        _triangle(st, Vector3(a.x, a.y, -0.5), Vector3(b.x, b.y, -0.5),
            Vector3(c.x, c.y, -0.5), Vector3.FORWARD)
    for i in range(profile.size()):
        var a: Vector2 = profile[i]
        var b: Vector2 = profile[(i + 1) % profile.size()]
        var direction: Vector2 = b - a
        # Clockwise XY profile: the left normal points out of the solid.
        _quad(st, Vector3(a.x, a.y, -0.5), Vector3(b.x, b.y, -0.5),
            Vector3(b.x, b.y, 0.5), Vector3(a.x, a.y, 0.5),
            Vector3(-direction.y, direction.x, 0.0))

# Short pleated front skirt. Its top edge is straight at Y=+0.5;
# the lower edge has a visible fabric scallop and folded depth.
static func _nexus_awning_skirt(st: SurfaceTool) -> void:
    for i in range(8):
        var x0: float = -0.5 + float(i) / 8.0
        var x1: float = -0.5 + float(i + 1) / 8.0
        var a := Vector3(x0, 0.5, 0)
        var b := Vector3(x1, 0.5, 0)
        var c := Vector3(x1, -0.46 + 0.04 * cos(x1 * TAU * 3.0),
            0.35 * sin(x1 * TAU * 2.0))
        var d := Vector3(x0, -0.46 + 0.04 * cos(x0 * TAU * 3.0),
            0.35 * sin(x0 * TAU * 2.0))
        _quad(st, a, b, c, d, Vector3.BACK)
        _quad(st, a, d, c, b, Vector3.FORWARD)

# The dish is a real shallow paraboloid with a closed thin backing.
static func _nexus_dish(st: SurfaceTool) -> void:
    const SEGMENTS: int = 16
    for side in [0.0, -0.05]:
        for ring in range(3):
            var r0: float = float(ring) / 6.0
            var r1: float = float(ring + 1) / 6.0
            for i in range(SEGMENTS):
                var a: float = TAU * float(i) / float(SEGMENTS)
                var b: float = TAU * float(i + 1) / float(SEGMENTS)
                var p := Vector3(r0 * cos(a), r0 * sin(a), side + 1.8 * r0 * r0)
                var q := Vector3(r1 * cos(a), r1 * sin(a), side + 1.8 * r1 * r1)
                var u := Vector3(r1 * cos(b), r1 * sin(b), side + 1.8 * r1 * r1)
                var v := Vector3(r0 * cos(b), r0 * sin(b), side + 1.8 * r0 * r0)
                _quad(st, p, q, u, v, Vector3.BACK if side == 0.0 else Vector3.FORWARD)
    for i in range(SEGMENTS):
        var a: float = TAU * float(i) / float(SEGMENTS)
        var b: float = TAU * float(i + 1) / float(SEGMENTS)
        var p := Vector3(0.5 * cos(a), 0.5 * sin(a), 0.45)
        var q := Vector3(0.5 * cos(b), 0.5 * sin(b), 0.45)
        _quad(st, p, q, q - Vector3(0, 0, 0.05),
            p - Vector3(0, 0, 0.05), Vector3(cos((a+b)*0.5), sin((a+b)*0.5), 0))

static func make(kind: String) -> ArrayMesh:
    if _mesh_cache.has(kind):
        return _mesh_cache[kind] as ArrayMesh
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    match kind:
        "deck":
            _beveled(st, true)
        "bevel":
            _beveled(st, false)
        "nexus_shallow_bevel":
            _beveled(st, false, true)
        "nexus_portal":
            _nexus_portal(st)
        "hopper":
            _hopper(st)
        "hood":
            _hood(st)
        "canvas":
            _canvas(st)
        "nexus_canvas":
            _canvas(st, true)
        "nexus_awning_skirt":
            _nexus_awning_skirt(st)
        "nexus_dish":
            _nexus_dish(st)
        "drum":
            _rotor(st, false)
        "gear":
            _rotor(st, true)
        "octagonal_slew":
            _octagonal_slew(st)
        "roof":
            _roof(st)
        "louver":
            _louver(st)
        "cargo_case":
            _cargo_case(st)
        "tray":
            _reinforced_tray(st)
        "vent_stack":
            _vent_stack(st)
        "gusset":
            _welded_gusset(st)
        _:
            push_error("Unsupported SERA BASE polygon type: " + kind)
            return null
    var authored: ArrayMesh = st.commit()
    _mesh_cache[kind] = authored
    return authored

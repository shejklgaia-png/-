extends RefCounted
## SERA BASE physically sculpted meshes, assembled from explicit triangles.
## Meshes are immutable shared unit shapes: facility transforms supply size.
## Materials and primitive geometry are reused across MultiMesh batches.
## No procedural runtime noise, physics, shadows, or per-frame work.

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
    for point in [a, b, c]:
        var p: Vector3 = point
        var uv: Vector2
        if absf(normal.y) > 0.55:
            uv = Vector2(p.x + 0.5, p.z + 0.5)
        elif absf(normal.x) > absf(normal.z):
            uv = Vector2(p.z + 0.5, 0.5 - p.y)
        else:
            uv = Vector2(p.x + 0.5, 0.5 - p.y)
        st.set_normal(normal)
        st.set_uv(uv)
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

static func _beveled(st: SurfaceTool, deck: bool) -> void:
    # 8-sided footprint, stepped top lip, individually triangulated bevels.
    # Plate top remains +0.5 so world Y=-0.03 floor level stays unchanged.
    var clip: float = 0.045 if deck else 0.13
    var inset: float = 0.028 if deck else 0.075
    var lower: Array[Vector3] = _octagonal_ring(-0.5, 0.5, clip)
    var shoulder: Array[Vector3] = _octagonal_ring(
        0.38 if deck else 0.33, 0.5, clip)
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

static func _canvas(st: SurfaceTool) -> void:
    # Top and bottom are actual 4x4 tessellations, hem has real thickness.
    var grid: Array = []
    for iz in range(5):
        var row: Array[Vector3] = []
        var z: float = -0.5 + float(iz) * 0.25
        for ix in range(5):
            var x: float = -0.5 + float(ix) * 0.25
            row.append(Vector3(x, _canopy_y(x, z), z))
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
        "hopper":
            _hopper(st)
        "hood":
            _hood(st)
        "canvas":
            _canvas(st)
        "drum":
            _rotor(st, false)
        "gear":
            _rotor(st, true)
        _:
            push_error("Unsupported SERA BASE polygon type: " + kind)
            return null
    var authored: ArrayMesh = st.commit()
    _mesh_cache[kind] = authored
    return authored

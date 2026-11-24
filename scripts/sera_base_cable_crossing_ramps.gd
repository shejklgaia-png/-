extends Node3D
## Opaque, load-bearing cable protectors, generated only on reserved roads.
## Continuous cross-section: a raised hollow cap and two sloping tread plates.
const STEP: float = 0.24
const HALF_TOP: float = 0.30
const HALF_WIDTH: float = 0.94
const FLOOR: float = -0.03
const HASH: float = 1.5
var _segments: Array[Dictionary] = []
var _index: Dictionary = {}

func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)

func _key(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / HASH), floori(p.y / HASH))

func _sample(points: PackedVector3Array) -> PackedVector3Array:
    var out := PackedVector3Array()
    if points.is_empty():
        return out
    out.append(points[0])
    for i in range(1, points.size()):
        var a: Vector3 = points[i - 1]
        var b: Vector3 = points[i]
        var n: int = maxi(1, ceili(_xz(a).distance_to(_xz(b)) / STEP))
        for j in range(1, n + 1):
            out.append(a.lerp(b, float(j) / float(n)))
    return out

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for p in [a, b, c, a, c, d]:
        st.add_vertex(p)

func _profile(p: Vector3, tangent: Vector2, radius: float) -> PackedVector3Array:
    var across := Vector2(-tangent.y, tangent.x)
    var top: float = maxf(0.28, p.y + radius + 0.10)
    var positions := PackedVector3Array()
    for x in [-HALF_WIDTH, -HALF_TOP, HALF_TOP, HALF_WIDTH]:
        var point: Vector2 = _xz(p) + across * x
        positions.append(Vector3(point.x, top if absf(x) < 0.4 else FLOOR + 0.025, point.y))
    return positions

func _record(a: Vector3, b: Vector3, radius: float) -> void:
    var record: Dictionary = {"a": _xz(a), "b": _xz(b),
        "ha": maxf(0.28, a.y + radius + 0.10),
        "hb": maxf(0.28, b.y + radius + 0.10)}
    var index: int = _segments.size()
    _segments.append(record)
    var lo: Vector2 = _xz(a).min(_xz(b)) - Vector2.ONE * (HALF_WIDTH + 0.15)
    var hi: Vector2 = _xz(a).max(_xz(b)) + Vector2.ONE * (HALF_WIDTH + 0.15)
    var first: Vector2i = _key(lo)
    var last: Vector2i = _key(hi)
    for x in range(first.x, last.x + 1):
        for z in range(first.y, last.y + 1):
            var cell := Vector2i(x, z)
            if not _index.has(cell):
                _index[cell] = []
            (_index[cell] as Array).append(index)

func build(paths: Array[Dictionary], logistics: Node3D) -> void:
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var yellow := SurfaceTool.new()
    yellow.begin(Mesh.PRIMITIVE_TRIANGLES)
    for path in paths:
        var points: PackedVector3Array = _sample(path["points"])
        var radius: float = float(path["radius"])
        if points.size() < 2:
            continue
        var active: Array[bool] = []
        for i in range(points.size() - 1):
            var mid: Vector2 = _xz((points[i] + points[i + 1]) * 0.5)
            active.append(bool(logistics.call("road_at", mid)))
        # One sample of overlap beyond each crossing protects the road edge.
        for i in range(points.size() - 1):
            if not active[i] and not (i > 0 and active[i - 1]) and not (i + 1 < active.size() and active[i + 1]):
                continue
            var a: Vector3 = points[i]
            var b: Vector3 = points[i + 1]
            if _xz(a).distance_squared_to(_xz(b)) < 0.00001:
                continue
            var before: Vector2 = _xz(points[maxi(0, i - 1)])
            var after: Vector2 = _xz(points[mini(points.size() - 1, i + 2)])
            var ta: Vector2 = (_xz(b) - before).normalized()
            var tb: Vector2 = (after - _xz(a)).normalized()
            var pa: PackedVector3Array = _profile(a, ta, radius)
            var pb: PackedVector3Array = _profile(b, tb, radius)
            # Yellow beveled approaches, dark non-slip central cap. The
            # underside is open for the existing cable, not a solid block.
            _quad(yellow, pa[0], pb[0], pb[1], pa[1])
            _quad(deck, pa[1], pb[1], pb[2], pa[2])
            _quad(yellow, pa[2], pb[2], pb[3], pa[3])
            if i % 3 == 0:
                var up := Vector3.UP * 0.012
                var left: Vector3 = pa[1].lerp(pa[2], 0.09) + up
                var right: Vector3 = pa[1].lerp(pa[2], 0.91) + up
                var left_end: Vector3 = left.lerp(pb[1] + up, 0.16)
                var right_end: Vector3 = right.lerp(pb[2] + up, 0.16)
                _quad(yellow, left, left_end, right_end, right)
            _record(a, b, radius)
    if _segments.is_empty():
        return
    _finish(deck, "CableProtectorSteelDeck", Color("#4b535a"))
    _finish(yellow, "CableProtectorSafetyRamps", Color("#d9ab40"))
    print("SERA_BASE_LOGISTICS: cable ramp sections=", _segments.size())

func _finish(st: SurfaceTool, label: String, tint: Color) -> void:
    st.generate_normals()
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.30
    material.roughness = 0.84
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = st.commit()
    draw.material_override = material
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.set_meta("sera_outline_role", "clutter")
    draw.set_meta("sera_preserve_authored_material", true)
    add_child(draw)

func height_at(p: Vector2) -> float:
    var y: float = 0.0
    for value in _index.get(_key(p), []):
        var seg: Dictionary = _segments[int(value)]
        var a: Vector2 = seg["a"]
        var b: Vector2 = seg["b"]
        var axis: Vector2 = b - a
        var fraction: float = (p - a).dot(axis) / axis.length_squared()
        if fraction < -0.1 or fraction > 1.1:
            continue
        var distance: float = p.distance_to(a + axis * clampf(fraction, 0.0, 1.0))
        if distance >= HALF_WIDTH:
            continue
        var slope: float = 1.0 - clampf((distance - HALF_TOP) / (HALF_WIDTH - HALF_TOP), 0.0, 1.0)
        y = maxf(y, (lerpf(float(seg["ha"]), float(seg["hb"]), clampf(fraction, 0.0, 1.0)) - FLOOR) * slope)
    return y

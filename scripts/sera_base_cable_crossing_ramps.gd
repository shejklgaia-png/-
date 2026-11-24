extends Node3D
## Narrow modular protectors follow the cable, never the bounding rectangle
## of several intersecting roads. Coverage and height use the same profile.
const FLOOR: float = -0.005
const SAMPLE_STEP: float = 0.22
const TRACK_SWEEP: float = 0.58
const HASH_SIZE: float = 1.5
var _sections: Array[Dictionary] = []
var _index: Dictionary = {}


func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for p in [a, b, c, a, c, d]:
        st.add_vertex(p)


func _sample(points: PackedVector3Array) -> PackedVector3Array:
    var result := PackedVector3Array()
    if points.is_empty():
        return result
    result.append(points[0])
    for i in range(1, points.size()):
        var a: Vector3 = points[i - 1]
        var b: Vector3 = points[i]
        var length: float = _xz(a).distance_to(_xz(b))
        if length < 0.003:
            continue
        var count: int = maxi(1, ceili(length / SAMPLE_STEP))
        for j in range(1, count + 1):
            result.append(a.lerp(b, float(j) / float(count)))
    return result


func _road_bounds(roads: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for road in roads:
        var a: Vector2 = road["a"]
        var b: Vector2 = road["b"]
        if a.distance_squared_to(b) < 0.00001:
            continue
        result.append({"a": a, "b": b, "bounds": Rect2(a.min(b), (b - a).abs()).grow(TRACK_SWEEP + 0.20)})
    return result


func _needs_cover(a: Vector2, b: Vector2, radius: float, roads: Array[Dictionary]) -> bool:
    var bounds := Rect2(a.min(b), (b - a).abs()).grow(0.01)
    for road in roads:
        var road_box: Rect2 = road["bounds"]
        if not road_box.intersects(bounds):
            continue
        var nearest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a, b, road["a"], road["b"])
        if nearest.size() == 2 and nearest[0].distance_to(nearest[1]) <= TRACK_SWEEP + radius:
            return true
    return false


func _profile(points: PackedVector3Array, i: int, radius: float, bias: float) -> PackedVector3Array:
    var p: Vector3 = points[i]
    var before: Vector2 = _xz(points[maxi(0, i - 1)])
    var after: Vector2 = _xz(points[mini(points.size() - 1, i + 1)])
    var direction: Vector2 = (after - before).normalized()
    if direction.length_squared() < 0.001:
        direction = Vector2.RIGHT
    var normal := Vector2(-direction.y, direction.x)
    # Cross-cable width is strictly local: normally 0.79m, thick GRID
    # cable 0.94m. No width increase due to road length or other cables.
    var half_top: float = radius + 0.075
    var half_width: float = half_top + 0.25
    var top: float = maxf(0.16, p.y + radius + 0.035) + bias
    var row := PackedVector3Array()
    for offset in [-half_width, -half_top, half_top, half_width]:
        var at: Vector2 = _xz(p) + normal * float(offset)
        row.append(Vector3(at.x, top if absf(float(offset)) <= half_top + 0.001 else FLOOR + bias, at.y))
    return row


func _key(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / HASH_SIZE), floori(p.y / HASH_SIZE))


func _record(pa: PackedVector3Array, pb: PackedVector3Array) -> void:
    var bounds := Rect2(_xz(pa[0]), Vector2.ZERO)
    for p in pa:
        bounds = bounds.expand(_xz(p))
    for p in pb:
        bounds = bounds.expand(_xz(p))
    var id: int = _sections.size()
    _sections.append({"bounds": bounds, "pa": pa, "pb": pb})
    var low: Vector2i = _key(bounds.position)
    var high: Vector2i = _key(bounds.end)
    for x in range(low.x, high.x + 1):
        for z in range(low.y, high.y + 1):
            var k := Vector2i(x, z)
            if not _index.has(k):
                _index[k] = []
            (_index[k] as Array).append(id)


func _emit_section(deck: SurfaceTool, trim: SurfaceTool, points: PackedVector3Array, i: int, radius: float, bias: float) -> void:
    var pa: PackedVector3Array = _profile(points, i, radius, bias)
    var pb: PackedVector3Array = _profile(points, i + 1, radius, bias)
    for j in range(3):
        _quad(deck, pa[j], pb[j], pb[j + 1], pa[j + 1])
    # Thin safety markings on the flat cover, not large yellow slopes.
    var up := Vector3.UP * 0.008
    for fraction in [0.0, 0.84]:
        var k: float = fraction
        _quad(trim, pa[1].lerp(pa[2], k) + up, pb[1].lerp(pb[2], k) + up,
            pb[1].lerp(pb[2], k + 0.16) + up, pa[1].lerp(pa[2], k + 0.16) + up)
    _record(pa, pb)


func build(paths: Array[Dictionary], logistics: Node3D) -> void:
    await _build_narrow(paths, logistics, null)


func build_budgeted(paths: Array[Dictionary], logistics: Node3D, budget: Variant) -> void:
    await _build_narrow(paths, logistics, budget)


func _build_narrow(paths: Array[Dictionary], logistics: Node3D, budget: Variant) -> void:
    var roads: Array[Dictionary] = _road_bounds(logistics.call("road_segments"))
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    var cable_id: int = 0
    for path in paths:
        var points: PackedVector3Array = _sample(path["points"])
        var radius: float = float(path["radius"])
        # Different cables may cross. A tiny per-cable offset avoids
        # coplanar faces without ever merging their footprints.
        var bias: float = float(cable_id) * 0.001
        cable_id += 1
        var active: Array[bool] = []
        for i in range(points.size() - 1):
            if budget != null:
                await budget.checkpoint("narrow cable protector scan")
            active.append(_needs_cover(_xz(points[i]), _xz(points[i + 1]), radius, roads))
        for i in range(active.size()):
            if not active[i] and not (i > 0 and active[i - 1]) and not (i + 1 < active.size() and active[i + 1]):
                continue
            if budget != null:
                await budget.checkpoint("narrow cable protector mesh")
            _emit_section(deck, trim, points, i, radius, bias)
    if _sections.is_empty():
        return
    _finish(deck, "CableProtectorSteelDeck", Color("#41494f"))
    if budget != null:
        await budget.checkpoint("narrow cable protector deck")
    _finish(trim, "CableProtectorSafetyEdges", Color("#b99b47"))
    print("SERA_BASE_LOGISTICS: narrow cable protector sections=", _sections.size())


func placement_bounds() -> Array[Rect2]:
    var result: Array[Rect2] = []
    for section in _sections:
        result.append(section["bounds"])
    return result


func _finish(st: SurfaceTool, label: String, tint: Color) -> void:
    st.generate_normals()
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.24
    material.roughness = 0.88
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = st.commit()
    draw.material_override = material
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.set_meta("sera_outline_role", "clutter")
    draw.set_meta("sera_preserve_authored_material", true)
    add_child(draw)


# Interpolate the exact generated triangles rather than guessing a separate
# rectangular height map. This also handles turns and intersecting protectors.
func _triangle_height(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
    var aa: Vector2 = _xz(a)
    var ab: Vector2 = _xz(b) - aa
    var ac: Vector2 = _xz(c) - aa
    var relative: Vector2 = p - aa
    var det: float = ab.cross(ac)
    if absf(det) < 0.000001:
        return 0.0
    var u: float = relative.cross(ac) / det
    var v: float = ab.cross(relative) / det
    if u < -0.0001 or v < -0.0001 or u + v > 1.0001:
        return 0.0
    return a.y + (b.y - a.y) * u + (c.y - a.y) * v


func height_at(p: Vector2) -> float:
    var y: float = 0.0
    for id in _index.get(_key(p), []):
        var section: Dictionary = _sections[int(id)]
        var bounds: Rect2 = section["bounds"]
        if not bounds.grow(0.001).has_point(p):
            continue
        var pa: PackedVector3Array = section["pa"]
        var pb: PackedVector3Array = section["pb"]
        for j in range(3):
            y = maxf(y, _triangle_height(p, pa[j], pb[j], pb[j + 1]))
            y = maxf(y, _triangle_height(p, pa[j], pb[j + 1], pa[j + 1]))
    return y

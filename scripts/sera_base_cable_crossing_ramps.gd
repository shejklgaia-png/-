extends Node3D
## One compact rigid industrial cable protector per actual crossing.
## Parallel route overlap is not a reason to extrude a yellow cable ribbon.
const FLOOR: float = -0.005
const HALF_RAMP: float = 0.48
const HALF_LANE: float = 0.82
var _pads: Array[Dictionary] = []

func _xz(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for p in [a, b, c, a, c, d]:
        st.add_vertex(p)


func _world(pad: Dictionary, x: float, z: float, height: float) -> Vector3:
    var axis: Vector2 = pad["axis"]
    var side := Vector2(-axis.y, axis.x)
    var p: Vector2 = (pad["center"] as Vector2) + side * x + axis * z
    return Vector3(p.x, height, p.y)


func _corners(pad: Dictionary) -> PackedVector2Array:
    var result := PackedVector2Array()
    for x in [-float(pad["wide"]), float(pad["wide"])]:
        for z in [-float(pad["flat"]) - HALF_RAMP, float(pad["flat"]) + HALF_RAMP]:
            result.append(_xz(_world(pad, x, z, 0.0)))
    return result


func _bounds_on(points: PackedVector2Array, axis: Vector2) -> Vector2:
    var low: float = INF
    var high: float = -INF
    for p in points:
        var n: float = p.dot(axis)
        low = minf(low, n)
        high = maxf(high, n)
    return Vector2(low, high)


func _overlap(a: Dictionary, b: Dictionary) -> bool:
    var aa: Vector2 = a["axis"]
    var ba: Vector2 = b["axis"]
    var ca: PackedVector2Array = _corners(a)
    var cb: PackedVector2Array = _corners(b)
    for value in [aa, Vector2(-aa.y, aa.x), ba, Vector2(-ba.y, ba.x)]:
        var axis: Vector2 = value
        var ra: Vector2 = _bounds_on(ca, axis)
        var rb: Vector2 = _bounds_on(cb, axis)
        if ra.y < rb.x - 0.04 or rb.y < ra.x - 0.04:
            return false
    return true


func _combine(a: Dictionary, b: Dictionary) -> Dictionary:
    # Consolidate intersecting protectors into a single platform; use the
    # first travel direction and enclose the two central cable covers.
    var axis: Vector2 = a["axis"]
    var side := Vector2(-axis.y, axis.x)
    var points: PackedVector2Array = _corners(a)
    points.append_array(_corners(b))
    var along: Vector2 = _bounds_on(points, axis)
    var across: Vector2 = _bounds_on(points, side)
    return {"axis": axis, "center": axis * ((along.x + along.y) * 0.5) + side * ((across.x + across.y) * 0.5),
        "wide": (across.y - across.x) * 0.5,
        "flat": maxf(0.22, (along.y - along.x) * 0.5 - HALF_RAMP),
        "height": maxf(float(a["height"]), float(b["height"]))}


func _add_crossing(point: Vector2, direction: Vector2, wire_direction: Vector2, height: float) -> void:
    var angle: float = absf(direction.cross(wire_direction))
    # Shallow actual crossings still receive a compact cover; longitudinal
    # overlap alone never produces a ribbon.
    angle = maxf(angle, 0.24)
    var pad: Dictionary = {"center": point, "axis": direction,
        "wide": HALF_LANE,
        "flat": clampf(0.24 + 0.35 * absf(direction.dot(wire_direction)) / angle, 0.24, 0.78),
        "height": maxf(0.20, height)}
    for existing in _pads:
        var center: Vector2 = existing["center"]
        if center.distance_to(point) < 0.26:
            existing["height"] = maxf(float(existing["height"]), height)
            return
    # Merge touching platforms before making any mesh. No stacked, crossing
    # or z-fighting ramp triangles can remain.
    var i: int = 0
    while i < _pads.size():
        if _overlap(pad, _pads[i]):
            pad = _combine(_pads[i], pad)
            _pads.remove_at(i)
            i = 0
        else:
            i += 1
    _pads.append(pad)


func build(paths: Array[Dictionary], logistics: Node3D) -> void:
    var roads: Array = logistics.call("road_segments")
    for path in paths:
        var points: PackedVector3Array = path["points"]
        var radius: float = float(path["radius"])
        for i in range(1, points.size()):
            var a: Vector2 = _xz(points[i - 1])
            var b: Vector2 = _xz(points[i])
            if a.distance_squared_to(b) < 0.00001:
                continue
            var wire_dir: Vector2 = (b - a).normalized()
            var wire_bounds := Rect2(a.min(b), (a - b).abs()).grow(0.02)
            for road in roads:
                var c: Vector2 = road["a"]
                var d: Vector2 = road["b"]
                if c.distance_squared_to(d) < 0.00001:
                    continue
                if not wire_bounds.intersects(Rect2(c.min(d), (c - d).abs()).grow(0.02)):
                    continue
                var cross_point: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
                if cross_point == null:
                    continue
                var p: Vector2 = cross_point
                var fraction: float = clampf((p - a).dot(b - a) / a.distance_squared_to(b), 0.0, 1.0)
                var top: float = lerpf(points[i - 1].y, points[i].y, fraction) + radius + 0.055
                _add_crossing(p, (d - c).normalized(), wire_dir, top)
    if _pads.is_empty():
        return
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    for pad in _pads:
        _emit_pad(deck, trim, pad)
    _finish(deck, "CableProtectorSteelDeck", Color("#41494f"))
    _finish(trim, "CableProtectorSafetyEdges", Color("#b99b47"))
    print("SERA_BASE_LOGISTICS: compact cable protectors=", _pads.size())


func _emit_pad(deck: SurfaceTool, trim: SurfaceTool, pad: Dictionary) -> void:
    var width: float = float(pad["wide"])
    var flat: float = float(pad["flat"])
    var top: float = float(pad["height"])
    # One dark rectangular tread, two short sloped approaches and narrow
    # yellow side strips. No bright ribbon along the wire.
    var rows: Array[float] = [-flat - HALF_RAMP, -flat, flat, flat + HALF_RAMP]
    var levels: Array[float] = [FLOOR, top, top, FLOOR]
    for i in range(3):
        var z0: float = rows[i]
        var z1: float = rows[i + 1]
        var h0: float = levels[i]
        var h1: float = levels[i + 1]
        _quad(deck, _world(pad, -width, z0, h0), _world(pad, width, z0, h0),
            _world(pad, width, z1, h1), _world(pad, -width, z1, h1))
        for sign_value in [-1.0, 1.0]:
            var sign_side: float = sign_value
            var x0: float = sign_side * width
            var x1: float = sign_side * (width - 0.09)
            _quad(trim, _world(pad, x0, z0, h0 + 0.008), _world(pad, x1, z0, h0 + 0.008),
                _world(pad, x1, z1, h1 + 0.008), _world(pad, x0, z1, h1 + 0.008))
        # Thin side skirt visually closes the steel plate, leaving the
        # underside cable channel open rather than filling it with solids.
        for sign_value in [-1.0, 1.0]:
            var x: float = float(sign_value) * width
            _quad(deck, _world(pad, x, z0, h0), _world(pad, x, z1, h1),
                _world(pad, x, z1, h1 - 0.045), _world(pad, x, z0, h0 - 0.045))


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


func height_at(p: Vector2) -> float:
    var y: float = 0.0
    for pad in _pads:
        var axis: Vector2 = pad["axis"]
        var offset: Vector2 = p - (pad["center"] as Vector2)
        if absf(offset.cross(axis)) > float(pad["wide"]):
            continue
        var along: float = absf(offset.dot(axis))
        var slope: float = 1.0 - clampf((along - float(pad["flat"])) / HALF_RAMP, 0.0, 1.0)
        y = maxf(y, (float(pad["height"]) - FLOOR) * slope)
    return y

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


func _top_corners(pad: Dictionary) -> PackedVector2Array:
    var result := PackedVector2Array()
    for x in [-float(pad["wide"]), float(pad["wide"])]:
        for z in [-float(pad["flat"]), float(pad["flat"])]:
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
    # Merge the raised tops, not the entire sloping footprint. This keeps
    # both original cable channels under a flat cover after angled merges,
    # without accumulating a new ramp-width at every coincident crossing.
    var points: PackedVector2Array = _top_corners(a)
    points.append_array(_top_corners(b))
    var along: Vector2 = _bounds_on(points, axis)
    var across: Vector2 = _bounds_on(points, side)
    return {"axis": axis, "center": axis * ((along.x + along.y) * 0.5) + side * ((across.x + across.y) * 0.5),
        "wide": (across.y - across.x) * 0.5,
        "flat": maxf(0.24, (along.y - along.x) * 0.5),
        "height": maxf(float(a["height"]), float(b["height"]))}


func _add_crossing(point: Vector2, wire_direction: Vector2, width: float, radius: float, height: float) -> void:
    # The hollow channel follows the actual fixed cable. Slopes are on
    # both sides of the cable, rather than running along the cable itself.
    var normal := Vector2(-wire_direction.y, wire_direction.x)
    var pad: Dictionary = {"center": point, "axis": normal,
        "wide": maxf(HALF_LANE, width),
        "flat": maxf(0.24, radius + 0.12),
        "height": maxf(0.20, height)}
    for existing in _pads:
        var center: Vector2 = existing["center"]
        if center.distance_to(point) < 0.04 and absf((existing["axis"] as Vector2).dot(normal)) > 0.99 and float(existing["wide"]) >= float(pad["wide"]) and float(existing["flat"]) >= float(pad["flat"]):
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


# Project the road's swept footprint onto the cable segment. This catches
# shallow/parallel encounters as well as exact centerline crossings.
func _cover_encounter(a: Vector3, b: Vector3, radius: float, c: Vector2, d: Vector2) -> void:
    var start: Vector2 = _xz(a)
    var finish: Vector2 = _xz(b)
    var wire: Vector2 = finish - start
    var length: float = wire.length()
    if length < 0.003 or c.distance_squared_to(d) < 0.00001:
        return
    var axis: Vector2 = wire / length
    var margin: float = HALF_LANE + radius
    if not Rect2(start.min(finish), wire.abs()).grow(margin).intersects(Rect2(c.min(d), (d - c).abs()).grow(0.02)):
        return
    var nearest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(start, finish, c, d)
    if nearest.size() != 2 or nearest[0].distance_to(nearest[1]) > margin:
        return
    var road_axis: Vector2 = (d - c).normalized()
    var cross_angle: float = absf(axis.cross(road_axis))
    var center_distance: float = (nearest[0] - start).dot(axis)
    var low: float
    var high: float
    if cross_angle >= 0.30:
        var span: float = margin / cross_angle
        low = maxf(0.0, center_distance - span)
        high = minf(length, center_distance + span)
    else:
        # Only the actually shared stretch is covered, not the entire line.
        var u: float = (c - start).dot(axis)
        var v: float = (d - start).dot(axis)
        low = clampf(minf(u, v) - margin, 0.0, length)
        high = clampf(maxf(u, v) + margin, 0.0, length)
    if high < low:
        return
    var mid: float = (low + high) * 0.5
    var top: float = maxf(lerpf(a.y, b.y, low / length), lerpf(a.y, b.y, high / length)) + radius + 0.055
    _add_crossing(start + axis * mid, axis, (high - low) * 0.5 + radius + 0.15, radius, top)


func build(paths: Array[Dictionary], logistics: Node3D) -> void:
    var roads: Array = logistics.call("road_segments")
    for path in paths:
        var points: PackedVector3Array = path["points"]
        var radius: float = float(path["radius"])
        for i in range(1, points.size()):
            for road in roads:
                _cover_encounter(points[i - 1], points[i], radius, road["a"], road["b"])
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


func build_budgeted(paths: Array[Dictionary], logistics: Node3D, budget: Variant) -> void:
    var roads: Array = logistics.call("road_segments")
    for path in paths:
        var points: PackedVector3Array = path["points"]
        var radius: float = float(path["radius"])
        for i in range(1, points.size()):
            await budget.checkpoint("cable crossing scan")
            for road in roads:
                await budget.checkpoint("cable crossing segment")
                _cover_encounter(points[i - 1], points[i], radius, road["a"], road["b"])
    if _pads.is_empty():
        return
    var deck := SurfaceTool.new()
    deck.begin(Mesh.PRIMITIVE_TRIANGLES)
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    for pad in _pads:
        await budget.checkpoint("cable protector mesh")
        _emit_pad(deck, trim, pad)
    _finish(deck, "CableProtectorSteelDeck", Color("#41494f"))
    await budget.checkpoint("cable protector deck")
    _finish(trim, "CableProtectorSafetyEdges", Color("#b99b47"))
    print("SERA_BASE_LOGISTICS: compact cable protectors=", _pads.size())


func placement_bounds() -> Array[Rect2]:
    var result: Array[Rect2] = []
    for pad in _pads:
        var corners: PackedVector2Array = _corners(pad)
        var rect := Rect2(corners[0], Vector2.ZERO)
        for p in corners:
            rect = rect.expand(p)
        result.append(rect)
    return result


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

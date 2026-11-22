extends RefCounted
## Bounded, one-shot CPU extraction of visible mesh/mesh intersections for
## the stationary NEXUS assembly. The result is local-space line segments
## parented to a source mesh and rendered in the SAME 3D pass as live edges.
## No per-frame raycasts, pixel readbacks or duplicate camera.
const MAX_TRIANGLES_PER_SOURCE: int = 500
const MAX_PAIR_TRIANGLE_CHECKS: int = 75000
const EPSILON_SQUARED: float = 0.00000001

static func _aabb_for(a: Vector3, b: Vector3, c: Vector3) -> AABB:
    var low: Vector3 = a.min(b).min(c)
    var high: Vector3 = a.max(b).max(c)
    return AABB(low - Vector3.ONE * 0.0001,
        high - low + Vector3.ONE * 0.0002)

static func _source_triangles(source: MeshInstance3D,
        transform_to_rig: Transform3D) -> Dictionary:
    var result: Array = []
    var bounds: AABB = AABB()
    var initialized: bool = false
    var total: int = 0
    for surface in range(source.mesh.get_surface_count()):
        if source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var arrays: Array = source.mesh.surface_get_arrays(surface)
        var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices := PackedInt32Array()
        if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
            indices = arrays[Mesh.ARRAY_INDEX]
        var count: int = indices.size() if not indices.is_empty() else points.size()
        total += int(count / 3)
        if total > MAX_TRIANGLES_PER_SOURCE:
            return {}
        for i in range(int(count / 3)):
            var ia: int = indices[3 * i] if not indices.is_empty() else 3 * i
            var ib: int = indices[3 * i + 1] if not indices.is_empty() else 3 * i + 1
            var ic: int = indices[3 * i + 2] if not indices.is_empty() else 3 * i + 2
            if ia < 0 or ib < 0 or ic < 0 or (
                    ia >= points.size() or ib >= points.size() or ic >= points.size()):
                continue
            var a: Vector3 = transform_to_rig * points[ia]
            var b: Vector3 = transform_to_rig * points[ib]
            var c: Vector3 = transform_to_rig * points[ic]
            if (b - a).cross(c - a).length_squared() < EPSILON_SQUARED:
                continue
            var box: AABB = _aabb_for(a, b, c)
            if not initialized:
                bounds = box
                initialized = true
            else:
                bounds = bounds.merge(box)
            result.append({"a": a, "b": b, "c": c, "aabb": box})
    if not initialized:
        return {}
    return {"triangles": result, "aabb": bounds,
        "inverse": transform_to_rig.affine_inverse()}

static func _edge_hit(a: Vector3, b: Vector3,
        t0: Vector3, t1: Vector3, t2: Vector3) -> Variant:
    var n: Vector3 = (t1 - t0).cross(t2 - t0)
    var denom: float = n.dot(b - a)
    if absf(denom) < 0.00000001:
        return null
    var t: float = n.dot(t0 - a) / denom
    if t < -0.00001 or t > 1.00001:
        return null
    var hit: Vector3 = a.lerp(b, clampf(t, 0.0, 1.0))
    var u: Vector3 = t1 - t0
    var v: Vector3 = t2 - t0
    var w: Vector3 = hit - t0
    var uu: float = u.dot(u)
    var uv: float = u.dot(v)
    var vv: float = v.dot(v)
    var wu: float = w.dot(u)
    var wv: float = w.dot(v)
    var determinant: float = uu * vv - uv * uv
    if absf(determinant) < 0.0000000001:
        return null
    var x: float = (wu * vv - wv * uv) / determinant
    var y: float = (wv * uu - wu * uv) / determinant
    if x < -0.0001 or y < -0.0001 or x + y > 1.0001:
        return null
    return hit

static func _add_unique(points: Array[Vector3], hit: Variant) -> void:
    if not (hit is Vector3):
        return
    var point: Vector3 = hit
    for current in points:
        if current.distance_squared_to(point) < EPSILON_SQUARED:
            return
    points.append(point)

static func _intersection(a: Dictionary, b: Dictionary) -> PackedVector3Array:
    var hits: Array[Vector3] = []
    var a0: Vector3 = a["a"]
    var a1: Vector3 = a["b"]
    var a2: Vector3 = a["c"]
    var b0: Vector3 = b["a"]
    var b1: Vector3 = b["b"]
    var b2: Vector3 = b["c"]
    for segment in [[a0, a1], [a1, a2], [a2, a0]]:
        _add_unique(hits, _edge_hit(segment[0], segment[1], b0, b1, b2))
    for segment in [[b0, b1], [b1, b2], [b2, b0]]:
        _add_unique(hits, _edge_hit(segment[0], segment[1], a0, a1, a2))
    if hits.size() < 2:
        return PackedVector3Array()
    var maximum: float = EPSILON_SQUARED
    var first: Vector3 = Vector3.ZERO
    var second: Vector3 = Vector3.ZERO
    for i in range(hits.size()):
        for j in range(i + 1, hits.size()):
            var distance: float = hits[i].distance_squared_to(hits[j])
            if distance > maximum:
                maximum = distance
                first = hits[i]
                second = hits[j]
    if maximum <= EPSILON_SQUARED:
        return PackedVector3Array()
    return PackedVector3Array([first, second])

static func build(rig: Node3D, sources: Dictionary) -> Dictionary:
    var keys: Array = sources.keys()
    keys.sort()
    var entries: Dictionary = {}
    var to_rig: Transform3D = rig.global_transform.affine_inverse()
    for key in keys:
        var source: MeshInstance3D = sources[key] as MeshInstance3D
        if not source.is_visible_in_tree() or source.mesh == null:
            continue
        var from_source: Transform3D = to_rig * source.global_transform
        var triangles: Dictionary = _source_triangles(source, from_source)
        if not triangles.is_empty():
            entries[key] = triangles
    var segments: Dictionary = {}
    var visited: Dictionary = {}
    var checked: int = 0
    for i in range(keys.size()):
        var first_key: int = keys[i]
        if not entries.has(first_key):
            continue
        var first: Dictionary = entries[first_key]
        for j in range(i + 1, keys.size()):
            var second_key: int = keys[j]
            if not entries.has(second_key):
                continue
            var second: Dictionary = entries[second_key]
            var first_aabb: AABB = first["aabb"]
            var second_aabb: AABB = second["aabb"]
            if not first_aabb.intersects(second_aabb):
                continue
            var inverse: Transform3D = first["inverse"]
            var out: PackedVector3Array = segments.get(first_key,
                PackedVector3Array())
            for ta in first["triangles"]:
                for tb in second["triangles"]:
                    checked += 1
                    if checked > MAX_PAIR_TRIANGLE_CHECKS:
                        return segments
                    var triangle_aabb: AABB = ta["aabb"]
                    var other_aabb: AABB = tb["aabb"]
                    if not triangle_aabb.intersects(other_aabb):
                        continue
                    var hit: PackedVector3Array = _intersection(ta, tb)
                    if hit.size() != 2:
                        continue
                    var local_a: Vector3 = inverse * hit[0]
                    var local_b: Vector3 = inverse * hit[1]
                    var id_a := Vector3i(roundi(local_a.x * 10000.0),
                        roundi(local_a.y * 10000.0),
                        roundi(local_a.z * 10000.0))
                    var id_b := Vector3i(roundi(local_b.x * 10000.0),
                        roundi(local_b.y * 10000.0),
                        roundi(local_b.z * 10000.0))
                    var key_ab: String = str(id_a) + "/" + str(id_b)
                    var key_ba: String = str(id_b) + "/" + str(id_a)
                    if visited.has(key_ab) or visited.has(key_ba):
                        continue
                    visited[key_ab] = true
                    out.append(local_a)
                    out.append(local_b)
            if not out.is_empty():
                segments[first_key] = out
    return segments

extends RefCounted
## Shared 80-degree hard-edge extraction for BASE and NEXUS.
## Buildings draw both convex and concave 1px corners; clutter retains
## convex-only 1px. Silhouettes and mesh contacts use the RGB12 ID pass.
const CREASE_DEGREES: float = 80.0
const MAX_EDGES_PER_MESH: int = 8000

static func _position_key(p: Vector3) -> String:
    # Blockbench triangulates UV seams with separate, coincident vertices.
    return "%d:%d:%d" % [roundi(p.x * 10000.0),
        roundi(p.y * 10000.0), roundi(p.z * 10000.0)]

static func _extract_edges(mesh: Mesh) -> Array:
    var by_key: Dictionary = {}
    var triangle_seen: Dictionary = {}
    for surface in range(mesh.get_surface_count()):
        # PrimitiveMesh (BoxMesh, SphereMesh, etc.) already uses triangles
        # but does not implement ArrayMesh.surface_get_primitive_type().
        if mesh is ArrayMesh and (
                (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES):
            continue
        var arrays: Array = mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        # Non-indexed mesh surfaces return null for ARRAY_INDEX, not an empty
        # PackedInt32Array. Avoid typed Nil assignment and use vertex order.
        var indices := PackedInt32Array()
        if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
            indices = arrays[Mesh.ARRAY_INDEX]
        var indexed: bool = not indices.is_empty()
        var count: int = indices.size() if indexed else vertices.size()
        for first in range(0, count - 2, 3):
            var i0: int = indices[first] if indexed else first
            var i1: int = indices[first + 1] if indexed else first + 1
            var i2: int = indices[first + 2] if indexed else first + 2
            if mini(i0, mini(i1, i2)) < 0 or maxi(i0, maxi(i1, i2)) >= vertices.size():
                continue
            var a: Vector3 = vertices[i0]
            var b: Vector3 = vertices[i1]
            var c: Vector3 = vertices[i2]
            var normal: Vector3 = (b - a).cross(c - a)
            if normal.length_squared() < 0.000000001:
                continue
            normal = normal.normalized()
            var triangle_points := PackedStringArray([
                _position_key(a), _position_key(b), _position_key(c)])
            triangle_points.sort()
            var triangle_id: String = "|".join(triangle_points)
            var duplicate_triangle: bool = triangle_seen.has(triangle_id)
            triangle_seen[triangle_id] = true
            for endpoints in [[a, b], [b, c], [c, a]]:
                var start: Vector3 = endpoints[0]
                var finish: Vector3 = endpoints[1]
                var ka: String = _position_key(start)
                var kb: String = _position_key(finish)
                if ka == kb:
                    continue
                var key: String = ka + "|" + kb if ka < kb else kb + "|" + ka
                if not by_key.has(key):
                    by_key[key] = {"a": start, "b": finish, "face_a": normal,
                        "count": 1, "duplicate_triangle": duplicate_triangle}
                else:
                    var edge: Dictionary = by_key[key]
                    edge["count"] = int(edge.get("count", 1)) + 1
                    if duplicate_triangle:
                        edge["duplicate_triangle"] = true
                    if not edge.has("face_b"):
                        edge["face_b"] = normal
                    elif edge["face_a"].dot(normal) < edge["face_a"].dot(edge["face_b"]):
                        # Non-manifold mesh: retain the most distinct neighboring face.
                        edge["face_b"] = normal
    var result: Array = []
    var crease_cosine: float = cos(deg_to_rad(CREASE_DEGREES))
    for entry in by_key.values():
        var edge: Dictionary = entry
        if edge.has("face_b"):
            var cosine: float = clampf(edge["face_a"].dot(edge["face_b"]), -1.0, 1.0)
            # Internal triangulation seams and near-coplanar faces are never inked.
            if cosine >= 0.99999:
                # An exactly duplicated triangle has the same three edges
                # twice. Its perimeter remains a silhouette, unlike a
                # coplanar triangulation seam between distinct triangles.
                # Three or more coincident edge uses remain an internal seam.
                if (not bool(edge.get("duplicate_triangle", false)) or
                        int(edge.get("count", 0)) != 2):
                    continue
            edge["crease"] = cosine <= crease_cosine + 0.000001
        else:
            edge["crease"] = false
        result.append(edge)
    return result

static func _build_overlay(mesh: Mesh) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var added: int = 0
    for edge in _extract_edges(mesh):
        if added >= MAX_EDGES_PER_MESH:
            break
        var a: Vector3 = edge["a"]
        var b: Vector3 = edge["b"]
        var tangent: Vector3 = b - a
        if tangent.length_squared() < 0.000000001:
            continue
        tangent = tangent.normalized()
        var face_a: Vector3 = edge["face_a"]
        var face_b: Vector3 = edge.get("face_b", Vector3.ZERO)
        var ink_flag: float = 1.0 if bool(edge["crease"]) else 0.0
        var color := Color(face_a.x * 0.5 + 0.5, face_a.y * 0.5 + 0.5,
            face_a.z * 0.5 + 0.5, ink_flag)
        var adjacent := Color(face_b.x, face_b.y, face_b.z,
            1.0 if edge.has("face_b") else 0.0)
        for vertex in [[a, -1.0], [b, -1.0], [b, 1.0],
                [a, -1.0], [b, 1.0], [a, 1.0]]:
            st.set_color(color)
            st.set_custom(0, adjacent)
            # NORMAL carries the edge direction; this is an unshaded overlay.
            st.set_normal(tangent)
            st.set_uv(Vector2(float(vertex[1]), 0.0))
            st.add_vertex(vertex[0])
        added += 1
    if added == 0:
        return null
    return st.commit()


# The RGB12 ID compositor owns silhouettes and inter-mesh boundaries.
# Extract only manifold hard corners from the SAME mesh. Include concave
# edges for buildings; keep small props convex-only. No open edges.
static func build_corner_edges(mesh: Mesh, include_concave: bool) -> ArrayMesh:
    if mesh == null:
        return null
    var volume: float = 0.0
    for si in range(mesh.get_surface_count()):
        var arrays: Array = mesh.surface_get_arrays(si)
        var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices := PackedInt32Array()
        if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
            indices = arrays[Mesh.ARRAY_INDEX]
        var count: int = indices.size() if not indices.is_empty() else points.size()
        for k in range(0, count - 2, 3):
            var ia: int = indices[k] if not indices.is_empty() else k
            var ib: int = indices[k + 1] if not indices.is_empty() else k + 1
            var ic: int = indices[k + 2] if not indices.is_empty() else k + 2
            if mini(ia, mini(ib, ic)) < 0 or (
                    maxi(ia, maxi(ib, ic)) >= points.size()):
                continue
            volume += points[ia].dot(points[ib].cross(points[ic])) / 6.0
    var outward_sign: float = -1.0 if volume < -0.000001 else 1.0
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var emitted: int = 0
    for edge_value in _extract_edges(mesh):
        if emitted >= MAX_EDGES_PER_MESH:
            break
        var edge: Dictionary = edge_value
        if not bool(edge.get("crease", false)) or (
                not edge.has("face_b")) or (
                int(edge.get("count", 0)) != 2) or (
                bool(edge.get("duplicate_triangle", false))):
            continue
        var start: Vector3 = edge["a"]
        var finish: Vector3 = edge["b"]
        var direction: Vector3 = finish - start
        if direction.length_squared() < 0.000000001:
            continue
        var tangent: Vector3 = direction.normalized()
        var na: Vector3 = edge["face_a"]
        var nb: Vector3 = edge["face_b"]
        var signed_corner: float = tangent.dot(na.cross(nb)) * outward_sign
        if absf(signed_corner) <= 0.00001 or (
                signed_corner < 0.0 and not include_concave):
            continue
        # Signed dihedral separates convex (+) and concave (-) corners.
        # Pass both outward normals for visibility-aware rasterization.
        var a_out: Vector3 = na * outward_sign
        var b_out: Vector3 = nb * outward_sign
        var face_a := Color(a_out.x * 0.5 + 0.5,
            a_out.y * 0.5 + 0.5, a_out.z * 0.5 + 0.5, 1.0)
        var face_b := Color(b_out.x, b_out.y, b_out.z, 1.0)
        for endpoint in [[start, -1.0], [finish, -1.0],
                [finish, 1.0], [start, -1.0],
                [finish, 1.0], [start, 1.0]]:
            st.set_color(face_a)
            st.set_custom(0, face_b)
            st.set_normal(tangent)
            st.set_uv(Vector2(float(endpoint[1]), 0.0))
            st.add_vertex(endpoint[0])
        emitted += 1
    if emitted == 0:
        return null
    return st.commit()


# Retain legacy API for convex-only small props.
static func build_convex_only(mesh: Mesh) -> ArrayMesh:
    return build_corner_edges(mesh, false)

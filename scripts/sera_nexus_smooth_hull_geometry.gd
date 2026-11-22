extends RefCounted
## NEXUS silhouette-only normal baker.
## Preserves authored topology, UVs, colors, indices, and skinning arrays.
## Source shading is never altered: only the duplicate inverted hull uses
## position-welded averaged NORMAL vectors.
const MAX_VERTICES: int = 90000
const NORMAL_EPSILON: float = 0.0001
const POSITION_GRID: float = 10000.0

static func _key(pos: Vector3) -> Vector3i:
    return Vector3i(roundi(pos.x * POSITION_GRID),
        roundi(pos.y * POSITION_GRID), roundi(pos.z * POSITION_GRID))

static func _add_direction(directions: Dictionary, position: Vector3,
        direction: Vector3) -> void:
    if direction.length_squared() <= 0.000001:
        return
    var key: Vector3i = _key(position)
    var candidates: Array = directions.get(key, [])
    var normal: Vector3 = direction.normalized()
    # Each adjacent surface contributes one DISTINCT face direction. UV
    # splits and triangulated coplanar quads must not bias the average.
    for existing in candidates:
        var candidate_normal: Vector3 = existing
        if candidate_normal.dot(normal) >= 1.0 - NORMAL_EPSILON:
            return
    candidates.append(normal)
    directions[key] = candidates

static func build(source_mesh: Mesh) -> ArrayMesh:
    if source_mesh == null or source_mesh.get_surface_count() == 0:
        return null
    # Blend shape vertex deformation needs identical shape data on both
    # copies. This builder intentionally does not silently drop it.
    if source_mesh.get_blend_shape_count() > 0:
        return null
    var surfaces: Array = []
    var directions: Dictionary = {}
    var count: int = 0
    for surf in range(source_mesh.get_surface_count()):
        if source_mesh is ArrayMesh and (
                (source_mesh as ArrayMesh).surface_get_primitive_type(surf)
                != Mesh.PRIMITIVE_TRIANGLES):
            return null
        var data: Array = source_mesh.surface_get_arrays(surf)
        var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
        if verts.is_empty():
            continue
        count += verts.size()
        if count > MAX_VERTICES:
            return null
        var normals := PackedVector3Array()
        if data[Mesh.ARRAY_NORMAL] is PackedVector3Array:
            normals = data[Mesh.ARRAY_NORMAL]
        if normals.size() == verts.size():
            for index in range(verts.size()):
                _add_direction(directions, verts[index], normals[index])
        else:
            # Fallback for unlit or procedural triangle meshes without
            # authored normals. Winding follows the engine's vertex order.
            var indices := PackedInt32Array()
            if data[Mesh.ARRAY_INDEX] is PackedInt32Array:
                indices = data[Mesh.ARRAY_INDEX]
            var indexed: bool = not indices.is_empty()
            var vertex_count: int = indices.size() if indexed else verts.size()
            for t in range(0, vertex_count - 2, 3):
                var ia: int = indices[t] if indexed else t
                var ib: int = indices[t + 1] if indexed else t + 1
                var ic: int = indices[t + 2] if indexed else t + 2
                if mini(ia, mini(ib, ic)) < 0 or (
                        maxi(ia, maxi(ib, ic)) >= verts.size()):
                    continue
                var face: Vector3 = (
                    verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
                for id in [ia, ib, ic]:
                    _add_direction(directions, verts[id], face)
        surfaces.append(data)
    if surfaces.is_empty():
        return null
    var averaged: Dictionary = {}
    for key in directions.keys():
        var normal: Vector3 = Vector3.ZERO
        for direction in directions[key]:
            normal += direction
        if normal.length_squared() >= 0.000001:
            averaged[key] = normal.normalized()
    if averaged.is_empty():
        return null
    var hull := ArrayMesh.new()
    for data in surfaces:
        var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
        var old_normals := PackedVector3Array()
        if data[Mesh.ARRAY_NORMAL] is PackedVector3Array:
            old_normals = data[Mesh.ARRAY_NORMAL]
        var smoothed := PackedVector3Array()
        smoothed.resize(points.size())
        for index in range(points.size()):
            var fallback: Vector3 = (old_normals[index]
                if old_normals.size() == points.size() else Vector3.UP)
            smoothed[index] = averaged.get(_key(points[index]), fallback)
        # Duplicate only the surface arrays. Keep all other source channels,
        # including bone indices/weights for skinned parts.
        var clone: Array = data.duplicate(true)
        clone[Mesh.ARRAY_NORMAL] = smoothed
        hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clone)
    return hull

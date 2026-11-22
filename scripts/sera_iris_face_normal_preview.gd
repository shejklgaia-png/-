extends RefCounted
## NEXUS HEAD D preview ONLY. Merge the two triangle normals belonging to
## each authored Blockbench quad WITHOUT moving vertices, changing UVs or
## touching the shared equipment mesh. No new draw pass is required.
const FACE_CULLING = preload("res://scripts/sera_face_culling.gd")
const IRIS_EMBEDDED = preload("res://assets/sera_camera_eye_head_data.gd")
const LIVE_SOURCE: String = "res://models/storage/カメラアイ頭部.bbmodel"
const UNIT: float = 0.065
const MIN_TRIANGLE_LENGTH_SQUARED: float = 0.000000001


static func authored_elements() -> Array:
    # Follow sera_equipment.gd: prefer the authoring source when present,
    # otherwise use the embedded Android snapshot containing the same faces.
    var model: Variant = null
    if FileAccess.file_exists(LIVE_SOURCE):
        model = JSON.parse_string(FileAccess.get_file_as_string(LIVE_SOURCE))
    if not (model is Dictionary) or (model as Dictionary).get(
            "elements", []).is_empty() or (model as Dictionary).get(
            "textures", []).is_empty():
        model = JSON.parse_string(IRIS_EMBEDDED.get_json())
    if model is Dictionary:
        return (model as Dictionary).get("elements", [])
    return []


static func _authored_face_triangle_groups(element: Dictionary) -> Array[int]:
    # Replicate only SeraRig._make_mesh's face iteration and zero-area
    # filtering. Its SurfaceTool writes independent, unindexed triangles in
    # this order. The original winding is retained for the actual mesh.
    var vertex_map: Dictionary = element.get("vertices", {})
    var faces: Dictionary = element.get("faces", {})
    var reverse_faces: Dictionary = FACE_CULLING.inspect_element(
        element).get("reverse_faces", {})
    var groups: Array[int] = []
    for face_id in faces.keys():
        var face: Dictionary = faces[face_id]
        var points: Array[Vector3] = []
        for key in face.get("vertices", []):
            if not vertex_map.has(key):
                continue
            var raw: Array = vertex_map[key]
            if raw.size() < 3:
                continue
            points.append(Vector3(float(raw[0]), float(raw[1]),
                float(raw[2])) * UNIT)
        if points.size() < 3:
            continue
        if (points[1] - points[0]).cross(points[2] - points[0]
                ).length_squared() < MIN_TRIANGLE_LENGTH_SQUARED:
            continue
        if bool(reverse_faces.get(face_id, false)):
            points.reverse()
        var triangles: int = 0
        for i in range(1, points.size() - 1):
            var area_vector: Vector3 = (points[i] - points[0]).cross(
                points[i + 1] - points[0])
            if area_vector.length_squared() >= MIN_TRIANGLE_LENGTH_SQUARED:
                triangles += 1
        if triangles > 0:
            groups.append(triangles)
    return groups


static func make_face_uniform_mesh(source_mesh: Mesh,
        element: Dictionary) -> ArrayMesh:
    if source_mesh == null or source_mesh.get_surface_count() != 1 or (
            source_mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES):
        return null
    var arrays: Array = source_mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var original_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    if vertices.is_empty() or original_normals.size() != vertices.size():
        return null
    # A different mesh revision or an indexed topology must fail closed.
    var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
    if index_data is PackedInt32Array and index_data.size() > 0:
        return null
    var groups: Array[int] = _authored_face_triangle_groups(element)
    var expected_count: int = 0
    for count in groups:
        expected_count += count * 3
    if expected_count != vertices.size():
        return null
    var shared_normals: PackedVector3Array = original_normals.duplicate()
    var offset: int = 0
    for count in groups:
        # Weighted mean of the two (or more) triangle area-vectors produces
        # ONE uniform normal for the authored face, even when its corners
        # are slightly non-coplanar. Different authored faces remain distinct.
        var aggregate: Vector3 = Vector3.ZERO
        for triangle in range(count):
            var start: int = offset + triangle * 3
            aggregate += (vertices[start + 1] - vertices[start]).cross(
                vertices[start + 2] - vertices[start])
        var face_normal: Vector3 = original_normals[offset]
        if aggregate.length_squared() > MIN_TRIANGLE_LENGTH_SQUARED:
            face_normal = aggregate.normalized()
        for k in range(count * 3):
            shared_normals[offset + k] = face_normal
        offset += count * 3
    arrays[Mesh.ARRAY_NORMAL] = shared_normals
    var surface := ArrayMesh.new()
    surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    if source_mesh.surface_get_material(0) != null:
        surface.surface_set_material(0, source_mesh.surface_get_material(0))
    return surface

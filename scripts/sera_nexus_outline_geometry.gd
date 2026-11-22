extends RefCounted
## NEXUS-only line ribbons with capped projected endpoints.
## Reuse BASE's topology extraction, but keep BASE facility rendering untouched.
const BaseTopology = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const MAX_EDGES_PER_MESH: int = 8000

static func build(mesh: Mesh) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var count: int = 0
    for value in BaseTopology._extract_edges(mesh):
        if count >= MAX_EDGES_PER_MESH:
            break
        var entry: Dictionary = value
        var a: Vector3 = entry["a"]
        var b: Vector3 = entry["b"]
        var tangent: Vector3 = b - a
        if tangent.length_squared() < 0.000000001:
            continue
        tangent = tangent.normalized()
        var first: Vector3 = entry["face_a"]
        var second: Vector3 = entry.get("face_b", Vector3.ZERO)
        var face_color := Color(
            first.x * 0.5 + 0.5,
            first.y * 0.5 + 0.5,
            first.z * 0.5 + 0.5, 0.0)
        var adjacent := Color(second.x, second.y, second.z,
            1.0 if entry.has("face_b") else 0.0)
        # UV.x is +/- stroke width direction, UV.y is +/- endpoint cap.
        # The extra projected cap closes pinholes at adjacent edges without
        # modifying the source mesh or adding a second camera.
        for vertex in [[a, -1.0, -1.0], [b, -1.0, 1.0],
                [b, 1.0, 1.0], [a, -1.0, -1.0],
                [b, 1.0, 1.0], [a, 1.0, -1.0]]:
            surface.set_normal(tangent)
            surface.set_color(face_color)
            surface.set_custom(0, adjacent)
            surface.set_uv(Vector2(float(vertex[1]), float(vertex[2])))
            surface.add_vertex(vertex[0])
        count += 1
    if count == 0:
        return null
    return surface.commit()

extends RefCounted
## NEXUS-only line ribbons with capped projected endpoints.
## Reuse BASE's topology extraction, but keep BASE facility rendering untouched.
const BaseTopology = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const MAX_EDGES_PER_MESH: int = 8000

static func build(mesh: Mesh) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    # One mesh-local midpoint per edge. It is identical at all six ribbon
    # vertices, preventing one half of an edge from changing visibility while
    # the other half survives the camera-facing test.
    surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
    # The first face normal must NOT use COLOR (8-bit normalized).
    # CUSTOM2 holds it as full-precision float, plus the convex corner flag.
    # Keep COLOR populated for older diagnostic shaders only.
    surface.set_custom_format(2, SurfaceTool.CUSTOM_RGBA_FLOAT)
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
        var midpoint: Vector3 = (a + b) * 0.5
        var edge_center := Color(midpoint.x, midpoint.y, midpoint.z, 0.0)
        # For the canonical Blockbench outward winding, the signed turn
        # of two adjacent faces around the first face's directed edge is
        # positive at convex armor corners and negative at recesses.
        # Only pronounced corners may receive the thin visible crease.
        var convex_crease: bool = false
        if entry.has("face_b") and bool(entry.get("crease", false)):
            convex_crease = first.cross(second).dot(tangent) > 0.01
        var face_a_precise := Color(first.x, first.y, first.z,
            1.0 if convex_crease else 0.0)
        # UV.x is +/- stroke width direction, UV.y is +/- endpoint cap.
        # The extra projected cap closes pinholes at adjacent edges without
        # modifying the source mesh or adding a second camera.
        for vertex in [[a, -1.0, -1.0], [b, -1.0, 1.0],
                [b, 1.0, 1.0], [a, -1.0, -1.0],
                [b, 1.0, 1.0], [a, 1.0, -1.0]]:
            surface.set_normal(tangent)
            surface.set_color(face_color)
            surface.set_custom(0, adjacent)
            surface.set_custom(1, edge_center)
            surface.set_custom(2, face_a_precise)
            surface.set_uv(Vector2(float(vertex[1]), float(vertex[2])))
            surface.add_vertex(vertex[0])
        count += 1
    if count == 0:
        return null
    return surface.commit()

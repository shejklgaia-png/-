extends RefCounted
## Two intentionally separate ink paths:
## (1) 6px contour uses the CURRENT actor SERA inverted backface hull, not
##     the obsolete front/back edge ribbons.
## (2) 2px camera-facing sharp corners keep the old BASE ribbon shader.
## Both are bound only to actual solid part MultiMesh instances, never VFX.
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
const SERA_SILHOUETTE_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const BASE_CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")

static var _silhouette_cache: Dictionary = {}
static var _crease_cache: Dictionary = {}
static var _silhouette_material: ShaderMaterial
static var _crease_material: ShaderMaterial

static func silhouette_overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _silhouette_cache.has(geometry):
        return _silhouette_cache[geometry] as ArrayMesh
    # Latest SERA: world-space face normals welded by quantized vertex
    # position, converted once into a smooth-normal inverted hull.
    var ink: ArrayMesh = SeraViewEdges._build_overlay(physical_mesh)
    _silhouette_cache[geometry] = ink
    return ink

static func silhouette_material() -> ShaderMaterial:
    if _silhouette_material == null:
        _silhouette_material = ShaderMaterial.new()
        _silhouette_material.shader = SERA_SILHOUETTE_SHADER
        _silhouette_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        # BASE keeps its approved stronger width and color. SERA character
        # material remains 3px #17212f; only BASE overrides the uniforms.
        _silhouette_material.set_shader_parameter("ink_color", Color("#55798A"))
        _silhouette_material.set_shader_parameter("stroke_px", 6.0)
    return _silhouette_material

static func _key(p: Vector3) -> String:
    return SeraViewEdges._position_key(p)

static func _undirected_edge(a: Vector3, b: Vector3) -> String:
    var first: String = _key(a)
    var second: String = _key(b)
    return (first + "|" + second) if first < second else (
        second + "|" + first)

static func crease_overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _crease_cache.has(geometry):
        return _crease_cache[geometry] as ArrayMesh
    # Preserve old BASE front/front 80-degree corner policy. The latest actor
    # SERA no longer emits ribbons, so this separate outline must derive its
    # own adjacent triangle pairs from the unchanged physical mesh.
    var edge_uses: Dictionary = {}
    for surface in range(physical_mesh.get_surface_count()):
        if physical_mesh is ArrayMesh and (
                (physical_mesh as ArrayMesh).surface_get_primitive_type(surface)
                != Mesh.PRIMITIVE_TRIANGLES):
            continue
        var arrays: Array = physical_mesh.surface_get_arrays(surface)
        var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if positions.is_empty():
            continue
        var indices := PackedInt32Array()
        if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
            indices = arrays[Mesh.ARRAY_INDEX]
        var indexed: bool = not indices.is_empty()
        var count: int = indices.size() if indexed else positions.size()
        for offset in range(0, count - 2, 3):
            var i0: int = indices[offset] if indexed else offset
            var i1: int = indices[offset + 1] if indexed else offset + 1
            var i2: int = indices[offset + 2] if indexed else offset + 2
            if mini(i0, mini(i1, i2)) < 0 or (
                    maxi(i0, maxi(i1, i2)) >= positions.size()):
                continue
            var a: Vector3 = positions[i0]
            var b: Vector3 = positions[i1]
            var c: Vector3 = positions[i2]
            var normal: Vector3 = (b - a).cross(c - a)
            if normal.length_squared() < 0.000000001:
                continue
            normal = normal.normalized()
            for segment in [[a, b], [b, c], [c, a]]:
                var start: Vector3 = segment[0]
                var finish: Vector3 = segment[1]
                var edge: String = _undirected_edge(start, finish)
                if not edge_uses.has(edge):
                    edge_uses[edge] = []
                (edge_uses[edge] as Array).append({
                    "a": start, "b": finish, "normal": normal})
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    builder.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var added: int = 0
    var crease_cosine: float = cos(deg_to_rad(80.0))
    for uses_variant in edge_uses.values():
        var uses: Array = uses_variant
        if uses.size() < 2:
            continue
        var best_dot: float = 1.0
        var normal_a: Vector3 = Vector3.ZERO
        var normal_b: Vector3 = Vector3.ZERO
        for i in range(uses.size()):
            var first: Dictionary = uses[i]
            for j in range(i + 1, uses.size()):
                var next: Dictionary = uses[j]
                var fa: Vector3 = first["normal"]
                var fb: Vector3 = next["normal"]
                var cosine: float = fa.dot(fb)
                if cosine < best_dot:
                    best_dot = cosine
                    normal_a = fa
                    normal_b = fb
        # No lines on coplanar triangulation seams or nearly flat corners.
        if best_dot > crease_cosine or (
                normal_a == Vector3.ZERO or normal_b == Vector3.ZERO):
            continue
        var edge_record: Dictionary = uses[0]
        var a: Vector3 = edge_record["a"]
        var b: Vector3 = edge_record["b"]
        var tangent: Vector3 = b - a
        if tangent.length_squared() < 0.000000001:
            continue
        tangent = tangent.normalized()
        var face_color := Color(
            normal_a.x * 0.5 + 0.5,
            normal_a.y * 0.5 + 0.5,
            normal_a.z * 0.5 + 0.5, 1.0)
        var neighbor := Color(normal_b.x, normal_b.y, normal_b.z, 1.0)
        for vertex in [[a, -1.0], [b, -1.0], [b, 1.0],
                [a, -1.0], [b, 1.0], [a, 1.0]]:
            builder.set_color(face_color)
            builder.set_custom(0, neighbor)
            builder.set_normal(tangent)
            builder.set_uv(Vector2(float(vertex[1]), 0.0))
            builder.add_vertex(vertex[0])
        added += 1
    var creases: ArrayMesh = null
    if added > 0:
        creases = builder.commit()
    _crease_cache[geometry] = creases
    return creases

static func crease_material() -> ShaderMaterial:
    if _crease_material == null:
        _crease_material = ShaderMaterial.new()
        _crease_material.shader = BASE_CREASE_SHADER
        _crease_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _crease_material.set_shader_parameter("ink_color", Color("#55798A"))
        _crease_material.set_shader_parameter("crease_px", 2.0)
        _crease_material.set_shader_parameter("crease_only", true)
    return _crease_material

# This compatibility entry still returns only the latest SERA silhouette.
static func overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    return silhouette_overlay_for(geometry, physical_mesh)

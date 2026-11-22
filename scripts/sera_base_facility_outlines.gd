extends RefCounted
## GPU geometry ink shared with SERA: the same real triangle adjacency and
## camera-facing normals, not screen-projected AABB or global convex hull.
## The underlying solid MultiMesh batches remain untouched.
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
const BASE_INK_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")

static var _geometry_cache: Dictionary = {}
static var _shared_material: ShaderMaterial

static func overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _geometry_cache.has(geometry):
        return _geometry_cache[geometry] as ArrayMesh
    # Reuse SERA's 80-degree classification, duplicated-face filtering,
    # triangulation-seam removal and six-vertex edge ribbon generation.
    var ink: ArrayMesh = SeraViewEdges._build_overlay(physical_mesh)
    _geometry_cache[geometry] = ink
    return ink

static func material() -> ShaderMaterial:
    if _shared_material == null:
        _shared_material = ShaderMaterial.new()
        _shared_material.shader = BASE_INK_SHADER
        _shared_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _shared_material.set_shader_parameter("ink_color", Color("#55798A"))
        _shared_material.set_shader_parameter("silhouette_px", 6.0)
        _shared_material.set_shader_parameter("crease_px", 2.0)
    return _shared_material

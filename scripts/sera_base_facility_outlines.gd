extends RefCounted
## BASE silhouettes use the *live* SERA inverted-hull shader and its CPU
## smoothed-normal geometry, with a BASE-specific 6px blue-grey material.
## Only the independent 2px near-camera hard creases retain the historical
## view-edge ribbon pass. No FX, lights, floor reflection or smoke are inked.
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
const BaseFacilityCreaseGeometry = preload(
    "res://scripts/sera_base_facility_crease_geometry.gd")
const SERA_INVERTED_HULL_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const BASE_CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")

static var _silhouette_cache: Dictionary = {}
static var _crease_cache: Dictionary = {}
static var _shared_silhouette_material: ShaderMaterial
static var _shared_crease_material: ShaderMaterial

static func overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _silhouette_cache.has(geometry):
        return _silhouette_cache[geometry] as ArrayMesh
    # This intentionally calls the latest SERA builder directly.  Its welded
    # normal inverted hull eliminates interior angled-face ink entirely.
    var ink: ArrayMesh = SeraViewEdges._build_overlay(physical_mesh)
    _silhouette_cache[geometry] = ink
    return ink

static func crease_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _crease_cache.has(geometry):
        return _crease_cache[geometry] as ArrayMesh
    # Unmodified 80deg old crease extraction: camera-facing front/front
    # junctions only, as requested. Independent of the new outer contour.
    var ink: ArrayMesh = BaseFacilityCreaseGeometry._build_overlay(physical_mesh)
    _crease_cache[geometry] = ink
    return ink

static func material() -> ShaderMaterial:
    if _shared_silhouette_material == null:
        _shared_silhouette_material = ShaderMaterial.new()
        _shared_silhouette_material.shader = SERA_INVERTED_HULL_SHADER
        _shared_silhouette_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _shared_silhouette_material.set_shader_parameter(
            "ink_color", Color("#000000"))
        _shared_silhouette_material.set_shader_parameter("stroke_px", 6.0)
    return _shared_silhouette_material

static func crease_material() -> ShaderMaterial:
    if _shared_crease_material == null:
        _shared_crease_material = ShaderMaterial.new()
        _shared_crease_material.shader = BASE_CREASE_SHADER
        _shared_crease_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _shared_crease_material.set_shader_parameter(
            "ink_color", Color("#353535"))
        _shared_crease_material.set_shader_parameter("crease_px", 2.0)
    return _shared_crease_material

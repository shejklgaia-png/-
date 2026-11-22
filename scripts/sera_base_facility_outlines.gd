extends RefCounted
## BASE uses physical mesh contour ribbons to avoid inverted-hull full-face
## overdraw and depth-mask disappearance on Android GL Compatibility.
## Black 4px camera-facing silhouette and #202020 2px visible hard creases
## share edge geometry but have separate material passes. FX is excluded.
const BaseFacilityCreaseGeometry = preload(
    "res://scripts/sera_base_facility_crease_geometry.gd")
const BASE_SILHOUETTE_SHADER = preload("res://shaders/base_facility_silhouette_edges.gdshader")
const BASE_CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")

static var _silhouette_cache: Dictionary = {}
static var _crease_cache: Dictionary = {}
static var _shared_silhouette_material: ShaderMaterial
static var _shared_crease_material: ShaderMaterial

static func overlay_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _silhouette_cache.has(geometry):
        return _silhouette_cache[geometry] as ArrayMesh
    # Two passes consume the SAME topological edge geometry (face A/B,
    # boundary flag and screen-space tangent). No filled inverted-hull
    # triangles may reach the BASE material: masked triangles vanished,
    # unmasked triangles painted entire buildings magenta on Android.
    var ink: ArrayMesh = BaseFacilityCreaseGeometry._build_overlay(physical_mesh)
    _silhouette_cache[geometry] = ink
    _crease_cache[geometry] = ink
    return ink

static func crease_for(geometry: String, physical_mesh: Mesh) -> ArrayMesh:
    if _crease_cache.has(geometry):
        return _crease_cache[geometry] as ArrayMesh
    # Reuse the exact same edge mesh as the camera-dependent silhouette.
    # The 2px shader selects only front/front >=80 degree hard creases.
    var ink: ArrayMesh = overlay_for(geometry, physical_mesh)
    _crease_cache[geometry] = ink
    return ink

static func material() -> ShaderMaterial:
    if _shared_silhouette_material == null:
        _shared_silhouette_material = ShaderMaterial.new()
        _shared_silhouette_material.shader = BASE_SILHOUETTE_SHADER
        _shared_silhouette_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _shared_silhouette_material.set_shader_parameter(
            "ink_color", Color("#000000"))
        _shared_silhouette_material.set_shader_parameter("stroke_px", 4.0)
    return _shared_silhouette_material

static func crease_material() -> ShaderMaterial:
    if _shared_crease_material == null:
        _shared_crease_material = ShaderMaterial.new()
        _shared_crease_material.shader = BASE_CREASE_SHADER
        _shared_crease_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        _shared_crease_material.set_shader_parameter(
            "ink_color", Color("#202020"))
        _shared_crease_material.set_shader_parameter("crease_px", 2.0)
    return _shared_crease_material

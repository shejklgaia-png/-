extends Node3D
## Lightweight per-MeshInstance visible-silhouette ink (inverted hull).
## The original triangles and averaged outward normals are cached per Mesh.
## GPU expansion is a constant screen-space 3px; no interior polygon edges.
const SCAN_INTERVAL: float = 0.75
const MAX_TRIANGLES_PER_MESH: int = 30000
const INK_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const INK_NAME: String = "SeraEdgeInk"

var _scan_remaining: float = 0.0
var _mesh_cache: Dictionary = {}
var _ink_material: ShaderMaterial

func _ready() -> void:
    _ink_material = ShaderMaterial.new()
    _ink_material.shader = INK_SHADER
    # Inverted rear hull runs after opaque armor; depth testing stays enabled.
    _ink_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    _ink_material.set_shader_parameter("ink_color", Color("#17212f"))
    _ink_material.set_shader_parameter("stroke_px", 3.0)
    _sync_meshes()
    set_process(true)

func _process(delta: float) -> void:
    # Equipment may install/swap MeshInstances after the actor's _ready.
    # No per-frame CPU mesh projection, edge extraction or silhouette rebuild,
    # or material mutation occurs between these infrequent topology scans.
    _scan_remaining -= delta
    if _scan_remaining <= 0.0:
        _scan_remaining = SCAN_INTERVAL
        _sync_meshes()

func _sync_meshes() -> void:
    var actor: Node = get_parent()
    if actor == null:
        return
    # The training target controller is parented directly to its core mesh.
    if actor is MeshInstance3D:
        _attach(actor as MeshInstance3D)
    var pending: Array[Node] = [actor]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        for child in node.get_children():
            if child == self or child.name == INK_NAME:
                continue
            if child is MeshInstance3D:
                _attach(child as MeshInstance3D)
            pending.append(child)

func _attach(source: MeshInstance3D) -> void:
    if source.mesh == null or not _is_eligible(source):
        # Effects can be created, retagged or assigned a transparent FX
        # material after the previous 0.75-second topology scan.
        _remove_overlay(source)
        return
    var old: MeshInstance3D = source.get_node_or_null(INK_NAME) as MeshInstance3D
    var mesh_id: int = source.mesh.get_instance_id()
    if old != null and int(old.get_meta("edge_source_mesh_id", -1)) == mesh_id:
        return
    if old != null:
        source.remove_child(old)
        old.queue_free()
    var ink: ArrayMesh = _mesh_cache.get(mesh_id)
    if not _mesh_cache.has(mesh_id):
        ink = _build_overlay(source.mesh)
        _mesh_cache[mesh_id] = ink
    if ink == null:
        return
    var instance := MeshInstance3D.new()
    instance.name = INK_NAME
    instance.mesh = ink
    instance.material_override = _ink_material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    instance.extra_cull_margin = 0.10
    instance.set_meta("edge_source_mesh_id", mesh_id)
    source.add_child(instance)
    # Inherits animation, joint transforms, equipment swaps, and visibility.
    # Face interiors are occluded by their own opaque source geometry.

func _remove_overlay(source: MeshInstance3D) -> void:
    var old: MeshInstance3D = source.get_node_or_null(INK_NAME) as MeshInstance3D
    if old != null:
        source.remove_child(old)
        old.queue_free()


static func _is_fx_node(node: Node) -> bool:
    # Explicitly mark effect subtrees, even when the individual mesh has
    # an opaque material and an arbitrary name such as "Arc" or "Cube".
    if bool(node.get_meta("sera_no_view_edges", false)) or (
            node.is_in_group("sera_no_view_edges")):
        return true
    var label: String = str(node.name).to_lower()
    for forbidden in ["swordeffect", "afterimage", "ghost", "trail",
            "particle", "flame", "shockwave", "glow", "flash", "beam",
            "slash", "effect", "exhaust", "spark", "smoke", "radiance",
            "projectile", "debris", "blast"]:
        if label.contains(forbidden):
            return true
    return label.begins_with("fx_") or label.ends_with("_fx") or (
        label.contains("_vfx"))


static func _is_transient_material(material: Material) -> bool:
    if material == null:
        return false
    if material is BaseMaterial3D:
        var solid_or_fx: BaseMaterial3D = material
        return solid_or_fx.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (
            solid_or_fx.no_depth_test) or (
            solid_or_fx.blend_mode == BaseMaterial3D.BLEND_MODE_ADD)
    if material is ShaderMaterial:
        var shaded: ShaderMaterial = material
        if shaded.shader != null:
            # Character armor can have its own opaque ShaderMaterial; do not
            # reject shaders indiscriminately. Only transparent FX passes.
            var code: String = shaded.shader.code
            return code.contains("ALPHA") or code.contains("blend_add") or (
                code.contains("depth_test_disabled"))
    return false


static func _is_eligible(source: MeshInstance3D) -> bool:
    if source.mesh == null or source.mesh is QuadMesh or source.mesh is PlaneMesh:
        return false
    # A sword slash has a Slash-named parent but a neutral child mesh name
    # (AlphaClippedMainArc / ConvexTwoSided3DArc). Check ALL ancestors.
    var ancestor: Node = source
    while ancestor != null:
        if _is_fx_node(ancestor):
            return false
        ancestor = ancestor.get_parent()
    # Transparent/alpha-blended shader geometry must not be treated as
    # opaque character armor even when the FX node names are generic.
    if _is_transient_material(source.material_override):
        return false
    for surface in range(source.mesh.get_surface_count()):
        if _is_transient_material(source.get_active_material(surface)):
            return false
    return true

static func _position_key(p: Vector3) -> String:
    # Blockbench triangulates UV seams with separate, coincident vertices.
    return "%d:%d:%d" % [roundi(p.x * 10000.0),
        roundi(p.y * 10000.0), roundi(p.z * 10000.0)]

static func _build_overlay(mesh: Mesh) -> ArrayMesh:
    # The previous edge ribbons selected front/back polygon transitions even
    # inside steeply angled visible surfaces. Draw no edge primitives at all.
    # Instead, the shader draws the enlarged BACK faces of each source mesh.
    # Opaque front faces cover their interior; only the visible mesh contour
    # can survive the depth test. Independent MeshInstances retain their seams.
    var triangle_vertices := PackedVector3Array()
    var triangle_normals := PackedVector3Array()
    var normal_sum: Dictionary = {}
    var triangle_count: int = 0
    for surface in range(mesh.get_surface_count()):
        if mesh is ArrayMesh and (
                (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES):
            continue
        var arrays: Array = mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if vertices.is_empty():
            continue
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
            var face_normal: Vector3 = (b - a).cross(c - a)
            if face_normal.length_squared() < 0.000000001:
                continue
            # Do not return a partly inked mesh (a broken silhouette).
            if triangle_count >= MAX_TRIANGLES_PER_MESH:
                return null
            triangle_count += 1
            var unit_normal: Vector3 = face_normal.normalized()
            for p in [a, b, c]:
                triangle_vertices.append(p)
                triangle_normals.append(unit_normal)
                var key: String = _position_key(p)
                normal_sum[key] = normal_sum.get(key, Vector3.ZERO) + face_normal

    if triangle_count == 0:
        return null
    # Weld only the normals at coincident positions; do not change the source
    # geometry, UVs, hard/flat shading or actual opaque material.
    # Area weighting prevents triangulation diagonals becoming false ridges.
    var vertex_normals := PackedVector3Array()
    for i in range(triangle_vertices.size()):
        var key: String = _position_key(triangle_vertices[i])
        var smooth: Vector3 = normal_sum.get(key, triangle_normals[i])
        if smooth.length_squared() < 0.000000001:
            smooth = triangle_normals[i]
        vertex_normals.append(smooth.normalized())
    var surface_arrays: Array = []
    surface_arrays.resize(Mesh.ARRAY_MAX)
    surface_arrays[Mesh.ARRAY_VERTEX] = triangle_vertices
    surface_arrays[Mesh.ARRAY_NORMAL] = vertex_normals
    var inverted_hull := ArrayMesh.new()
    inverted_hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
    return inverted_hull

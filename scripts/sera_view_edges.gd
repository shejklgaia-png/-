extends Node3D
## Low-cost, camera-dependent hard-edge and silhouette ink for GL Compatibility.
## Topology is computed only when a Mesh resource is first encountered.
## The shader decides edge visibility and pixel width on the GPU every frame.
const CREASE_DEGREES: float = 80.0
const SCAN_INTERVAL: float = 0.75
const MAX_EDGES_PER_MESH: int = 8000
const INK_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const INK_NAME: String = "SeraEdgeInk"

var _scan_remaining: float = 0.0
var _mesh_cache: Dictionary = {}
var _ink_material: ShaderMaterial

func _ready() -> void:
    _ink_material = ShaderMaterial.new()
    _ink_material.shader = INK_SHADER
    # Transparent pass runs after opaque armor; depth testing remains enabled.
    _ink_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    _ink_material.set_shader_parameter("ink_color", Color("#17212f"))
    _ink_material.set_shader_parameter("stroke_px", 3.0)
    _sync_meshes()
    set_process(true)

func _process(delta: float) -> void:
    # Equipment may install/swap MeshInstances after the actor's _ready.
    # No per-frame CPU traversal, vertex projection, edge reconstruction,
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
    # Same local geometry and ancestor transforms: joint rotations, IK and
    # equipment visibility are inherited without copying or repainting data.

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

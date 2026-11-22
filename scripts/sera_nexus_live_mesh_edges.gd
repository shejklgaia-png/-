extends Node3D
## NEXUS full-body SERA outline: camera-facing GPU edge ribbons in the SAME
## 3D viewport as the source meshes. Every ribbon is a child of its original
## MeshInstance3D, so bone animation, preview rotation and scale use the same
## scene transforms and rendering frame without any ID-camera synchronization.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const RenderOrder = preload("res://scripts/render_order_policy.gd")
const EDGE_SHADER = preload("res://shaders/sera_live_mesh_edges.gdshader")
const ContactSeams = preload("res://scripts/sera_nexus_contact_seams.gd")
const RESCAN_SECONDS: float = 0.35
const WELD_GRID: float = 10000.0
const MAX_TRIANGLES_PER_MESH: int = 12000
const MAX_EDGES_PER_MESH: int = 40000
const COPLANAR_DOT: float = 0.995

var _source_root: Node3D
var _edge_material: ShaderMaterial
var _edge_links: Dictionary = {} # source ID -> {source, mesh, draw}
var _geometry_cache: Dictionary = {} # Mesh resource instance ID -> ArrayMesh/null
var _contact_links: Dictionary = {} # mesh ID -> depth-tested contact ribbons
var _last_contact_signature: String = ""
var _rescan_elapsed: float = 0.0

func configure(rig: Node3D) -> void:
    _source_root = rig

func _ready() -> void:
    name = "SeraLiveMeshEdges"
    set_meta("sera_generated_live_edge", true)
    set_meta("FX_NO_OUTLINE", true)
    _edge_material = ShaderMaterial.new()
    _edge_material.shader = EDGE_SHADER
    _edge_material.render_priority = RenderOrder.NEXUS_SURFACE_EDGES
    _edge_material.set_shader_parameter("ink_color", Color("#17212f"))
    _edge_material.set_shader_parameter("silhouette_px", 4.0)
    _edge_material.set_shader_parameter("boundary_px", 3.0)
    visible = GraphicsSettings.get_enabled("character_outline")
    if visible:
        _refresh_meshes()
    set_process(true)

func _process(delta: float) -> void:
    _rescan_elapsed -= delta
    if _rescan_elapsed > 0.0:
        return
    _rescan_elapsed = RESCAN_SECONDS
    var enabled: bool = GraphicsSettings.get_enabled("character_outline")
    if visible != enabled:
        visible = enabled
        # The draw nodes live under the original meshes, NOT under this
        # controller, so changing this controller's visibility alone would
        # not hide any ribbons.
        for record in _edge_links.values():
            var draw: MeshInstance3D = record.get("draw") as MeshInstance3D
            if is_instance_valid(draw):
                draw.visible = enabled
        for contact in _contact_links.values():
            if is_instance_valid(contact):
                (contact as MeshInstance3D).visible = enabled
    if enabled:
        _refresh_meshes()

func _refresh_meshes() -> void:
    if not is_instance_valid(_source_root):
        return
    var found: Dictionary = {}
    var pending: Array[Node] = [_source_root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node == self or bool(node.get_meta(
                "sera_generated_live_edge", false)):
            continue
        var label: String = str(node.name).to_lower()
        if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
                bool(node.get_meta("sera_no_view_edges", false))) or (
                label.contains("swordeffect") or label.contains("afterimage")
                or label.contains("ghost") or label.contains("beam")
                or label.contains("trail") or label.contains("particle")
                or label.contains("smoke") or label.contains("glow")):
            continue
        if node is MeshInstance3D:
            var part: MeshInstance3D = node as MeshInstance3D
            if part.mesh != null and not (part.mesh is QuadMesh) and (
                    not (part.mesh is PlaneMesh)):
                found[part.get_instance_id()] = part
        for child in node.get_children():
            if child is Node3D:
                pending.append(child)
    for key in _edge_links.keys():
        if found.has(key):
            continue
        var gone: Dictionary = _edge_links[key]
        var old_draw: MeshInstance3D = gone.get("draw") as MeshInstance3D
        if is_instance_valid(old_draw):
            old_draw.queue_free()
        _edge_links.erase(key)
    for key in found.keys():
        var source: MeshInstance3D = found[key] as MeshInstance3D
        var record: Dictionary = _edge_links.get(key, {})
        var current_draw: MeshInstance3D = (
            record.get("draw") as MeshInstance3D)
        if record.get("mesh") == source.mesh and (
                current_draw == null or is_instance_valid(current_draw)):
            # A null draw is valid: degenerate or overly large meshes are
            # remembered and not repeatedly rebuilt every 0.35 seconds.
            if is_instance_valid(current_draw):
                current_draw.layers = source.layers
            continue
        if is_instance_valid(current_draw):
            current_draw.queue_free()
        var ribbons: ArrayMesh = _edge_geometry(source.mesh)
        var draw: MeshInstance3D = null
        if ribbons != null:
            draw = MeshInstance3D.new()
            draw.name = "SeraGPUOutline_%d" % key
            draw.set_meta("sera_generated_live_edge", true)
            draw.set_meta("FX_NO_OUTLINE", true)
            draw.mesh = ribbons
            draw.material_override = _edge_material
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            draw.layers = source.layers
            draw.extra_cull_margin = 1.0
            # Child of the original source, never a copy in an independent
            # World3D: all authored bone transforms are inherited immediately.
            source.add_child(draw)
        _edge_links[key] = {
            "source": weakref(source), "mesh": source.mesh, "draw": draw
        }
    _refresh_contact_lines(found)

func _position_id(point: Vector3, ids: Dictionary) -> int:
    var quantized := Vector3i(roundi(point.x * WELD_GRID),
        roundi(point.y * WELD_GRID), roundi(point.z * WELD_GRID))
    if not ids.has(quantized):
        ids[quantized] = ids.size()
    return int(ids[quantized])

func _register_edge(edges: Dictionary, position_ids: Dictionary,
        start: Vector3, finish: Vector3, face_normal: Vector3) -> void:
    if start.distance_squared_to(finish) < 0.0000000001:
        return
    var a: int = _position_id(start, position_ids)
    var b: int = _position_id(finish, position_ids)
    if a == b:
        return
    var key: String = ("%d:%d" % [a, b]) if a < b else (
        "%d:%d" % [b, a])
    if not edges.has(key):
        edges[key] = {
            "a": start, "b": finish,
            "n0": face_normal, "n1": Vector3.ZERO, "faces": 1
        }
        return
    var entry: Dictionary = edges[key]
    if int(entry["faces"]) == 1:
        entry["n1"] = face_normal
    entry["faces"] = int(entry["faces"]) + 1
    edges[key] = entry

func _edge_geometry(source_mesh: Mesh) -> ArrayMesh:
    var cache_key: int = source_mesh.get_instance_id()
    if _geometry_cache.has(cache_key):
        return _geometry_cache[cache_key] as ArrayMesh
    var edges: Dictionary = {}
    var position_ids: Dictionary = {}
    var triangle_total: int = 0
    for surface in range(source_mesh.get_surface_count()):
        if source_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var data: Array = source_mesh.surface_get_arrays(surface)
        var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
        if points.is_empty():
            continue
        var normals := PackedVector3Array()
        if data[Mesh.ARRAY_NORMAL] is PackedVector3Array:
            normals = data[Mesh.ARRAY_NORMAL]
        var indices := PackedInt32Array()
        if data[Mesh.ARRAY_INDEX] is PackedInt32Array:
            indices = data[Mesh.ARRAY_INDEX]
        var vertex_count: int = (indices.size()
            if not indices.is_empty() else points.size())
        var triangles: int = int(vertex_count / 3)
        triangle_total += triangles
        if triangle_total > MAX_TRIANGLES_PER_MESH:
            _geometry_cache[cache_key] = null
            return null
        for i in range(triangles):
            var ia: int = indices[i * 3] if not indices.is_empty() else i * 3
            var ib: int = indices[i * 3 + 1] if not indices.is_empty() else i * 3 + 1
            var ic: int = indices[i * 3 + 2] if not indices.is_empty() else i * 3 + 2
            if ia < 0 or ib < 0 or ic < 0 or (
                    ia >= points.size() or ib >= points.size() or ic >= points.size()):
                continue
            var a: Vector3 = points[ia]
            var b: Vector3 = points[ib]
            var c: Vector3 = points[ic]
            var face_normal: Vector3 = (b - a).cross(c - a)
            if face_normal.length_squared() < 0.0000000001:
                continue
            if normals.size() == points.size():
                var authored: Vector3 = normals[ia] + normals[ib] + normals[ic]
                if authored.length_squared() > 0.0000000001:
                    face_normal = authored
            face_normal = face_normal.normalized()
            _register_edge(edges, position_ids, a, b, face_normal)
            _register_edge(edges, position_ids, b, c, face_normal)
            _register_edge(edges, position_ids, c, a, face_normal)

    var out_points := PackedVector3Array()
    var out_normals := PackedVector3Array()
    var out_tangents := PackedFloat32Array()
    var out_colors := PackedColorArray()
    var out_uv := PackedVector2Array()
    var out_indices := PackedInt32Array()
    var emitted: int = 0
    for edge in edges.values():
        var record: Dictionary = edge
        var faces: int = int(record["faces"])
        # Non-manifold edges have ambiguous facing; avoid solid black
        # seams from piled-up duplicate triangles.
        if faces > 2:
            continue
        var n0: Vector3 = record["n0"]
        var n1: Vector3 = record["n1"]
        if faces == 2 and n0.dot(n1) >= COPLANAR_DOT:
            continue
        var a: Vector3 = record["a"]
        var b: Vector3 = record["b"]
        var direction: Vector3 = (b - a).normalized()
        var encoded: Color = Color(
            (n1.x + 1.0) * 0.5, (n1.y + 1.0) * 0.5,
            (n1.z + 1.0) * 0.5, 1.0 if faces == 2 else 0.0)
        var begin: int = out_points.size()
        for corner in range(4):
            out_points.append(a if corner < 2 else b)
            out_normals.append(n0)
            out_tangents.append_array(PackedFloat32Array([
                direction.x, direction.y, direction.z, 1.0]))
            out_colors.append(encoded)
            out_uv.append(Vector2(-1.0 if corner % 2 == 0 else 1.0, 0.0))
        for index in [0, 1, 2, 1, 3, 2]:
            out_indices.append(begin + index)
        emitted += 1
        if emitted >= MAX_EDGES_PER_MESH:
            break
    if out_points.is_empty():
        _geometry_cache[cache_key] = null
        return null
    var result := ArrayMesh.new()
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = out_points
    arrays[Mesh.ARRAY_NORMAL] = out_normals
    arrays[Mesh.ARRAY_TANGENT] = out_tangents
    arrays[Mesh.ARRAY_COLOR] = out_colors
    arrays[Mesh.ARRAY_TEX_UV] = out_uv
    arrays[Mesh.ARRAY_INDEX] = out_indices
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    _geometry_cache[cache_key] = result
    return result

func _contact_ribbon_mesh(segments: PackedVector3Array) -> ArrayMesh:
    if segments.size() < 2:
        return null
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var tangents := PackedFloat32Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for i in range(int(segments.size() / 2)):
        var a: Vector3 = segments[i * 2]
        var b: Vector3 = segments[i * 2 + 1]
        if a.distance_squared_to(b) < 0.0000000001:
            continue
        var direction: Vector3 = (b - a).normalized()
        var begin: int = vertices.size()
        for corner in range(4):
            vertices.append(a if corner < 2 else b)
            normals.append(Vector3.UP)
            tangents.append_array(PackedFloat32Array([
                direction.x, direction.y, direction.z, 1.0]))
            # An actual intersection curve is a boundary (no adjacent-face
            # visibility decision); regular scene depth still masks it.
            colors.append(Color(0.5, 0.5, 0.5, 0.0))
            uvs.append(Vector2(-1.0 if corner % 2 == 0 else 1.0, 0.0))
        for idx in [0, 1, 2, 1, 3, 2]:
            indices.append(begin + idx)
    if vertices.is_empty():
        return null
    var mesh := ArrayMesh.new()
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TANGENT] = tangents
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _refresh_contact_lines(found: Dictionary) -> void:
    # Contact extraction only runs when the *relative assembly* changes.
    # Dragging/rotating the complete preview does NOT rebuild any contacts.
    var relative_root: Transform3D = _source_root.global_transform.affine_inverse()
    var tokens: Array[String] = []
    for key in found.keys():
        var source: MeshInstance3D = found[key] as MeshInstance3D
        var relative: Transform3D = relative_root * source.global_transform
        tokens.append("%d:%d:%s:%s" % [
            key, source.mesh.get_instance_id(), str(relative),
            str(source.is_visible_in_tree())])
    tokens.sort()
    var signature: String = "|".join(tokens)
    if signature == _last_contact_signature:
        return
    _last_contact_signature = signature
    for old in _contact_links.values():
        if is_instance_valid(old):
            (old as Node).queue_free()
    _contact_links.clear()
    var segments: Dictionary = ContactSeams.build(_source_root, found)
    for key in segments.keys():
        var part: MeshInstance3D = found.get(key) as MeshInstance3D
        if not is_instance_valid(part):
            continue
        var geometry: ArrayMesh = _contact_ribbon_mesh(segments[key])
        if geometry == null:
            continue
        var contact := MeshInstance3D.new()
        contact.name = "SeraGPUContact_%d" % key
        contact.set_meta("sera_generated_live_edge", true)
        contact.set_meta("FX_NO_OUTLINE", true)
        contact.mesh = geometry
        contact.material_override = _edge_material
        contact.layers = part.layers
        contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        contact.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        contact.extra_cull_margin = 1.0
        part.add_child(contact)
        _contact_links[key] = contact

extends Node3D
## NEXUS display-SERA only: cached topological edge ribbons with GPU-facing
## convex silhouette selection. No ID SubViewport / screen-space sampling.
## MeshInstance3D children inherit their source pose, transforms and visibility.
const Edges = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const INK_SHADER = preload("res://shaders/nexus_sera_gpu_convex_silhouette.gdshader")
const EDGE_NAME: String = "NexusSeraConvexInk"
const SCAN_SECONDS: float = 0.65
const MAX_EDGES_PER_MESH: int = 8000
# Keep the apparent ink as thick as the 3px single-part ID preview.
# The old hardware depth test hid part of every screen-space ribbon.
const PREVIEW_MATCHED_STROKE_PX: float = 3.0
# Permit partial penetration between individually authored armor meshes.
# Full occlusion farther than this remains hidden; no global X-ray.
const EMBEDDED_EDGE_ALLOWANCE_M: float = 0.22

var _elapsed: float = 0.0
var _overlays: Dictionary = {} # source instance ID -> {source, overlay, mesh, closed}
var _geometry_cache: Dictionary = {} # mesh/closed -> {source, result}
var _material: ShaderMaterial


func _ready() -> void:
    _material = ShaderMaterial.new()
    _material.shader = INK_SHADER
    _material.set_shader_parameter("ink_color", Color("#17212f"))
    _material.set_shader_parameter("stroke_px", PREVIEW_MATCHED_STROKE_PX)
    _material.set_shader_parameter(
        "contact_depth_allowance", EMBEDDED_EDGE_ALLOWANCE_M)
    _material.render_priority = 110
    _scan()
    set_process(true)


func _process(delta: float) -> void:
    _elapsed -= delta
    if _elapsed <= 0.0:
        _elapsed = SCAN_SECONDS
        _scan()


# Called immediately on equipment changes; periodic scan remains a fallback.
func refresh_meshes() -> void:
    _elapsed = SCAN_SECONDS
    _scan()


func _exit_tree() -> void:
    for record in _overlays.values():
        var ink: MeshInstance3D = record.get("overlay") as MeshInstance3D
        if is_instance_valid(ink):
            ink.queue_free()
    _overlays.clear()
    _geometry_cache.clear()


static func _blocked(node: Node) -> bool:
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return true
    var label: String = str(node.name).to_lower()
    for text in ["viewedges", "seraedgeink", "nexusseraconvexink",
            "afterimage", "ghost", "projectile", "laser", "beam",
            "trail", "slash", "spark", "smoke", "flame", "glow",
            "flash", "shockwave", "particle", "exhaust", "effect",
            "radiance", "debris", "blast", "floor", "ground",
            "backdrop", "collision", "trigger", "debug"]:
        if label.contains(text):
            return true
    return false


static func _eligible(mesh_node: MeshInstance3D) -> bool:
    if mesh_node.mesh == null or mesh_node.mesh is QuadMesh or (
            mesh_node.mesh is PlaneMesh):
        return false
    # Only solid source pieces. The original material and shading are
    # untouched; no laser/FX meshes enter the outline ribbon pass.
    var mat: Material = mesh_node.material_override
    if mat is BaseMaterial3D:
        var solid: BaseMaterial3D = mat as BaseMaterial3D
        if solid.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (
                solid.blend_mode == BaseMaterial3D.BLEND_MODE_ADD):
            return false
    elif mat is ShaderMaterial:
        var src_shader: Shader = (mat as ShaderMaterial).shader
        if src_shader == null:
            return false
        var source: String = src_shader.code
        if source.contains("blend_add") or source.contains("ALPHA ="):
            return false
    return true


func _scan() -> void:
    var rig: Node3D = get_parent() as Node3D
    if not is_instance_valid(rig):
        return
    var requested: Dictionary = {}
    var pending: Array[Node] = [rig]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node == self or (node != rig and _blocked(node)):
            continue
        if node is MeshInstance3D and node.is_visible_in_tree() and (
                _eligible(node as MeshInstance3D)):
            var source: MeshInstance3D = node as MeshInstance3D
            requested[source.get_instance_id()] = source
        for child in node.get_children():
            if child is Node3D:
                pending.append(child)

    for key in _overlays.keys():
        if requested.has(key):
            continue
        var old: MeshInstance3D = _overlays[key].get("overlay") as MeshInstance3D
        if is_instance_valid(old):
            old.queue_free()
        _overlays.erase(key)

    for key in requested.keys():
        var source: MeshInstance3D = requested[key] as MeshInstance3D
        var closed: bool = bool(source.get_meta("sera_single_sided", false))
        var cached: Dictionary = _overlays.get(key, {})
        var old_mesh: Mesh = cached.get("mesh") as Mesh
        if old_mesh == source.mesh and bool(cached.get("closed", false)) == closed:
            var existing: MeshInstance3D = cached.get("overlay") as MeshInstance3D
            if is_instance_valid(existing):
                continue
        var overlay: MeshInstance3D = cached.get("overlay") as MeshInstance3D
        var generated: Mesh = _cached_geometry(source.mesh, closed)
        if generated == null:
            if is_instance_valid(overlay):
                overlay.queue_free()
            _overlays.erase(key)
            continue
        if not is_instance_valid(overlay):
            overlay = MeshInstance3D.new()
            overlay.name = EDGE_NAME
            overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            overlay.extra_cull_margin = 0.02
            overlay.material_override = _material
            overlay.set_meta("sera_skip_common_id_outline", true)
            source.add_child(overlay)
        overlay.mesh = generated
        overlay.layers = source.layers
        _overlays[key] = {
            "source": weakref(source), "overlay": overlay,
            "mesh": source.mesh, "closed": closed
        }


func _cached_geometry(source: Mesh, closed: bool) -> Mesh:
    var key: String = "%d/%d" % [source.get_instance_id(), int(closed)]
    if _geometry_cache.has(key):
        var entry: Dictionary = _geometry_cache[key]
        var previous: WeakRef = entry.get("source") as WeakRef
        if previous != null and previous.get_ref() == source:
            return entry.get("result") as Mesh
    var result: Mesh = _make_edges(source, closed)
    _geometry_cache[key] = {"source": weakref(source), "result": result}
    return result


static func _signed_volume(mesh: Mesh) -> float:
    var total: float = 0.0
    for surface in range(mesh.get_surface_count()):
        if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != (
                Mesh.PRIMITIVE_TRIANGLES):
            continue
        var arrays: Array = mesh.surface_get_arrays(surface)
        var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if points.is_empty():
            continue
        var ids := PackedInt32Array()
        if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
            ids = arrays[Mesh.ARRAY_INDEX]
        var indexed: bool = not ids.is_empty()
        var count: int = ids.size() if indexed else points.size()
        for k in range(0, count - 2, 3):
            var i0: int = ids[k] if indexed else k
            var i1: int = ids[k + 1] if indexed else k + 1
            var i2: int = ids[k + 2] if indexed else k + 2
            if mini(i0, mini(i1, i2)) < 0 or (
                    maxi(i0, maxi(i1, i2)) >= points.size()):
                continue
            total += points[i0].dot(points[i1].cross(points[i2])) / 6.0
    return total


static func _make_edges(mesh: Mesh, closed: bool) -> ArrayMesh:
    var extracted: Array = Edges._extract_edges(mesh)
    if extracted.is_empty():
        return null
    # Consistent closed meshes can have either winding. Signed volume
    # determines which normal direction is outward for convex filtering.
    # Open meshes have ambiguous volume: keep their physical boundaries.
    var outward_sign: float = 1.0
    if closed and _signed_volume(mesh) < 0.0:
        outward_sign = -1.0
    var writer := SurfaceTool.new()
    writer.begin(Mesh.PRIMITIVE_TRIANGLES)
    writer.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var emitted: int = 0
    for item in extracted:
        if emitted >= MAX_EDGES_PER_MESH:
            break
        var edge: Dictionary = item as Dictionary
        var a: Vector3 = edge["a"]
        var b: Vector3 = edge["b"]
        var direction: Vector3 = b - a
        if direction.length_squared() < 0.000000001:
            continue
        var tangent: Vector3 = direction.normalized()
        var normal_a: Vector3 = edge["face_a"]
        var normal_b: Vector3 = edge.get("face_b", Vector3.ZERO)
        # A paired edge that shares two nearly coplanar faces is already
        # culled by the geometry extractor. Ignore ambiguous non-manifolds.
        var paired: bool = edge.has("face_b") and (
            int(edge.get("count", 0)) == 2) and (
            not bool(edge.get("duplicate_triangle", false)))
        if closed and edge.has("face_b") and not paired:
            continue
        if closed and paired:
            var convex_bend: float = tangent.dot(normal_a.cross(normal_b))
            if convex_bend * outward_sign <= 0.00001:
                continue
        normal_a = (normal_a * outward_sign).normalized()
        if paired:
            normal_b = (normal_b * outward_sign).normalized()
        var encoded_a := Color(
            normal_a.x * 0.5 + 0.5, normal_a.y * 0.5 + 0.5,
            normal_a.z * 0.5 + 0.5, 1.0)
        var encoded_b := Color(normal_b.x, normal_b.y, normal_b.z,
            1.0 if paired else 0.0)
        for corner in [[a, -1.0], [b, -1.0], [b, 1.0],
                [a, -1.0], [b, 1.0], [a, 1.0]]:
            writer.set_color(encoded_a)
            writer.set_custom(0, encoded_b)
            writer.set_normal(tangent)
            writer.set_uv(Vector2(float(corner[1]), 0.0))
            writer.add_vertex(corner[0])
        emitted += 1
    if emitted == 0:
        return null
    return writer.commit()

extends Node3D
## NEXUS display-SERA only: cached topological edge ribbons with GPU-facing
## convex silhouette selection. Contacts use the NEXUS shared ID compositor.
## MeshInstance3D children inherit their source pose, transforms and visibility.
const Edges = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const INK_SHADER = preload("res://shaders/nexus_sera_gpu_convex_silhouette.gdshader")
const GPU_FULL_EDGES = preload("res://shaders/sera_bittaran_gpu_contours.gdshader")
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const EDGE_NAME: String = "NexusSeraConvexInk"
const SCAN_SECONDS: float = 0.65
const MAX_EDGES_PER_MESH: int = 8000
# Only internal convex ridges use this width; visible-ID owns the outer 4px.
const PREVIEW_MATCHED_STROKE_PX: float = 4.0
# Reuse the same topology/depth shader in combat with thinner creases.
# The NEXUS defaults remain unchanged for existing users of this helper.
var ink_stroke_px: float = PREVIEW_MATCHED_STROKE_PX
var ink_render_priority: int = 110
var overlay_name: String = EDGE_NAME
# Icon capture also restricts visible front creases to hard (>=80°) edges.
# Optional for combat only; NEXUS retains its existing geometry by default.
var hard_creases_only: bool = false
# Battle-only GPU mode: silhouette and disjoint mesh borders (no convex ridges).
# Off by default to preserve NEXUS/icon consumers of this controller.
var enable_combat_gpu_full_edges: bool = false
var silhouette_inside_px: float = 1.0
var silhouette_outside_px: float = 5.0
var seam_stroke_px: float = 4.0
var scan_interval_seconds: float = SCAN_SECONDS

var _elapsed: float = 0.0
var _overlays: Dictionary = {} # source instance ID -> {source, overlay, mesh, closed}
var _geometry_cache: Dictionary = {} # mesh/closed -> {source, result}
var _material: ShaderMaterial


func _ready() -> void:
    _material = ShaderMaterial.new()
    _material.shader = GPU_FULL_EDGES if enable_combat_gpu_full_edges else INK_SHADER
    _material.set_shader_parameter("ink_color", Color("#17212f"))
    if enable_combat_gpu_full_edges:
        _material.set_shader_parameter("silhouette_inside_px", silhouette_inside_px)
        _material.set_shader_parameter("silhouette_outside_px", silhouette_outside_px)
        _material.set_shader_parameter("seam_px", seam_stroke_px)
    else:
        _material.set_shader_parameter("stroke_px", ink_stroke_px)
    _material.render_priority = ink_render_priority
    _scan()
    set_process(true)


func _process(delta: float) -> void:
    _elapsed -= delta
    if _elapsed <= 0.0:
        _elapsed = scan_interval_seconds
        _scan()


# Called immediately on equipment changes; periodic scan remains a fallback.
func refresh_meshes() -> void:
    _elapsed = scan_interval_seconds
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
    # Read the on-device graphics option only during the low-frequency scan,
    # not every visual frame. Disabling linework hides the cached ribbons.
    if enable_combat_gpu_full_edges and not GraphicsSettings.get_enabled(
            "character_outline"):
        for record in _overlays.values():
            var visible_overlay: MeshInstance3D = record.get(
                "overlay") as MeshInstance3D
            if is_instance_valid(visible_overlay):
                visible_overlay.visible = false
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
                existing.visible = true
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
            overlay.name = overlay_name
            overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            overlay.extra_cull_margin = 0.08 if (
                enable_combat_gpu_full_edges) else 0.02
            overlay.material_override = _material
            overlay.set_meta("sera_skip_common_id_outline", true)
            overlay.set_meta("FX_NO_OUTLINE", true)
            overlay.set_meta("sera_generated_live_edge", true)
            source.add_child(overlay)
        overlay.mesh = generated
        overlay.layers = source.layers
        overlay.visible = true
        _overlays[key] = {
            "source": weakref(source), "overlay": overlay,
            "mesh": source.mesh, "closed": closed
        }


func _cached_geometry(source: Mesh, closed: bool) -> Mesh:
    var key: String = "%d/%d/%d/%d" % [
        source.get_instance_id(), int(closed),
        int(hard_creases_only), int(enable_combat_gpu_full_edges)]
    if _geometry_cache.has(key):
        var entry: Dictionary = _geometry_cache[key]
        var previous: WeakRef = entry.get("source") as WeakRef
        if previous != null and previous.get_ref() == source:
            return entry.get("result") as Mesh
    var result: Mesh = _make_edges(
        source, closed, hard_creases_only, enable_combat_gpu_full_edges)
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


# Select the most straight-on face-connected neighbor during cached
# mesh construction. Its direction lets the GPU recompute the corner angle
# after projection for the current camera (including camera shake).
# UV.y retains the conservative 3D cap as a fallback.
static func _combat_endpoint_corner(edge: Dictionary,
        endpoint: Vector3, outgoing: Vector3,
        incident: Dictionary) -> Dictionary:
    var spokes: Array = incident.get(Edges._position_key(endpoint), [])
    # Non-manifold intersections are ambiguous; retain the known-good cap.
    if spokes.size() > 16:
        return {"scale": 1.0, "neighbor": Vector3.ZERO, "kind": 0.0}
    var face_a: Vector3 = edge["face_a"]
    var face_b: Vector3 = edge.get("face_b", Vector3.ZERO)
    var scale: float = 1.0
    # Select one other welded edge sharing a real face. A 90-degree corner
    # was previously treated as unconnected and kept its full inner cap.
    var best_cos: float = 1.0
    var best_neighbor: Vector3 = Vector3.ZERO
    for item in spokes:
        var neighbor: Dictionary = item as Dictionary
        var next_direction: Vector3 = neighbor["direction"]
        var cos_angle: float = clampf(outgoing.dot(next_direction), -1.0, 1.0)
        # Exclude this edge itself and duplicate same-direction spokes.
        if cos_angle > 0.999:
            continue
        var other_a: Vector3 = neighbor["face_a"]
        var other_b: Vector3 = neighbor["face_b"]
        var same_face: bool = face_a.dot(other_a) > 0.9995 or (
            other_b != Vector3.ZERO and face_a.dot(other_b) > 0.9995)
        if face_b != Vector3.ZERO:
            same_face = same_face or face_b.dot(other_a) > 0.9995 or (
                other_b != Vector3.ZERO and face_b.dot(other_b) > 0.9995)
        if not same_face:
            continue
        # Preserve the prior external-cap behavior for obtuse corners.
        # Right and acute joints keep an unmodified full outer extension.
        if cos_angle < 0.0:
            var required_ratio: float = sqrt(maxf(0.0,
                (1.0 + cos_angle) / maxf(1.0 - cos_angle, 0.0001)))
            scale = minf(scale, clampf(required_ratio, 0.2, 1.0))
        if cos_angle < best_cos:
            best_cos = cos_angle
            best_neighbor = next_direction
    # CUSTOM2.w: 1 = legacy projected outer-cap adjustment (>90 deg);
    # 0.5 = new inside-only trim for face-connected right/acute corners.
    # 0 = isolated endpoint, preserve its original square cap.
    var connection_kind: float = 0.0
    if best_neighbor != Vector3.ZERO:
        connection_kind = 1.0 if best_cos < -0.001 else 0.5
    return {"scale": scale, "neighbor": best_neighbor,
        "kind": connection_kind}


static func _make_edges(mesh: Mesh, closed: bool,
        hard_only: bool = false,
        include_full_contour: bool = false) -> ArrayMesh:
    var extracted: Array = Edges._extract_edges(mesh)
    if extracted.is_empty():
        return null
    # Consistent closed meshes can have either winding. Signed volume
    # determines which normal direction is outward for convex filtering.
    # Open meshes have ambiguous volume: keep their physical boundaries.
    var outward_sign: float = 1.0
    if closed and not include_full_contour and _signed_volume(mesh) < 0.0:
        outward_sign = -1.0
    var writer := SurfaceTool.new()
    writer.begin(Mesh.PRIMITIVE_TRIANGLES)
    writer.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    if include_full_contour:
        # Each ribbon's six vertices need the SAME view-facing decision.
        # Store the local edge midpoint at full float precision; the normal
        # and camera-facing test must not vary between its two endpoints.
        writer.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
        # One cached neighboring 3D edge direction at each ribbon endpoint.
        # No new triangles, materials, cameras, or visibility passes.
        writer.set_custom_format(2, SurfaceTool.CUSTOM_RGBA_FLOAT)
    # Build one adjacency index for cached combat meshes. The original
    # ribbon topology and the 6-vertex drawing path remain untouched.
    var incident: Dictionary = {}
    if include_full_contour:
        for candidate_value in extracted:
            var candidate: Dictionary = candidate_value as Dictionary
            var candidate_paired: bool = candidate.has("face_b") and (
                int(candidate.get("count", 0)) == 2) and (
                not bool(candidate.get("duplicate_triangle", false)))
            var candidate_boundary: bool = not candidate.has("face_b") and (
                int(candidate.get("count", 0)) == 1)
            if not candidate_paired and not candidate_boundary:
                continue
            var start: Vector3 = candidate["a"]
            var finish: Vector3 = candidate["b"]
            var span: Vector3 = finish - start
            if span.length_squared() < 0.000000001:
                continue
            var unit_span: Vector3 = span.normalized()
            for endpoint in [[start, unit_span], [finish, -unit_span]]:
                var key: String = Edges._position_key(endpoint[0])
                if not incident.has(key):
                    incident[key] = []
                var spokes: Array = incident[key]
                spokes.append({
                    "direction": endpoint[1],
                    "face_a": candidate["face_a"],
                    "face_b": candidate.get("face_b", Vector3.ZERO)
                })
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
        # New full contour includes genuine single-sided boundary edges
        # and paired edges; ambiguous duplicate/non-manifold edges are ignored.
        # Retain every paired edge as a possible front/back silhouette at
        # other camera angles. No front/front crease is emitted in full mode.
        var boundary: bool = not edge.has("face_b") and (
            int(edge.get("count", 0)) == 1)
        if include_full_contour:
            if not paired and not boundary:
                continue
        else:
            if not paired:
                continue
            if hard_only and not bool(edge.get("crease", false)):
                continue
        # Topology is shared, but this expensive convexity classification is
        # needed only by the legacy NEXUS/icon convex controller.
        var signed_convex: bool = true
        if not include_full_contour and closed and paired:
            var convex_bend: float = tangent.dot(normal_a.cross(normal_b))
            signed_convex = convex_bend * outward_sign > 0.00001
            if not signed_convex:
                continue
        normal_a = (normal_a * outward_sign).normalized()
        if paired:
            normal_b = (normal_b * outward_sign).normalized()
        # The existing edge extractor marks genuine >=80-degree
        # face-to-face creases. In combat, retain this bit so the GPU can
        # show only front/front hard edges as additional visible seams.
        # Coplanar triangulation lines and non-manifold pairs are excluded
        # by the extractor and the paired condition above.
        var emit_crease: bool = (paired and (
            bool(edge.get("crease", false)) if include_full_contour else (
            signed_convex and (not hard_only or
                bool(edge.get("crease", false))))))
        var encoded_a := Color(
            normal_a.x * 0.5 + 0.5, normal_a.y * 0.5 + 0.5,
            normal_a.z * 0.5 + 0.5,
            1.0 if emit_crease else 0.0)
        var encoded_b := Color(normal_b.x, normal_b.y, normal_b.z,
            1.0 if paired else 0.0)
        var midpoint: Vector3 = (a + b) * 0.5
        # Keep the PR #871 shader and triangles. Only encode smaller cap
        # extensions at genuinely connected obtuse (>90 degree) joins.
        # Unconnected, right-angle and acute corners retain the old cap.
        var start_cap: float = 1.0
        var end_cap: float = 1.0
        var start_neighbor: Vector3 = Vector3.ZERO
        var end_neighbor: Vector3 = Vector3.ZERO
        var start_kind: float = 0.0
        var end_kind: float = 0.0
        if include_full_contour:
            var start_corner: Dictionary = _combat_endpoint_corner(
                edge, a, tangent, incident)
            var end_corner: Dictionary = _combat_endpoint_corner(
                edge, b, -tangent, incident)
            start_cap = float(start_corner["scale"])
            end_cap = float(end_corner["scale"])
            start_neighbor = start_corner["neighbor"]
            end_neighbor = end_corner["neighbor"]
            start_kind = float(start_corner["kind"])
            end_kind = float(end_corner["kind"])
        # UV.x is stroke side. UV.y keeps the 3D fallback cap fraction.
        # Per-endpoint CUSTOM2 provides a camera-projected alternative.
        for corner in [[a, -1.0, -start_cap, start_neighbor, start_kind],
                [b, -1.0, end_cap, end_neighbor, end_kind],
                [b, 1.0, end_cap, end_neighbor, end_kind],
                [a, -1.0, -start_cap, start_neighbor, start_kind],
                [b, 1.0, end_cap, end_neighbor, end_kind],
                [a, 1.0, -start_cap, start_neighbor, start_kind]]:
            writer.set_color(encoded_a)
            writer.set_custom(0, encoded_b)
            if include_full_contour:
                writer.set_custom(1, Color(
                    midpoint.x, midpoint.y, midpoint.z, 0.0))
                var next_edge: Vector3 = corner[3]
                writer.set_custom(2, Color(
                    next_edge.x, next_edge.y, next_edge.z,
                    float(corner[4])))
            writer.set_normal(tangent)
            writer.set_uv(Vector2(float(corner[1]), float(corner[2])))
            writer.add_vertex(corner[0])
        emitted += 1
    if emitted == 0:
        return null
    return writer.commit()

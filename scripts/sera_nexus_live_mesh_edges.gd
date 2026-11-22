extends Node3D
## NEXUS full-body SERA outline: camera-facing GPU edge ribbons in the SAME
## 3D viewport as the source meshes. Every ribbon is a child of its original
## MeshInstance3D, so bone animation, preview rotation and scale use the same
## scene transforms and rendering frame without any ID-camera synchronization.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const RenderOrder = preload("res://scripts/render_order_policy.gd")
const EDGE_SHADER = preload("res://shaders/sera_live_mesh_edges.gdshader")
const XRAY_SHADER = preload("res://shaders/sera_live_mesh_edges_xray.gdshader")
const ContactSeams = preload("res://scripts/sera_nexus_contact_seams.gd")
const RibbonGeometry = preload("res://scripts/sera_nexus_outline_geometry.gd")
const RESCAN_SECONDS: float = 0.35
const WELD_GRID: float = 10000.0
const MAX_TRIANGLES_PER_MESH: int = 12000
const MAX_EDGES_PER_MESH: int = 40000
const COPLANAR_DOT: float = 0.995

var _source_root: Node3D
var _edge_material: ShaderMaterial
var _xray_material: ShaderMaterial
var _diagnostic_mode: int = 0
var _edge_links: Dictionary = {} # source ID -> {source, mesh, draw}
var _geometry_cache: Dictionary = {} # Mesh resource instance ID -> ArrayMesh/null
var _contact_links: Dictionary = {} # mesh ID -> depth-tested contact ribbons
var _last_contact_signature: String = ""
var _visible_sources: Dictionary = {}
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
    _edge_material.set_shader_parameter("ink_color", Color("#0b1118"))
    _edge_material.set_shader_parameter("silhouette_px", 3.0)
    _edge_material.set_shader_parameter("boundary_px", 1.0)
    _edge_material.set_shader_parameter("diagnostic_mode", 0)
    _xray_material = _edge_material.duplicate() as ShaderMaterial
    _xray_material.shader = XRAY_SHADER
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
                draw.visible = enabled and _diagnostic_mode >= 2 and _diagnostic_mode <= 5
        for contact in _contact_links.values():
            if is_instance_valid(contact):
                (contact as MeshInstance3D).visible = enabled and (
                    _diagnostic_mode == 4 or _diagnostic_mode == 5)
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
            draw.visible = _diagnostic_mode >= 2 and _diagnostic_mode <= 5
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
    _visible_sources = found
    # Contact intersection geometry is costly and rarely contributes to the
    # exterior outline. Build it only when its diagnostic is explicitly open.
    if _diagnostic_mode == 4 or _diagnostic_mode == 5:
        _refresh_contact_lines(found)
    # A new equipment mesh inherits the selected debug material without
    # re-entering the expensive contact extraction on every rescan.
    if _diagnostic_mode != 0:
        var current_material: ShaderMaterial = (
            _xray_material if _diagnostic_mode == 5 else _edge_material)
        for record in _edge_links.values():
            var draw: MeshInstance3D = record.get("draw") as MeshInstance3D
            if is_instance_valid(draw):
                draw.material_override = current_material
                draw.visible = _diagnostic_mode >= 2 and _diagnostic_mode <= 5
        for value in _contact_links.values():
            var contact: MeshInstance3D = value as MeshInstance3D
            if is_instance_valid(contact):
                contact.material_override = current_material
                contact.visible = (_diagnostic_mode == 4 or _diagnostic_mode == 5)

# Reuse the proven GPU edge extractor used by BASE facilities.
# Its SurfaceTool format is consumed identically by SERA's new 3D shader,
# preventing UV, COLOR, NORMAL and TANGENT semantic mismatches on Android.
func _edge_geometry(source_mesh: Mesh) -> ArrayMesh:
    var cache_key: int = source_mesh.get_instance_id()
    if _geometry_cache.has(cache_key):
        return _geometry_cache[cache_key] as ArrayMesh
    var result: ArrayMesh = RibbonGeometry.build(source_mesh)
    _geometry_cache[cache_key] = result
    return result

func _contact_ribbon_mesh(segments: PackedVector3Array) -> ArrayMesh:
    if segments.size() < 2:
        return null
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
    var emitted: int = 0
    for index in range(int(segments.size() / 2)):
        var a: Vector3 = segments[index * 2]
        var b: Vector3 = segments[index * 2 + 1]
        var edge: Vector3 = b - a
        if edge.length_squared() < 0.0000000001:
            continue
        var tangent: Vector3 = edge.normalized()
        # The outline shader recognizes CUSTOM0.w=2 as an explicit
        # contact: normal A/B tests do not suppress its visible segments.
        for endpoint in [[a, -1.0], [b, -1.0], [b, 1.0],
                [a, -1.0], [b, 1.0], [a, 1.0]]:
            surface.set_normal(tangent)
            surface.set_color(Color(0.5, 1.0, 0.5, 0.0))
            surface.set_custom(0, Color(0.0, 0.0, 0.0, 2.0))
            surface.set_uv(Vector2(float(endpoint[1]), 0.0))
            surface.add_vertex(endpoint[0])
        emitted += 1
    if emitted == 0:
        return null
    return surface.commit()

func _relative_pose_signature(pose: Transform3D) -> String:
    # Quantization cancels float roundoff from rotating the complete rig:
    # never mistake a camera/player drag for a changed joint assembly.
    var components: Array[String] = []
    for value in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
        components.append("%d,%d,%d" % [roundi(value.x * 1000.0),
            roundi(value.y * 1000.0), roundi(value.z * 1000.0)])
    return ";".join(components)

func _refresh_contact_lines(found: Dictionary) -> void:
    # Contact extraction only runs when the *relative assembly* changes.
    # Dragging/rotating the complete preview does NOT rebuild any contacts.
    var relative_root: Transform3D = _source_root.global_transform.affine_inverse()
    var tokens: Array[String] = []
    for key in found.keys():
        var source: MeshInstance3D = found[key] as MeshInstance3D
        var relative: Transform3D = relative_root * source.global_transform
        tokens.append("%d:%d:%s:%s" % [
            key, source.mesh.get_instance_id(),
            _relative_pose_signature(relative),
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
        contact.visible = _diagnostic_mode == 4 or _diagnostic_mode == 5
        contact.layers = part.layers
        contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        contact.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        contact.extra_cull_margin = 1.0
        part.add_child(contact)
        _contact_links[key] = contact

## Diagnostic controls are intentionally separate from the persistent
## GRAPHICS SETTINGS switch; all modes return to production on exit.
func set_diagnostic_mode(mode: int) -> void:
    _diagnostic_mode = clampi(mode, 0, 9)
    if _edge_material == null or _xray_material == null:
        return
    if _diagnostic_mode == 4 or _diagnostic_mode == 5:
        # On-demand extraction, not a continuous background contact scan.
        _refresh_contact_lines(_visible_sources)
    _edge_material.set_shader_parameter("diagnostic_mode", _diagnostic_mode)
    _xray_material.set_shader_parameter("diagnostic_mode", _diagnostic_mode)
    var chosen: ShaderMaterial = (
        _xray_material if _diagnostic_mode == 5 else _edge_material)
    for record in _edge_links.values():
        var draw: MeshInstance3D = record.get("draw") as MeshInstance3D
        if is_instance_valid(draw):
            draw.material_override = chosen
            draw.visible = (_diagnostic_mode >= 2 and _diagnostic_mode <= 5
                and GraphicsSettings.get_enabled("character_outline"))
    for value in _contact_links.values():
        var contact: MeshInstance3D = value as MeshInstance3D
        if is_instance_valid(contact):
            contact.material_override = chosen
            contact.visible = (_diagnostic_mode == 4 or _diagnostic_mode == 5) and (
                GraphicsSettings.get_enabled("character_outline"))

func get_diagnostic_snapshot() -> Dictionary:
    # No GPU readback: these are counts of prepared geometry, not claims
    # about how many screen pixels were actually rasterized.
    var active_sources: int = 0
    var live_draws: int = 0
    var missing_draws: int = 0
    var topology_edges: int = 0
    for record in _edge_links.values():
        var ref: WeakRef = record.get("source") as WeakRef
        var source: MeshInstance3D = (
            ref.get_ref() as MeshInstance3D if ref != null else null)
        if not is_instance_valid(source) or not source.is_visible_in_tree():
            continue
        active_sources += 1
        var draw: MeshInstance3D = record.get("draw") as MeshInstance3D
        if not is_instance_valid(draw) or draw.mesh == null:
            missing_draws += 1
            continue
        live_draws += 1
        if draw.mesh.get_surface_count() > 0:
            var arrays: Array = draw.mesh.surface_get_arrays(0)
            var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            topology_edges += int(points.size() / 6)
    var contact_strokes: int = 0
    for value in _contact_links.values():
        var draw: MeshInstance3D = value as MeshInstance3D
        if is_instance_valid(draw) and draw.mesh != null and (
                draw.mesh.get_surface_count() > 0):
            var arrays: Array = draw.mesh.surface_get_arrays(0)
            var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            contact_strokes += int(points.size() / 6)
    var camera: Camera3D = get_viewport().get_camera_3d()
    return {
        "mode": _diagnostic_mode,
        "active_sources": active_sources,
        "edge_draws": live_draws,
        "missing_draws": missing_draws,
        "edge_segments": topology_edges,
        "contact_segments": contact_strokes,
        "camera_present": is_instance_valid(camera),
        "enabled": GraphicsSettings.get_enabled("character_outline"),
        "depth_disabled": _diagnostic_mode == 5,
        "contacts_cached": not _last_contact_signature.is_empty()
    }

extends Node3D
## NEXUS-only same-viewport 8-direction full-body silhouette.
## One transparent stencil writer per visible opaque source mesh and one
## MultiMesh with 8 shifted instances per rigid source mesh. Both are children
## of the SOURCE mesh to inherit its pose with zero frame synchronization.
## Old GPU edge and hull renderers stay available for isolated diagnostics.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const MASK_SHADER = preload("res://shaders/sera_nexus_stencil_mask.gdshader")
const SHIFT_SHADER = preload("res://shaders/sera_nexus_eightway_silhouette.gdshader")
const RESCAN_SECONDS: float = 0.35
const DIRECTION_COUNT: int = 8

var _source_root: Node3D
var _mask_material: ShaderMaterial
var _shift_material: ShaderMaterial
var _fallback_materials: Array[ShaderMaterial] = []
var _links: Dictionary = {}
var _mode: int = 0
var _enabled: bool = true
var _elapsed: float = 0.0
var _candidate_count: int = 0
var _hidden_count: int = 0

func configure(source_rig: Node3D) -> void:
    _source_root = source_rig

func _production_mode() -> bool:
    return _mode == 0 or _mode == 1 or _mode == 9

func _active() -> bool:
    return _enabled and _production_mode()

func _ready() -> void:
    name = "SeraEightWayOutline"
    set_meta("sera_generated_live_edge", true)
    set_meta("FX_NO_OUTLINE", true)

    _mask_material = ShaderMaterial.new()
    _mask_material.shader = MASK_SHADER
    _mask_material.render_priority = -22
    _shift_material = ShaderMaterial.new()
    _shift_material.shader = SHIFT_SHADER
    _shift_material.render_priority = -21
    _shift_material.set_shader_parameter("outline_px", 3.0)

    # For a future skinned mesh, MultiMesh cannot share the skin binding.
    # Fall back to eight ordinary child instances with the same shader.
    for direction in range(DIRECTION_COUNT):
        var fallback := ShaderMaterial.new()
        fallback.shader = SHIFT_SHADER
        fallback.render_priority = -21
        fallback.set_shader_parameter("outline_px", 3.0)
        fallback.set_shader_parameter("override_direction", direction)
        _fallback_materials.append(fallback)

    _enabled = GraphicsSettings.get_enabled("character_outline")
    _apply_mode()
    if _active():
        _refresh_links()
    set_process(true)

func _process(delta: float) -> void:
    _elapsed -= delta
    if _elapsed > 0.0:
        return
    _elapsed = RESCAN_SECONDS
    var now_enabled: bool = GraphicsSettings.get_enabled("character_outline")
    if now_enabled != _enabled:
        _enabled = now_enabled
        _apply_mode()
    if _active():
        _refresh_links()

func set_diagnostic_mode(mode: int) -> void:
    _mode = clampi(mode, 0, 18)
    _apply_mode()
    if _active():
        _refresh_links()

func _apply_mode() -> void:
    var ink: Color = (Color("#29f4f7") if (
        _mode == 1 or _mode == 9) else Color("#0b1118"))
    _shift_material.set_shader_parameter("outline_color", ink)
    for mat in _fallback_materials:
        mat.set_shader_parameter("outline_color", ink)
    var show: bool = _active()
    for entry in _links.values():
        var record: Dictionary = entry
        var mask: MeshInstance3D = record.get("mask") as MeshInstance3D
        if is_instance_valid(mask):
            mask.visible = show
        var instanced: MultiMeshInstance3D = (
            record.get("instanced") as MultiMeshInstance3D)
        if is_instance_valid(instanced):
            instanced.visible = show
        for node in record.get("fallback", []):
            var part: MeshInstance3D = node as MeshInstance3D
            if is_instance_valid(part):
                part.visible = show

func _source_allowed(node: Node) -> bool:
    if bool(node.get_meta("sera_generated_live_edge", false)):
        return false
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return false
    var label: String = str(node.name).to_lower()
    for excluded in ["swordeffect", "afterimage", "ghost", "beam",
            "trail", "particle", "smoke", "glow", "fx_"]:
        if label.contains(excluded):
            return false
    return true

func _prepare_node(draw: GeometryInstance3D,
        source: MeshInstance3D) -> void:
    draw.set_meta("sera_generated_live_edge", true)
    draw.set_meta("FX_NO_OUTLINE", true)
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    draw.extra_cull_margin = 2.0
    draw.layers = source.layers
    draw.visible = _active()
    source.add_child(draw)

func _inherit_skin(draw: MeshInstance3D, source: MeshInstance3D) -> void:
    if source.skin != null:
        draw.skin = source.skin
    if source.skeleton.is_empty():
        return
    var skeleton: Node = source.get_node_or_null(source.skeleton)
    if skeleton is Skeleton3D:
        draw.skeleton = draw.get_path_to(skeleton)

func _requires_skin_fallback(source: MeshInstance3D) -> bool:
    if source.skin != null:
        return true
    if not source.skeleton.is_empty() and (
            source.get_node_or_null(source.skeleton) is Skeleton3D):
        return true
    return source.mesh != null and source.mesh.get_blend_shape_count() > 0

func _create_entry(source: MeshInstance3D) -> Dictionary:
    # Mask uses the original mesh, not reconstructed edges/hull normals.
    var mask := MeshInstance3D.new()
    mask.name = "SeraEightWay_Mask"
    mask.mesh = source.mesh
    mask.material_override = _mask_material
    _prepare_node(mask, source)
    _inherit_skin(mask, source)

    var instanced: MultiMeshInstance3D = null
    var fallback: Array[MeshInstance3D] = []
    if _requires_skin_fallback(source):
        for direction in range(DIRECTION_COUNT):
            var shifted := MeshInstance3D.new()
            shifted.name = "SeraEightWay_Skinned_%d" % direction
            shifted.mesh = source.mesh
            shifted.material_override = _fallback_materials[direction]
            _prepare_node(shifted, source)
            _inherit_skin(shifted, source)
            fallback.append(shifted)
    else:
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = source.mesh
        multimesh.instance_count = DIRECTION_COUNT
        for direction in range(DIRECTION_COUNT):
            multimesh.set_instance_transform(
                direction, Transform3D.IDENTITY)
        instanced = MultiMeshInstance3D.new()
        instanced.name = "SeraEightWay_8Offsets"
        instanced.multimesh = multimesh
        instanced.material_override = _shift_material
        _prepare_node(instanced, source)

    return {"source_mesh": source.mesh, "mask": mask,
        "instanced": instanced, "fallback": fallback,
        "source": weakref(source)}

func _dispose(record: Dictionary) -> void:
    var mask: MeshInstance3D = record.get("mask") as MeshInstance3D
    if is_instance_valid(mask):
        mask.visible = false
        mask.queue_free()
    var instanced: MultiMeshInstance3D = (
        record.get("instanced") as MultiMeshInstance3D)
    if is_instance_valid(instanced):
        instanced.visible = false
        instanced.queue_free()
    for node in record.get("fallback", []):
        var part: MeshInstance3D = node as MeshInstance3D
        if is_instance_valid(part):
            part.visible = false
            part.queue_free()

func _still_valid(record: Dictionary, source: MeshInstance3D) -> bool:
    if record.get("source_mesh") != source.mesh:
        return false
    if not is_instance_valid(record.get("mask")):
        return false
    var instance: MultiMeshInstance3D = (
        record.get("instanced") as MultiMeshInstance3D)
    if is_instance_valid(instance):
        return not _requires_skin_fallback(source)
    var fallback: Array = record.get("fallback", [])
    if fallback.size() != DIRECTION_COUNT:
        return false
    for node in fallback:
        if not is_instance_valid(node):
            return false
    return _requires_skin_fallback(source)

func _refresh_links() -> void:
    if not is_instance_valid(_source_root):
        return
    var found: Dictionary = {}
    var pending: Array[Node] = [_source_root]
    _candidate_count = 0
    _hidden_count = 0
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if not _source_allowed(node):
            continue
        if node is MeshInstance3D:
            var source: MeshInstance3D = node as MeshInstance3D
            if source.mesh != null and not (source.mesh is QuadMesh) and (
                    not (source.mesh is PlaneMesh)):
                _candidate_count += 1
                if source.is_visible_in_tree():
                    found[source.get_instance_id()] = source
                else:
                    _hidden_count += 1
        for child in node.get_children():
            if child is Node3D:
                pending.append(child)

    for id in _links.keys():
        if found.has(id):
            continue
        _dispose(_links[id])
        _links.erase(id)

    for id in found.keys():
        var source: MeshInstance3D = found[id] as MeshInstance3D
        var previous: Dictionary = _links.get(id, {})
        if _still_valid(previous, source):
            var mask: MeshInstance3D = previous.get("mask") as MeshInstance3D
            mask.layers = source.layers
            var instanced: MultiMeshInstance3D = (
                previous.get("instanced") as MultiMeshInstance3D)
            if is_instance_valid(instanced):
                instanced.layers = source.layers
            for node in previous.get("fallback", []):
                var copy: MeshInstance3D = node as MeshInstance3D
                copy.layers = source.layers
            continue
        if not previous.is_empty():
            _dispose(previous)
        _links[id] = _create_entry(source)

func get_outline_snapshot() -> Dictionary:
    var skinned_count: int = 0
    for record in _links.values():
        var entry: Dictionary = record
        if (entry.get("fallback", []) as Array).size() > 0:
            skinned_count += 1
    return {"parts": _links.size(),
        "direction_instances": _links.size() * DIRECTION_COUNT,
        "skinned_fallbacks": skinned_count,
        "mode": _mode,
        "active": _active(),
        "stencil_ref": 17,
        "mask_draws": _links.size() if _active() else 0,
        "candidates": _candidate_count,
        "hidden": _hidden_count}

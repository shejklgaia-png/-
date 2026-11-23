extends Node3D
## NEXUS-only production contour: real 3D normal-expanded smoothed inverted
## hull with native GPU depth testing. No stencil, mask, extra viewport,
## screen-XY-only movement, separate camera or per-frame CPU edge work.
## Each hull is a child of its original MeshInstance3D for same-frame pose.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const HullGeometry = preload("res://scripts/sera_nexus_smooth_hull_geometry.gd")
const CLOSED_SHADER = preload(
    "res://shaders/sera_nexus_depth_hull_blockbench.gdshader")
const OPEN_SHADER = preload(
    "res://shaders/sera_nexus_depth_hull_open.gdshader")
const RESCAN_SECONDS: float = 0.35

var _source_root: Node3D
var _closed_material: ShaderMaterial
var _open_material: ShaderMaterial
var _links: Dictionary = {}
var _baked_cache: Dictionary = {}
var _mode: int = 0
var _enabled: bool = true
var _elapsed: float = 0.0
var _last_candidates: int = 0
var _last_hidden: int = 0
var _last_unsupported: int = 0

func configure(source_rig: Node3D) -> void:
    _source_root = source_rig

func _active() -> bool:
    return _enabled and (_mode == 0 or _mode == 1 or _mode == 9)

func _ready() -> void:
    name = "SeraDepthHullOutline"
    set_meta("sera_generated_live_edge", true)
    set_meta("FX_NO_OUTLINE", true)
    _closed_material = ShaderMaterial.new()
    _closed_material.shader = CLOSED_SHADER
    _closed_material.render_priority = -21
    _closed_material.set_shader_parameter("outline_px", 3.0)
    _open_material = ShaderMaterial.new()
    _open_material.shader = OPEN_SHADER
    _open_material.render_priority = -21
    _open_material.set_shader_parameter("outline_px", 3.0)
    _enabled = GraphicsSettings.get_enabled("character_outline")
    _apply_color()
    if _active():
        _refresh_links()
    set_process(true)

func _process(delta: float) -> void:
    # Loading graphics preferences reads the config file. Poll only at the
    # same 0.35s cadence as equipment changes, never every rendered frame.
    _elapsed -= delta
    if _elapsed > 0.0:
        return
    _elapsed = RESCAN_SECONDS
    var setting: bool = GraphicsSettings.get_enabled("character_outline")
    if setting != _enabled:
        _enabled = setting
    if _active():
        _refresh_links()
    elif not _links.is_empty():
        _release_links()

func set_diagnostic_mode(mode: int) -> void:
    _mode = clampi(mode, 0, 18)
    _apply_color()
    _elapsed = 0.0
    if _active():
        _refresh_links()
    else:
        _release_links()

func _apply_color() -> void:
    if _closed_material == null or _open_material == null:
        return
    var ink: Color = Color("#29f4f7") if (
        _mode == 1 or _mode == 9) else Color("#0b1118")
    _closed_material.set_shader_parameter("outline_color", ink)
    _open_material.set_shader_parameter("outline_color", ink)

func _source_allowed(node: Node) -> bool:
    if bool(node.get_meta("sera_generated_live_edge", false)):
        return false
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return false
    var lower: String = str(node.name).to_lower()
    for excluded in ["swordeffect", "afterimage", "ghost", "beam",
            "trail", "particle", "smoke", "glow", "fx_"]:
        if lower.contains(excluded):
            return false
    return true

func _get_baked(source_mesh: Mesh) -> ArrayMesh:
    var mesh_id: int = source_mesh.get_instance_id()
    if not _baked_cache.has(mesh_id):
        # Existing baker welds split Blockbench vertices by their position
        # and preserves the original indices/skin/UV without touching source.
        _baked_cache[mesh_id] = HullGeometry.build(source_mesh)
    return _baked_cache[mesh_id] as ArrayMesh

func _dispose(entry: Dictionary) -> void:
    var hull: MeshInstance3D = entry.get("hull") as MeshInstance3D
    if is_instance_valid(hull):
        hull.visible = false
        hull.queue_free()

func _release_links() -> void:
    for entry in _links.values():
        _dispose(entry)
    _links.clear()
    _baked_cache.clear()
    _last_candidates = 0
    _last_hidden = 0
    _last_unsupported = 0

func _create_hull(source: MeshInstance3D,
        baked: ArrayMesh) -> MeshInstance3D:
    var hull := MeshInstance3D.new()
    hull.name = "SeraDepthHull_3D_3px"
    hull.set_meta("sera_generated_live_edge", true)
    hull.set_meta("FX_NO_OUTLINE", true)
    hull.mesh = baked
    # Sealed Blockbench meshes have opposite front winding. Open pieces
    # use a distinct back-face-only material with rear view-depth bias:
    # the former cull_disabled pass painted black polygons inside the body.
    var closed: bool = bool(source.get_meta("sera_single_sided", false))
    hull.material_override = (
        _closed_material if closed else _open_material)
    hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    hull.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    hull.extra_cull_margin = 2.0
    hull.layers = source.layers
    source.add_child(hull)
    # Preserve the same Skeleton3D when a part uses skeletal deformation.
    # Reparenting changes the relative skeleton NodePath, not the bones.
    var skeleton_path: NodePath = source.skeleton
    if not skeleton_path.is_empty():
        var skeleton_node: Node = source.get_node_or_null(skeleton_path)
        if is_instance_valid(skeleton_node):
            hull.skeleton = hull.get_path_to(skeleton_node)
            hull.skin = source.skin
    return hull

func _refresh_links() -> void:
    if not is_instance_valid(_source_root) or not _active():
        return
    var found: Dictionary = {}
    var queue: Array[Node] = [_source_root]
    _last_candidates = 0
    _last_hidden = 0
    while not queue.is_empty():
        var node: Node = queue.pop_back()
        if node == self or not _source_allowed(node):
            continue
        if node is MeshInstance3D:
            var source: MeshInstance3D = node as MeshInstance3D
            if source.mesh != null and not (source.mesh is QuadMesh) and (
                    not (source.mesh is PlaneMesh)):
                _last_candidates += 1
                if source.is_visible_in_tree():
                    found[source.get_instance_id()] = source
                else:
                    _last_hidden += 1
        for child in node.get_children():
            if child is Node3D:
                queue.append(child)

    for id in _links.keys():
        if found.has(id):
            continue
        _dispose(_links[id])
        _links.erase(id)

    _last_unsupported = 0
    var active_mesh_ids: Dictionary = {}
    for id in found.keys():
        var source: MeshInstance3D = found[id] as MeshInstance3D
        active_mesh_ids[source.mesh.get_instance_id()] = true
        var previous: Dictionary = _links.get(id, {})
        var old_hull: MeshInstance3D = (
            previous.get("hull") as MeshInstance3D)
        if previous.get("source_mesh") == source.mesh and (
                is_instance_valid(old_hull)):
            old_hull.layers = source.layers
            continue
        if not previous.is_empty():
            _dispose(previous)
            _links.erase(id)
        var baked: ArrayMesh = _get_baked(source.mesh)
        if baked == null:
            _last_unsupported += 1
            continue
        _links[id] = {
            "source_mesh": source.mesh,
            "hull": _create_hull(source, baked)
        }

    # Gear swaps should not retain every historical outline mesh.
    for mesh_id in _baked_cache.keys():
        if not active_mesh_ids.has(mesh_id):
            _baked_cache.erase(mesh_id)

func get_outline_snapshot() -> Dictionary:
    return {
        "parts": _links.size(),
        "candidates": _last_candidates,
        "hidden": _last_hidden,
        "unsupported": _last_unsupported,
        "hulls": _links.size() if _active() else 0,
        "mode": _mode,
        "active": _active(),
        "outline_px": 3.0,
        "pipeline": "3d_normal_expanded_hull_native_depth",
        "vertex_growth": "smoothed_normals_3d",
        "open_mesh_culling": "back_only_with_rear_bias",
        "stencil_required": false,
        "viewport_copies": 0
    }

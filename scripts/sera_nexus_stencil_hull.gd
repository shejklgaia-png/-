extends Node3D
## NEXUS auto-registration for grouped SERA silhouettes.
## All ordinary opaque armor pieces write stencil value 17, then the baked
## back-face hulls read the shared mask. Each copy is a SOURCE CHILD and
## inherits its pose in the same frame. No secondary camera/readback.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const HullGeometry = preload("res://scripts/sera_nexus_smooth_hull_geometry.gd")
const STENCIL_MASK_SHADER = preload("res://shaders/sera_nexus_stencil_mask.gdshader")
const STENCIL_HULL_SHADER = preload("res://shaders/sera_nexus_stencil_hull.gdshader")
const RESCAN_SECONDS: float = 0.35

var _root: Node3D
var _mask_material: ShaderMaterial
var _hull_material: ShaderMaterial
var _links: Dictionary = {}
var _baked_cache: Dictionary = {}
var _elapsed: float = 0.0
var _mode: int = 0
var _enabled: bool = true

func configure(source_rig: Node3D) -> void:
    _root = source_rig

func _ready() -> void:
    name = "SeraStencilHull"
    set_meta("sera_generated_live_edge", true)
    set_meta("FX_NO_OUTLINE", true)
    _mask_material = ShaderMaterial.new()
    _mask_material.shader = STENCIL_MASK_SHADER
    _mask_material.render_priority = -22
    _hull_material = ShaderMaterial.new()
    _hull_material.shader = STENCIL_HULL_SHADER
    _hull_material.render_priority = -21
    _hull_material.set_shader_parameter("outline_color", Color("#0b1118"))
    _hull_material.set_shader_parameter("outline_px", 3.0)
    _enabled = GraphicsSettings.get_enabled("character_outline")
    _rebuild_links()
    _apply_mode()
    set_process(true)

func _process(delta: float) -> void:
    _elapsed -= delta
    if _elapsed > 0.0:
        return
    _elapsed = RESCAN_SECONDS
    var enabled: bool = GraphicsSettings.get_enabled("character_outline")
    if enabled != _enabled:
        _enabled = enabled
        _apply_mode()
    if _enabled:
        _rebuild_links()

func set_diagnostic_mode(mode: int) -> void:
    _mode = clampi(mode, 0, 5)
    _apply_mode()

func _apply_mode() -> void:
    var draw_hull: bool = _enabled and (_mode == 0 or _mode == 1)
    var color: Color = (
        Color("#29f4f7") if _mode == 1 else Color("#0b1118"))
    if is_instance_valid(_hull_material):
        _hull_material.set_shader_parameter("outline_color", color)
    for entry in _links.values():
        var item: Dictionary = entry
        for role in ["mask", "hull"]:
            var draw: MeshInstance3D = item.get(role) as MeshInstance3D
            if is_instance_valid(draw):
                draw.visible = draw_hull

func _source_allowed(node: Node) -> bool:
    if bool(node.get_meta("sera_generated_live_edge", false)):
        return false
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return false
    var name_lower: String = str(node.name).to_lower()
    for excluded in ["swordeffect", "afterimage", "ghost", "beam",
            "trail", "particle", "smoke", "glow", "fx_"]:
        if name_lower.contains(excluded):
            return false
    return true

func _baked(mesh: Mesh) -> ArrayMesh:
    var id: int = mesh.get_instance_id()
    if _baked_cache.has(id):
        return _baked_cache[id] as ArrayMesh
    var result: ArrayMesh = HullGeometry.build(mesh)
    _baked_cache[id] = result
    return result

func _prepare_draw(source: MeshInstance3D, mesh: Mesh,
        mat: ShaderMaterial, role: String) -> MeshInstance3D:
    var draw := MeshInstance3D.new()
    draw.name = "SeraStencil_%s" % role
    draw.set_meta("sera_generated_live_edge", true)
    draw.set_meta("FX_NO_OUTLINE", true)
    draw.mesh = mesh
    draw.material_override = mat
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    draw.extra_cull_margin = 2.0
    draw.layers = source.layers
    source.add_child(draw)
    # Godot skin/bone arrays are preserved by HullGeometry.build().
    # Relative Skeleton NodePath changes when the copy becomes a child.
    var skeleton_path: NodePath = source.skeleton
    if not skeleton_path.is_empty():
        var skeleton_node: Node = source.get_node_or_null(skeleton_path)
        if is_instance_valid(skeleton_node):
            draw.skeleton = draw.get_path_to(skeleton_node)
            draw.skin = source.skin
    return draw

func _rebuild_links() -> void:
    if not is_instance_valid(_root):
        return
    var found: Dictionary = {}
    var pending: Array[Node] = [_root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node == self or not _source_allowed(node):
            continue
        if node is MeshInstance3D:
            var part: MeshInstance3D = node as MeshInstance3D
            if part.mesh != null and not (part.mesh is QuadMesh) and (
                    not (part.mesh is PlaneMesh)):
                found[part.get_instance_id()] = part
        for child in node.get_children():
            if child is Node3D:
                pending.append(child)
    for id in _links.keys():
        if found.has(id):
            continue
        var entry: Dictionary = _links[id]
        for role in ["mask", "hull"]:
            var obsolete: MeshInstance3D = entry.get(role) as MeshInstance3D
            if is_instance_valid(obsolete):
                obsolete.queue_free()
        _links.erase(id)
    var created: bool = false
    for id in found.keys():
        var part: MeshInstance3D = found[id] as MeshInstance3D
        var previous: Dictionary = _links.get(id, {})
        if previous.get("source_mesh") == part.mesh:
            if bool(previous.get("unsupported", false)):
                continue
            var old_mask: MeshInstance3D = previous.get(
                "mask") as MeshInstance3D
            var old_hull: MeshInstance3D = previous.get(
                "hull") as MeshInstance3D
            if is_instance_valid(old_mask) and is_instance_valid(old_hull):
                old_mask.layers = part.layers
                old_hull.layers = part.layers
                continue
        for role in ["mask", "hull"]:
            var old: MeshInstance3D = previous.get(role) as MeshInstance3D
            if is_instance_valid(old):
                old.queue_free()
        var baked_mesh: ArrayMesh = _baked(part.mesh)
        if baked_mesh == null:
            # Do not attempt to show a partially transformed outline for
            # unsupported blend shapes or oversized procedural meshes.
            _links[id] = {"source_mesh": part.mesh, "mask": null,
                "hull": null, "unsupported": true}
            continue
        var mask: MeshInstance3D = _prepare_draw(part, part.mesh,
            _mask_material, "Mask")
        var hull: MeshInstance3D = _prepare_draw(part, baked_mesh,
            _hull_material, "Hull")
        _links[id] = {"source_mesh": part.mesh,
            "mask": mask, "hull": hull}
        created = true
    if created:
        _apply_mode()

func get_stencil_snapshot() -> Dictionary:
    var hulls: int = 0
    var missing: int = 0
    for entry in _links.values():
        var item: Dictionary = entry
        if is_instance_valid(item.get("hull")):
            hulls += 1
        else:
            missing += 1
    return {"parts": _links.size(), "hulls": hulls,
        "unsupported": missing, "enabled": _enabled,
        "mode": _mode, "shared_stencil": 17}

extends Node
## Shared front-facing hard-corner pass: buildings have convex + concave
## 1px; small clutter has convex-only 1px; actors have none.
## RGB12 visible IDs retain ownership of silhouettes and mesh contacts.
## Cache separately per mesh and signed-corner mode.
const Crease = preload("res://scripts/sera_base_facility_crease_geometry.gd")
const INK = preload("res://shaders/sera_scene_convex_ink.gdshader")
const Standards = preload("res://scripts/sera_outline_standard.gd")

var _draws: Dictionary = {}  # source-instance:style -> {source,draw,mesh,indices,dynamic}
var _geometry_cache: Dictionary = {}  # mesh ID + concave mode -> ArrayMesh
var _materials: Dictionary = {}
var _scale: Vector2 = Vector2.ONE
var _id_texture: Texture2D


static func _role(source: Node) -> int:
    var cursor: Node = source
    while cursor != null:
        var value: String = str(cursor.get_meta("sera_outline_role", ""))
        match value:
            "facility", "grid": return 2
            "nexus_background": return 4
            "clutter": return 3
            "actor", "crate", "part": return 0
        if str(cursor.get_meta("sera_graphics_outline_category", "")) in [
                "character", "part"]:
            return 0
        cursor = cursor.get_parent()
    return 0


static func _style(role: int, scene_profile: int) -> int:
    if scene_profile == 4:
        if role == 4: return 5 # NEXUS background concave only
        if role == 2: return 6 # NEXUS interact convex + concave
    if role != 2 and role != 3:
        return 0
    if scene_profile == 2:
        return 1 if role == 2 else 4  # NEXUS facility both / clutter convex
    return 2 if role == 2 else 3  # BASE facility both / clutter convex


func _material(style: int) -> ShaderMaterial:
    if _materials.has(style):
        return _materials[style] as ShaderMaterial
    var mat := ShaderMaterial.new()
    mat.shader = INK
    mat.render_priority = -29  # after visible RGB-ID ink (-30), before VFX
    # Background concave ribbons render AFTER the ID veil, so grade
    # their color to match the veiled black seams. Do not alter the width,
    # 60-degree threshold or the black lines on interactive equipment.
    var ink_color: Color = Color("#17212f") if style == 1 or style == 4 else Color.BLACK
    if style == 5:
        ink_color = Color("#27343e")
    mat.set_shader_parameter("ink_color", ink_color)
    var width_px: float = Standards.BASE_FACILITY_CORNER_PX
    if style == 1:
        width_px = Standards.NEXUS_CORNER_PX
    elif style == 4:
        width_px = Standards.NEXUS_CONVEX_PX
    elif style == 3:
        width_px = Standards.BASE_CLUTTER_CONVEX_PX
    elif style == 5:
        width_px = Standards.NEXUS_BACKGROUND_CONCAVE_PX
    elif style == 6:
        width_px = Standards.NEXUS_INTERACT_CORNER_PX
    mat.set_shader_parameter("corner_width_px", width_px)
    mat.set_shader_parameter("output_px_per_render_pixel", _scale)
    mat.set_shader_parameter("outlines_enabled", true)
    mat.set_shader_parameter("protect_emission", style != 1 and style != 4)
    if _id_texture != null:
        mat.set_shader_parameter("emissive_id_texture", _id_texture)
    _materials[style] = mat
    return mat


func set_render_context(profile: int, texture: Texture2D,
        display_scale: Vector2) -> void:
    _id_texture = texture
    if not _scale.is_equal_approx(display_scale):
        _scale = display_scale
        for mat_value in _materials.values():
            var mat: ShaderMaterial = mat_value
            mat.set_shader_parameter("output_px_per_render_pixel", _scale)
    for mat_value in _materials.values():
        var mat: ShaderMaterial = mat_value
        if _id_texture != null:
            mat.set_shader_parameter("emissive_id_texture", _id_texture)


func _cached_geometry(mesh: Mesh, style: int) -> ArrayMesh:
    if mesh == null:
        return null
    var include_concave: bool = style in [1, 2, 5, 6]
    var include_convex: bool = style != 5
    var all_angles: bool = style == 6
    var concave_degrees: float = Standards.NEXUS_INTERACT_CORNER_DEGREES if all_angles else (Standards.NEXUS_CONCAVE_DEGREES if style == 5 else Crease.CONCAVE_CREASE_DEGREES)
    var convex_degrees: float = Standards.NEXUS_INTERACT_CORNER_DEGREES if all_angles else Crease.CONVEX_CREASE_DEGREES
    var key: String = "%d:%d:%d:%s:%s:%d" % [mesh.get_instance_id(), int(include_concave), int(include_convex), concave_degrees, convex_degrees, int(all_angles)]
    if not _geometry_cache.has(key):
        _geometry_cache[key] = Crease.build_corner_edges(mesh, include_concave, include_convex, concave_degrees, convex_degrees, all_angles)
    return _geometry_cache[key] as ArrayMesh


static func _dynamic_indices(source: MultiMeshInstance3D) -> Dictionary:
    var indices: Dictionary = {}
    var host: Node = source.get_parent()
    if host == null:
        return indices
    var motions: Dictionary = host.get_meta("motion_entries", {})
    var multi: MultiMesh = source.multimesh
    for group in motions.values():
        for record_value in group:
            var record: Dictionary = record_value
            if record.get("mesh") == multi:
                indices[int(record.get("index", -1))] = true
    return indices


func sync_sources(desired: Dictionary, profile: int, texture: Texture2D,
        display_scale: Vector2) -> void:
    set_render_context(profile, texture, display_scale)
    var wanted: Dictionary = {}
    for entry_value in desired.values():
        var entry: Dictionary = entry_value
        var source: Node3D = entry.get("node") as Node3D
        if not is_instance_valid(source) or (
                not source.is_visible_in_tree()):
            continue
        # Moving shutter leaves retain their dedicated selection contour.
        # Only their physical corner ribbons opt into the NEXUS pass.
        if bool(entry.get("occluder", false)) and not (
                profile == 4 and bool(source.get_meta("nexus_corner_only", false))):
            continue
        var source_mesh: Mesh = null
        var original_multi: MultiMesh = null
        if source is MeshInstance3D:
            source_mesh = (source as MeshInstance3D).mesh
        elif source is MultiMeshInstance3D:
            original_multi = (source as MultiMeshInstance3D).multimesh
            if original_multi != null:
                source_mesh = original_multi.mesh
        if source_mesh == null:
            continue
        # Filter actors/CRATE/parts BEFORE costly topology extraction.
        var default_role: int = _role(source)
        var mixed_roles: bool = original_multi != null and bool(
            source.get_meta("sera_outline_instanced_roles", false))
        if not mixed_roles and _style(default_role, profile) == 0:
            continue
        var instance_groups: Dictionary = {}
        if original_multi != null:
            var custom: bool = bool(source.get_meta(
                "sera_outline_instanced_roles", false))
            for index in range(original_multi.instance_count):
                var role: int = _role(source)
                if custom:
                    role = roundi(original_multi.get_instance_custom_data(index).r * 8.0)
                var style: int = _style(role, profile)
                if style == 0:
                    continue
                if not instance_groups.has(style):
                    instance_groups[style] = PackedInt32Array()
                var selected: PackedInt32Array = instance_groups[style]
                selected.append(index)
                instance_groups[style] = selected
        else:
            var style: int = _style(_role(source), profile)
            if style == 0:
                continue
            instance_groups[style] = PackedInt32Array()

        if instance_groups.is_empty():
            continue
        for style_value in instance_groups.keys():
            var style: int = int(style_value)
            var selected: PackedInt32Array = instance_groups[style]
            var ribbon: ArrayMesh = _cached_geometry(source_mesh, style)
            if ribbon == null:
                continue
            var key: String = "%d:%d" % [source.get_instance_id(), style]
            wanted[key] = true
            var existing: Dictionary = _draws.get(key, {})
            if existing.get("mesh") == source_mesh and (
                    existing.get("indices", PackedInt32Array()) == selected):
                var existing_draw: Node3D = existing.get("draw") as Node3D
                if is_instance_valid(existing_draw):
                    (existing_draw as GeometryInstance3D).material_override = (
                        _material(style))
                    (existing_draw as VisualInstance3D).layers = (
                        (source as VisualInstance3D).layers)
                    continue
            if not existing.is_empty():
                var gone: Node3D = existing.get("draw") as Node3D
                if is_instance_valid(gone):
                    gone.queue_free()
            var draw: GeometryInstance3D
            var source_to_overlay: Dictionary = {}
            if original_multi == null:
                var mesh_draw := MeshInstance3D.new()
                mesh_draw.mesh = ribbon
                draw = mesh_draw
            else:
                var overlay_multi := MultiMesh.new()
                overlay_multi.transform_format = MultiMesh.TRANSFORM_3D
                overlay_multi.mesh = ribbon
                overlay_multi.instance_count = selected.size()
                for position in range(selected.size()):
                    var original_index: int = selected[position]
                    overlay_multi.set_instance_transform(position,
                        original_multi.get_instance_transform(original_index))
                    source_to_overlay[original_index] = position
                var multi_draw := MultiMeshInstance3D.new()
                multi_draw.multimesh = overlay_multi
                draw = multi_draw
            draw.name = "SeraGlobalConvexInk_%d" % style
            draw.set_meta("FX_NO_OUTLINE", true)
            draw.set_meta("sera_skip_common_id_outline", true)
            draw.set_meta("sera_generated_live_edge", true)
            draw.material_override = _material(style)
            draw.layers = (source as VisualInstance3D).layers
            draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
            draw.extra_cull_margin = 0.1
            draw.physics_interpolation_mode = (
                Node.PHYSICS_INTERPOLATION_MODE_OFF)
            source.add_child(draw)
            if profile == 4 and original_multi != null:
                # Canonical placement is event driven, not per-frame.
                # Resource metadata points weakly to the live overlays.
                var links: Dictionary = original_multi.get_meta("nexus_corner_links", {})
                links[style] = {"draw": weakref(draw), "mapping": source_to_overlay}
                original_multi.set_meta("nexus_corner_links", links)
            _draws[key] = {"source": weakref(source), "draw": draw,
                "mesh": source_mesh, "indices": selected,
                "motion": _dynamic_indices(source as MultiMeshInstance3D)
                    if original_multi != null else {},
                "mapping": source_to_overlay}
    for key in _draws.keys():
        if wanted.has(key):
            continue
        var draw: Node3D = _draws[key].get("draw") as Node3D
        if is_instance_valid(draw):
            draw.queue_free()
        _draws.erase(key)


func sync_animated_multimeshes() -> void:
    # Animated base shutter/power source instances retain the EXACT original
    # per-instance pose; static batches do not cost a per-frame CPU copy.
    for record in _draws.values():
        var motion: Dictionary = record.get("motion", {})
        if motion.is_empty():
            continue
        var ref: WeakRef = record.get("source") as WeakRef
        var source: MultiMeshInstance3D = (
            ref.get_ref() as MultiMeshInstance3D if ref != null else null)
        var draw: MultiMeshInstance3D = record.get("draw") as MultiMeshInstance3D
        if not is_instance_valid(source) or not is_instance_valid(draw):
            continue
        if source.multimesh == null or draw.multimesh == null:
            continue
        var mapped: Dictionary = record.get("mapping", {})
        for index_value in motion.keys():
            var source_index: int = int(index_value)
            if not mapped.has(source_index):
                continue
            var target_index: int = int(mapped[source_index])
            var current_pose: Transform3D = (
                source.multimesh.get_instance_transform(source_index))
            if draw.multimesh.get_instance_transform(target_index) != current_pose:
                draw.multimesh.set_instance_transform(target_index, current_pose)


func get_draw_count() -> int:
    return _draws.size()


func clear() -> void:
    for record in _draws.values():
        var draw: Node3D = record.get("draw") as Node3D
        if is_instance_valid(draw):
            draw.queue_free()
    _draws.clear()
    _materials.clear()
    _geometry_cache.clear()


func _exit_tree() -> void:
    clear()

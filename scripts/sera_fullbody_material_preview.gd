extends RefCounted
## Shared material shading on every solid 3D scene (character, boss, base,
## NEXUS, LAB, warehouse and 3D previews). Authored assets remain untouched.
## Uses only solid original materials; FX, transparent surfaces and outlines
## keep their source passes and render order.
const OPEN_SHADER = preload("res://shaders/sera_fullbody_material_shading.gdshader")
const CLOSED_SHADER = preload("res://shaders/sera_fullbody_material_shading_closed.gdshader")
const BACK_SHADER = preload("res://shaders/sera_fullbody_material_shading_back.gdshader")
static var _white_texture: Texture2D
static var _shared_materials: Dictionary = {}
static var _monochrome_texture_cache: Dictionary = {}
const BODY_SLOTS: Array[String] = [
    "head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"
]
# SERA_IRIS_MATERIAL_SHADING_V1 supplied in chat on 2026-11-22.
const ARMOR_STEPS: int = 8
const ARMOR_THRESHOLD: float = 0.65
const MECHANISM_STEPS: int = 2
const MECHANISM_THRESHOLD: float = 0.70
const LENS_STEPS: int = 3
const LENS_THRESHOLD: float = 0.10
const LENS_LIT: bool = false


static func _is_monochrome_source(source: StandardMaterial3D) -> bool:
    # A solid-colored piece is ARMOR regardless of its tint, location or name.
    # Vertex-colored meshes are not considered monochrome by texture alone.
    if source.vertex_color_use_as_albedo:
        return false
    var texture: Texture2D = source.albedo_texture
    if texture == null:
        return true
    var texture_id: int = texture.get_instance_id()
    if _monochrome_texture_cache.has(texture_id):
        return bool(_monochrome_texture_cache[texture_id])
    # Current character palettes are 96x32 / 16x16. Do not read back large
    # environment atlases solely to infer their material family.
    if texture.get_width() * texture.get_height() > 65536:
        _monochrome_texture_cache[texture_id] = false
        return false
    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        _monochrome_texture_cache[texture_id] = false
        return false
    if image.is_compressed() and image.decompress() != OK:
        _monochrome_texture_cache[texture_id] = false
        return false
    var first: Color = image.get_pixel(0, 0)
    var same: bool = true
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var color: Color = image.get_pixel(x, y)
            if absf(color.r - first.r) > 0.008 or (
                    absf(color.g - first.g) > 0.008) or (
                    absf(color.b - first.b) > 0.008):
                same = false
                break
        if not same:
            break
    _monochrome_texture_cache[texture_id] = same
    return same


static func _part_material_hint(mesh: MeshInstance3D, slot: String) -> int:
    var source: StandardMaterial3D = mesh.material_override as StandardMaterial3D
    if source != null and _is_monochrome_source(source):
        return 1
    # Visual/location-based provisional assignments for MULTICOLOR pieces.
    # A single mesh may contain both body armor and mechanisms; per-pixel
    # palette classification in the shader has the final say.
    var labels: String = slot + " " + str(mesh.name)
    var parent: Node = mesh.get_parent()
    for depth in range(3):
        if parent == null:
            break
        labels += " " + str(parent.name)
        parent = parent.get_parent()
    labels = labels.to_lower()
    for word in ["lens", "optic", "cameraeye", "camera_eye", "eyepiece",
            "visor", "glass", "レンズ", "光学", "カメラアイ"]:
        if labels.contains(word):
            return 3
    for keyword in ["joint", "hinge", "piston", "shaft", "gear", "servo",
            "inner", "mechanism", "cable", "motor", "axle", "rubber",
            "connector", "elbow", "knee", "neck",
            "shin", "linkage", "actuator",
            "関節", "内部", "駆動", "軸", "機構"]:
        if labels.contains(keyword):
            return 2
    # Breastplates, helmets, limbs, frames, decorative shells and weapons
    # default to armor; the UV/palette still identifies dark and cyan pixels.
    return 1


static func _is_display_piece(mesh: MeshInstance3D) -> bool:
    if not is_instance_valid(mesh) or mesh.mesh == null or (
            mesh.mesh is QuadMesh or mesh.mesh is PlaneMesh):
        return false
    var cursor: Node = mesh
    while cursor != null:
        var label: String = str(cursor.name).to_lower()
        if label.contains("swordeffect") or label.contains("afterimage") or (
                label.contains("ghost")) or label.contains("slash") or (
                label.contains("exhaust")) or label.contains("flame") or (
                label.contains("particle")) or label.contains("smoke") or (
                label.contains("spark") ) or label.contains("laser") or (
                label.contains("beam") ) or label.contains("trail") or (
                label.contains("shockwave") ) or label.contains("gridbackdrop") or (
                label.contains("edgeink") ) or label.contains("overlay"):
            return false
        if bool(cursor.get_meta("sera_no_view_edges", false)) or (
                bool(cursor.get_meta("FX_NO_OUTLINE", false))):
            return false
        cursor = cursor.get_parent()
    var material: Material = mesh.material_override
    if not (material is StandardMaterial3D):
        return false
    var standard: StandardMaterial3D = material as StandardMaterial3D
    return standard.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED


static func apply_to_rig(rig: Node3D) -> Dictionary:
    var result: Dictionary = {"total": 0, "slots": {}, "sets": {}}
    if not is_instance_valid(rig):
        return result
    var equipment: Variant = rig.get("equipment_handler")
    if equipment == null:
        return result
    var available: Dictionary = equipment.get("available")
    var applied_mesh_ids: Dictionary = {}
    for set_key in available.keys():
        var selection: Dictionary = available[set_key]
        for slot in BODY_SLOTS:
            var count: int = 0
            for candidate in selection.get(slot, []):
                var mesh: MeshInstance3D = candidate as MeshInstance3D
                if not _is_display_piece(mesh):
                    if is_instance_valid(mesh):
                        _apply_native_flat(mesh)
                    continue
                var mesh_id: int = mesh.get_instance_id()
                if applied_mesh_ids.has(mesh_id):
                    continue
                var shaded: ShaderMaterial = _make_shaded_material(
                    mesh, _part_material_hint(mesh, slot), false)
                if shaded == null:
                    continue
                mesh.material_override = shaded
                applied_mesh_ids[mesh_id] = true
                count += 1
                result["total"] = int(result["total"]) + 1
            if count > 0:
                var summary_key: String = str(set_key) + "/" + slot
                result["sets"][summary_key] = count
                result["slots"][slot] = int(result["slots"].get(slot, 0)) + count
    # SeraRig's 3px ViewEdges still owns contours, excluding effect meshes.
    return result


static func _white() -> Texture2D:
    if not is_instance_valid(_white_texture):
        var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _white_texture = ImageTexture.create_from_image(img)
    return _white_texture


static func _make_shaded_material(geometry: GeometryInstance3D,
        hint: int, preserve_per_object: bool) -> ShaderMaterial:
    var source: StandardMaterial3D = geometry.material_override as StandardMaterial3D
    if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (
            source.albedo_color.a < 0.999):
        return null
    # Opaque material with a special rendering pass retains it as next_pass.
    # Transparent/high-energy visuals are filtered by caller name/metadata.
    # Native emitting meshes may be animated (railgun charging, muzzle,
    # holograms). Preserve their original material object and live controls.
    # emission has zero shading steps in the supplied preset.
    if source.emission_enabled:
        geometry.set_meta("sera_no_view_edges", true)
        return null
    var texture: Texture2D = source.albedo_texture
    if texture == null:
        texture = _white()
    var iris_atlas: bool = texture.get_width() == 16 and texture.get_height() == 16
    var armor_only: bool = _is_monochrome_source(source)
    var baked_palette: bool = (not armor_only and
        texture.get_width() == 96 and texture.get_height() == 32)
    var cull: int = source.cull_mode
    var scene_min_brightness: float = clampf(float(
        geometry.get_meta("sera_scene_min_brightness", 0.0)), 0.0, 1.0)
    var next_id: int = (source.next_pass.get_instance_id()
        if source.next_pass != null else 0)
    var key: String = str([
        texture.get_instance_id(), source.albedo_color.to_html(true),
        hint, cull, int(iris_atlas), int(armor_only), int(baked_palette), next_id,
        source.emission.to_html(true) if source.emission_enabled else "none",
        source.emission_energy_multiplier if source.emission_enabled else 0.0,
        source.vertex_color_use_as_albedo, source.uv1_scale, source.uv1_offset,
        scene_min_brightness
    ])
    var shaded: ShaderMaterial = _shared_materials.get(key) as ShaderMaterial
    if shaded == null or preserve_per_object:
        shaded = ShaderMaterial.new()
        shaded.shader = (CLOSED_SHADER if cull == BaseMaterial3D.CULL_FRONT else
            (BACK_SHADER if cull == BaseMaterial3D.CULL_BACK else OPEN_SHADER))
        shaded.set_shader_parameter("source_texture", texture)
        shaded.set_shader_parameter("source_tint", source.albedo_color)
        shaded.set_shader_parameter("iris_palette", iris_atlas)
        shaded.set_shader_parameter("force_armor", armor_only)
        shaded.set_shader_parameter("baked_palette", baked_palette)
        shaded.set_shader_parameter("material_hint", hint)
        shaded.set_shader_parameter("armor_levels", ARMOR_STEPS)
        shaded.set_shader_parameter("armor_threshold", ARMOR_THRESHOLD)
        shaded.set_shader_parameter("dark_levels", MECHANISM_STEPS)
        shaded.set_shader_parameter("dark_threshold", MECHANISM_THRESHOLD)
        shaded.set_shader_parameter("lens_levels", LENS_STEPS)
        shaded.set_shader_parameter("lens_threshold", LENS_THRESHOLD)
        shaded.set_shader_parameter("lens_emissive", LENS_LIT)
        shaded.set_shader_parameter("texture_uv_scale",
            Vector2(source.uv1_scale.x, source.uv1_scale.y))
        shaded.set_shader_parameter("texture_uv_offset",
            Vector2(source.uv1_offset.x, source.uv1_offset.y))
        shaded.set_shader_parameter("use_vertex_color",
            source.vertex_color_use_as_albedo)
        shaded.set_shader_parameter(
            "scene_min_brightness", scene_min_brightness)
        shaded.set_shader_parameter("fx_emission", Vector3(source.emission.r,
            source.emission.g, source.emission.b) * (
            source.emission_energy_multiplier if source.emission_enabled else 0.0))
        shaded.next_pass = source.next_pass
        shaded.render_priority = source.render_priority
        if not preserve_per_object:
            _shared_materials[key] = shaded
    return shaded



# Native physically lit solids (notably BASE buildings) must keep the real
# StandardMaterial3D and work lights. Only their geometric normals change.
# Cache by source mesh, not by instance; no extra passes or periodic scans.
static var _native_flat_cache: Dictionary = {}

static func _native_lit(material: Material) -> bool:
    if material == null:
        return true
    var native: BaseMaterial3D = material as BaseMaterial3D
    return native != null and (
        native.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED) and (
        native.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED)

static func _flat_native_mesh(source: Mesh) -> Mesh:
    if source == null or source is BoxMesh or source is QuadMesh or (
            source is PlaneMesh) or source is PointMesh or (
            not (source is ArrayMesh or source is PrimitiveMesh)) or (
            source is ArrayMesh and (source as ArrayMesh).get_blend_shape_count() > 0) or (
            source.get_meta("sera_flat_face_mesh", false)):
        return source
    var key: int = source.get_instance_id()
    if _native_flat_cache.has(key):
        var entry: Array = _native_flat_cache[key]
        if entry[0].get_ref() == source:
            var cached: Mesh = entry[1].get_ref() as Mesh
            if cached != null:
                return cached
    var output := ArrayMesh.new()
    var changed: bool = false
    for surface in range(source.get_surface_count()):
        var primitive: int = Mesh.PRIMITIVE_TRIANGLES
        var flags: int = 0
        if source is ArrayMesh:
            var array_source: ArrayMesh = source as ArrayMesh
            primitive = array_source.surface_get_primitive_type(surface)
            # Preserve custom channel format bits and 8-weight layout.
            flags = array_source.surface_get_format(surface) & (
                ((1 << 25) - (1 << 13)) | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
        var arrays: Array = source.surface_get_arrays(surface)
        if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null:
            return source
        if primitive == Mesh.PRIMITIVE_TRIANGLES and (
                arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var normals: PackedVector3Array = PackedVector3Array()
            if arrays[Mesh.ARRAY_NORMAL] != null:
                normals = arrays[Mesh.ARRAY_NORMAL]
            var indices := PackedInt32Array()
            if arrays[Mesh.ARRAY_INDEX] != null:
                indices = arrays[Mesh.ARRAY_INDEX]
            if indices.is_empty():
                indices.resize(vertices.size())
                for i in range(vertices.size()):
                    indices[i] = i
            var needs_flat: bool = normals.size() != vertices.size()
            if indices.size() % 3 != 0 or vertices.is_empty():
                return source
            var face_normals := PackedVector3Array()
            face_normals.resize(indices.size())
            for i in range(0, indices.size(), 3):
                var ia: int = indices[i]
                var ib: int = indices[i + 1]
                var ic: int = indices[i + 2]
                # Godot mesh front faces use clockwise winding.
                var n: Vector3 = (vertices[ic] - vertices[ia]).cross(
                    vertices[ib] - vertices[ia]).normalized()
                if n.is_zero_approx():
                    n = normals[ia] if normals.size() == vertices.size() else Vector3.UP
                for j in range(3):
                    face_normals[i + j] = n
                    if normals.size() == vertices.size() and (
                            normals[indices[i + j]].dot(n) < 0.99999):
                        needs_flat = true
            if needs_flat:
                # Preserve UV, vertex paint, tangent, skin and custom channels.
                # Unindex only surfaces that actually have interpolated normals.
                var flat_arrays: Array = arrays.duplicate()
                for slot in range(Mesh.ARRAY_INDEX):
                    if slot == Mesh.ARRAY_NORMAL or arrays[slot] == null:
                        continue
                    var channel: Variant = arrays[slot]
                    if channel.size() == 0:
                        continue
                    if channel.size() % vertices.size() != 0:
                        return source
                    var stride: int = int(channel.size() / vertices.size())
                    var expanded: Variant = channel.duplicate()
                    expanded.resize(indices.size() * stride)
                    for i in range(indices.size()):
                        for component in range(stride):
                            expanded[i * stride + component] = channel[
                                indices[i] * stride + component]
                    flat_arrays[slot] = expanded
                flat_arrays[Mesh.ARRAY_NORMAL] = face_normals
                flat_arrays[Mesh.ARRAY_INDEX] = null
                # Keep the tangent basis orthogonal to the new face normal.
                if flat_arrays[Mesh.ARRAY_TANGENT] != null:
                    var tangents: PackedFloat32Array = flat_arrays[Mesh.ARRAY_TANGENT]
                    if tangents.size() == indices.size() * 4:
                        for i in range(indices.size()):
                            var t: Vector3 = Vector3(tangents[i * 4],
                                tangents[i * 4 + 1], tangents[i * 4 + 2])
                            var n: Vector3 = face_normals[i]
                            t = (t - n * n.dot(t)).normalized()
                            if t.is_zero_approx():
                                t = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
                            tangents[i * 4] = t.x
                            tangents[i * 4 + 1] = t.y
                            tangents[i * 4 + 2] = t.z
                        flat_arrays[Mesh.ARRAY_TANGENT] = tangents
                arrays = flat_arrays
                changed = true
        output.add_surface_from_arrays(primitive, arrays, [], {}, flags)
        if output.get_surface_count() != surface + 1:
            return source
        output.surface_set_material(surface, source.surface_get_material(surface))
        if source is ArrayMesh:
            output.surface_set_name(surface, (source as ArrayMesh).surface_get_name(surface))
    var result: Mesh = output if changed else source
    if changed:
        output.resource_name = source.resource_name
        if source is ArrayMesh:
            output.custom_aabb = (source as ArrayMesh).custom_aabb
        output.set_meta("sera_flat_face_mesh", true)
    if _native_flat_cache.size() >= 2048:
        # Bound the cache; nodes/multimeshes still own their converted resource.
        _native_flat_cache.clear()
    _native_flat_cache[key] = [weakref(source), weakref(result)]
    return result

static func _apply_native_flat(node: GeometryInstance3D) -> void:
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return
    if node is MultiMeshInstance3D:
        var batch_node: MultiMeshInstance3D = node as MultiMeshInstance3D
        var batch: MultiMesh = batch_node.multimesh
        if batch == null or batch.mesh == null:
            return
        var material: Material = node.material_override
        if material != null:
            if not _native_lit(material):
                return
        else:
            for i in range(batch.mesh.get_surface_count()):
                if not _native_lit(batch.mesh.surface_get_material(i)):
                    return
        var flat: Mesh = _flat_native_mesh(batch.mesh)
        if flat != batch.mesh:
            batch.mesh = flat
    elif node is MeshInstance3D:
        var mesh_node: MeshInstance3D = node as MeshInstance3D
        var source: Mesh = mesh_node.mesh
        if source == null:
            return
        var overrides: Array[Material] = []
        for i in range(source.get_surface_count()):
            if not _native_lit(mesh_node.get_active_material(i)):
                return
            overrides.append(mesh_node.get_surface_override_material(i))
        var flat: Mesh = _flat_native_mesh(source)
        if flat != source:
            mesh_node.mesh = flat
            for i in range(overrides.size()):
                mesh_node.set_surface_override_material(i, overrides[i])

static func _apply_subtree_node(node: Node, preserve_per_object: bool) -> int:
    var changed: int = 0
    if node is MeshInstance3D:
        var mesh: MeshInstance3D = node as MeshInstance3D
        if _is_display_piece(mesh):
            var styled: ShaderMaterial = _make_shaded_material(mesh,
                _part_material_hint(mesh, ""), preserve_per_object)
            if styled != null:
                mesh.material_override = styled
                changed += 1
    elif node is MultiMeshInstance3D:
        var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
        if batch.multimesh != null and batch.multimesh.mesh != null and (
                not batch.multimesh.mesh is QuadMesh) and (
                not batch.multimesh.mesh is PlaneMesh) and (
                batch.material_override is StandardMaterial3D) and (
                not bool(batch.get_meta("FX_NO_OUTLINE", false))) and (
                not bool(batch.get_meta(
                    "sera_preserve_authored_material", false))):
            var src: StandardMaterial3D = batch.material_override as StandardMaterial3D
            if src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
                var batch_material: ShaderMaterial = _make_shaded_material(
                    batch, _part_material_hint_batch(batch), false)
                if batch_material != null:
                    batch.material_override = batch_material
                    changed += 1
    if node is MeshInstance3D or node is MultiMeshInstance3D:
        _apply_native_flat(node as GeometryInstance3D)
    return changed


static func apply_to_subtree(root: Node3D, preserve_per_object: bool = false) -> int:
    if not is_instance_valid(root):
        return 0
    var changed: int = 0
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        changed += _apply_subtree_node(node, preserve_per_object)
        for child in node.get_children():
            if child is Node3D and child.name not in ["ViewEdges", "SeraEdgeInk"]:
                pending.append(child)
    return changed


static func apply_to_subtree_budgeted(root: Node3D,
        preserve_per_object: bool = false, budget: Variant = null) -> int:
    # One-shot scene build hook, no recurring tree scan or extra draw target.
    # SERA/BitTaran have their own ViewEdges; architecture keeps its authored
    # silhouette + front-crease meshes. FX shaders are never replaced.
    if not is_instance_valid(root):
        return 0
    var changed: int = 0
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        if budget != null:
            await budget.checkpoint("material shading")
        var node: Node = pending.pop_back()
        changed += _apply_subtree_node(node, preserve_per_object)
        for child in node.get_children():
            if child is Node3D and child.name not in ["ViewEdges", "SeraEdgeInk"]:
                pending.append(child)
    return changed


static func _part_material_hint_batch(mesh: MultiMeshInstance3D) -> int:
    var native: StandardMaterial3D = mesh.material_override as StandardMaterial3D
    if native != null and _is_monochrome_source(native):
        return 1
    var label: String = str(mesh.name).to_lower()
    for word in ["hinge", "shaft", "joint", "piston", "mechanism",
            "motor", "cable", "gear", "drive", "servo", "軸", "内部"]:
        if label.contains(word):
            return 2
    return 1

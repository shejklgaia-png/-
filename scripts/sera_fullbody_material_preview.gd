extends RefCounted
## NEXUS exhibition SERA only. Apply authored user IRIS material numbers to all
## installed and switchable body/weapon meshes with provisional palette/part
## classification. Leave training/combat, icons, LAB and master BB files alone.
const OPEN_SHADER = preload("res://shaders/sera_fullbody_material_shading.gdshader")
const CLOSED_SHADER = preload("res://shaders/sera_fullbody_material_shading_closed.gdshader")
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


static func _part_material_hint(mesh: MeshInstance3D, slot: String) -> int:
    # Visual/location-based provisional assignments (not an authored master).
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
    for keyword in ["joint", "hinge", "piston", "shaft", "gear", "servo",
            "inner", "mechanism", "cable", "motor", "axle", "rubber",
            "connector", "waist", "elbow", "knee", "neck", "pivot",
            "関節", "内部", "駆動", "軸"]:
        if labels.contains(keyword):
            return 2
    # Breastplates, helmets, limbs, frames, decorative shells and weapons
    # default to armor; the UV/palette still identifies dark and cyan pixels.
    return 1


static func _is_display_piece(mesh: MeshInstance3D) -> bool:
    if not is_instance_valid(mesh) or mesh.mesh == null:
        return false
    var cursor: Node = mesh
    while cursor != null:
        var label: String = str(cursor.name).to_lower()
        if label.contains("swordeffect") or label.contains("afterimage") or (
                label.contains("ghost")) or label.contains("slash") or (
                label.contains("exhaust")) or label.contains("flame"):
            return false
        if bool(cursor.get_meta("sera_no_view_edges", false)):
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
    # Identical texture + tint + culling + rough classification share one
    # ShaderMaterial. No per-mesh duplicate shader resources or extra pass.
    var material_cache: Dictionary = {}
    var applied_mesh_ids: Dictionary = {}
    # Several authored solid details have only an albedo tint. A 1x1 white
    # texture passes that base color into the common sampler without skipping
    # those meshes or changing their original Godot material resources.
    var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    white_image.fill(Color.WHITE)
    var white_texture: ImageTexture = ImageTexture.create_from_image(white_image)
    for set_key in available.keys():
        var selection: Dictionary = available[set_key]
        for slot in BODY_SLOTS:
            var count: int = 0
            for candidate in selection.get(slot, []):
                var mesh: MeshInstance3D = candidate as MeshInstance3D
                if not _is_display_piece(mesh):
                    continue
                var mesh_id: int = mesh.get_instance_id()
                if applied_mesh_ids.has(mesh_id):
                    continue
                var source: StandardMaterial3D = mesh.material_override as StandardMaterial3D
                var original_texture: Texture2D = source.albedo_texture
                if original_texture == null:
                    original_texture = white_texture
                var hint: int = _part_material_hint(mesh, slot)
                var closed: bool = bool(mesh.get_meta("sera_single_sided", false))
                var key: String = "%d:%s:%d:%d" % [
                    original_texture.get_instance_id(),
                    source.albedo_color.to_html(true), hint, int(closed)
                ]
                var shaded: ShaderMaterial = material_cache.get(key) as ShaderMaterial
                if shaded == null:
                    shaded = ShaderMaterial.new()
                    shaded.shader = CLOSED_SHADER if closed else OPEN_SHADER
                    shaded.set_shader_parameter("source_texture", original_texture)
                    shaded.set_shader_parameter("source_tint", source.albedo_color)
                    shaded.set_shader_parameter("material_hint", hint)
                    shaded.set_shader_parameter("armor_levels", ARMOR_STEPS)
                    shaded.set_shader_parameter("armor_threshold", ARMOR_THRESHOLD)
                    shaded.set_shader_parameter("dark_levels", MECHANISM_STEPS)
                    shaded.set_shader_parameter("dark_threshold", MECHANISM_THRESHOLD)
                    shaded.set_shader_parameter("lens_levels", LENS_STEPS)
                    shaded.set_shader_parameter("lens_threshold", LENS_THRESHOLD)
                    shaded.set_shader_parameter("lens_emissive", LENS_LIT)
                    material_cache[key] = shaded
                mesh.material_override = shaded
                applied_mesh_ids[mesh_id] = true
                count += 1
                result["total"] = int(result["total"]) + 1
            if count > 0:
                var summary_key: String = str(set_key) + "/" + slot
                result["sets"][summary_key] = count
                result["slots"][slot] = int(result["slots"].get(slot, 0)) + count
    # SeraRig already installs its current 3px view-dependent ink on all
    # equipment MeshInstances; keep that shader and geometry unchanged.
    # The existing ink still ignores transparency/FX and follows animation.
    return result

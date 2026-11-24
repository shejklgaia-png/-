extends RefCounted
## Fixed-cost BASE lighting: preserve six existing steel deck MultiMeshes.
## The optional patches are 2 transparent MultiMesh draws (8 instances each).
## No dynamic lights, shadow maps, per-frame CPU work or viewport are added.
const DECK_SHADER = preload("res://shaders/sera_base_deck_lighting.gdshader")
const PATCH_SHADER = preload("res://shaders/sera_base_floor_patch.gdshader")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")

const SPILL_TINTS: Dictionary = {
    "NEXUS": "#b9e4fa",
    "LABO": "#dfc19f",
    "SCRAP_COLLECTOR": "#a3cce8",
    "SMELTER": "#efa76c",
    "RECYCLER": "#e0bc94",
    "GENERATOR": "#7ebfdf",
    "STORAGE": "#dcc49a",
    "BUILD_TERMINAL": "#a2d3e9",
}
static var _white_texture: Texture2D

static func _plain_white() -> Texture2D:
    if _white_texture == null:
        var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _white_texture = ImageTexture.create_from_image(img)
    return _white_texture

static func deck_material(source: StandardMaterial3D) -> ShaderMaterial:
    var output := ShaderMaterial.new()
    output.shader = DECK_SHADER
    var tex: Texture2D = source.albedo_texture
    output.set_shader_parameter("source_texture",
        tex if tex != null else _plain_white())
    output.set_shader_parameter("source_tint", source.albedo_color)
    output.set_shader_parameter("texture_uv_scale",
        Vector2(source.uv1_scale.x, source.uv1_scale.y))
    output.set_shader_parameter("texture_uv_offset",
        Vector2(source.uv1_offset.x, source.uv1_offset.y))
    return output

# One silver steel finish for the BASE site slabs and full-size work decks.
const WORKSITE_SILVER := Color("#87939d")
const WORKSITE_SILVER_ALT := Color("#76838e")
const WORKSITE_TEXTURE := "res://assets/base/industrial_deck_wear.svg"

static func worksite_material(alternate: bool = false, base_framing: bool = false) -> ShaderMaterial:
    var source := StandardMaterial3D.new()
    source.albedo_color = WORKSITE_SILVER_ALT if alternate else WORKSITE_SILVER
    if ResourceLoader.exists(WORKSITE_TEXTURE):
        source.albedo_texture = load(WORKSITE_TEXTURE) as Texture2D
    var mat := deck_material(source)
    # Keep the BASE-specific floor framing only in the BASE camera.
    if not base_framing:
        mat.set_shader_parameter("top_edge_darkness",0.0)
        mat.set_shader_parameter("lower_corner_darkness",0.0)
    return mat

static func _make_patch_batch(root: Node3D, name: String,
        patches: Array[Dictionary], tint_strength: float) -> void:
    if patches.is_empty():
        return
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = patches.size()
    for i in range(patches.size()):
        var entry: Dictionary = patches[i]
        var span: Vector2 = entry["span"]
        var center: Vector3 = entry["center"]
        var tint: Color = entry["tint"]
        # +Y facing, deck top at -0.03m. Below the raised panel details.
        var basis := Basis(Vector3.RIGHT, -PI * 0.5).scaled_local(
            Vector3(span.x, span.y, 1.0))
        multi.set_instance_transform(i, Transform3D(
            basis, Vector3(center.x, -0.019, center.z)))
        multi.set_instance_custom_data(i, Color(
            tint.r, tint.g, tint.b, tint.a * tint_strength))
    var draw := MultiMeshInstance3D.new()
    draw.name = name
    draw.set_meta("FX_NO_OUTLINE", true)
    draw.set_meta("sera_no_view_edges", true)
    draw.multimesh = multi
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    var mat := ShaderMaterial.new()
    mat.shader = PATCH_SHADER
    # Behind the existing additive VFX and light shafts, not in their ID pass.
    mat.render_priority = -16
    draw.material_override = mat
    root.add_child(draw)

static func add_floor_accents(floor: Node3D, nexus_at: Vector3,
        facility_specs: Array) -> void:
    var root := Node3D.new()
    root.name = "DeckLightingAccents"
    root.set_meta("FX_NO_OUTLINE", true)
    root.set_meta("sera_no_view_edges", true)
    floor.add_child(root)
    var locations: Array[Dictionary] = [{
        "id": "NEXUS", "at": nexus_at,
        "size": Vector3(7.0, 0.0, 7.6),
    }]
    for spec in facility_specs:
        locations.append({
            "id": str(spec["id"]), "at": spec["at"],
            "size": spec["size"],
        })
    var shadows: Array[Dictionary] = []
    var spills: Array[Dictionary] = []
    for site in locations:
        var key: String = str(site["id"])
        var center: Vector3 = site["at"]
        var body: Vector3 = site["size"]
        var large: bool = key == "NEXUS"
        # Soft weight around structural feet, without expensive real shadows.
        shadows.append({
            "center": center,
            "span": Vector2(
                maxf(body.x * 2.18, 7.5),
                maxf(body.z * 2.24, 7.5)),
            "tint": Color(0.035, 0.055, 0.072, 0.31 if large else 0.24),
        })
        # A restrained reflected wash extends just in front of each lamp.
        # Existing spotlights, searchlight shafts and fire stay authoritative.
        var yaw: float = BaseArchitecture.facility_yaw_radians(key)
        var forward := Vector3(sin(yaw), 0.0, cos(yaw))
        var offset: float = 3.7 if large else 2.2
        var tint := Color(str(SPILL_TINTS.get(key, "#a6c4d7")))
        spills.append({
            "center": center + forward * offset,
            "span": Vector2(
                maxf(body.x * 2.4, 7.7),
                maxf(body.z * 2.6, 8.5)),
            "tint": Color(tint.r, tint.g, tint.b,
                0.12 if large else 0.09),
        })
    _make_patch_batch(root, "SoftContactShade", shadows, 1.0)
    _make_patch_batch(root, "SoftFacilityFloorBounce", spills, 1.0)

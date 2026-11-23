extends Node3D
## Separate FX-only graph, NEVER collected into the architectural outline mask.
## CPU chimney plumes are GL Compatibility safe; all light shafts are unshaded
## additive quads. Main solid MultiMesh and archived NEXUS remain untouched.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const PORTALS: Dictionary = {
    "NEXUS": {"at": Vector3(0, 1.64, 2.95), "size": Vector2(2.10, 2.25),
        "color": Color("#c9eaff")},
    "LABO": {"at": Vector3(0, 1.65, 1.75), "size": Vector2(2.55, 2.35),
        "color": Color("#ffd7a4")},
    "SCRAP_COLLECTOR": {"at": Vector3(-0.20, 1.02, 1.43),
        "size": Vector2(1.40, 1.40), "color": Color("#b1dcff")},
    "SMELTER": {"at": Vector3(0, 1.45, 1.27), "size": Vector2(1.42, 1.11),
        "color": Color("#ffa265")},
    "RECYCLER": {"at": Vector3(0, 1.48, 1.28), "size": Vector2(1.67, 1.44),
        "color": Color("#ffd2ac")},
    "GENERATOR": {"at": Vector3(-0.27, 1.43, 1.15),
        "size": Vector2(1.98, 1.35), "color": Color("#84d8ff")},
    "STORAGE": {"at": Vector3(0.01, 1.45, 1.24),
        "size": Vector2(1.80, 1.54), "color": Color("#ffe0b2")},
    "BUILD_TERMINAL": {"at": Vector3(0, 1.85, 0.60),
        "size": Vector2(1.53, 1.00), "color": Color("#a3e2ff")},
}
const SHAFT_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 hue : source_color = vec4(0.62, 0.82, 1.0, 0.72);
uniform float floor_mode = 0.0;
void fragment() {
    float radial = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 2.0), 2.1);
    float vertical = floor_mode > 0.5
        ? (1.0 - smoothstep(0.34, 1.0, UV.y))
        : smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.83, 1.0, UV.y));
    float breathing = 0.92 + 0.08 * sin(TIME * 2.17);
    float falloff = radial * vertical * breathing;
    ALBEDO = hue.rgb;
    EMISSION = hue.rgb * 2.8 * falloff;
    ALPHA = hue.a * falloff;
}
"""
const POOL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 glow_tint : source_color = vec4(0.64, 0.84, 1.0, 0.32);
void fragment() {
    vec2 rad = UV * 2.0 - vec2(1.0);
    float round_pool = pow(max(0.0, 1.0 - dot(rad, rad)), 2.6);
    ALBEDO = glow_tint.rgb;
    // The earlier subtle pool was virtually invisible at BASE overview zoom.
    // Keep falloff compact, but make its illuminated center legible.
    // Stronger readable local pools without adding lights or draw passes.
    EMISSION = glow_tint.rgb * round_pool * 5.2;
    ALPHA = clamp(glow_tint.a * round_pool * 1.15, 0.0, 1.0);
}
"""
# NEXUS shutter: a narrow projected strip, bright at the airlock and
# fading down the long axis. Rotating the quad -90 degrees around X puts
# local +Y at world -Z: the near (+Y) shutter edge is UV.y=0,
# while the far (world +Z) edge is UV.y=1.
const NEXUS_SHUTTER_BEAM_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 beam_tint : source_color = vec4(0.73, 0.92, 1.0, 0.72);
void fragment() {
    // 0 at the shutter, 1 at the distant tip. Prior UV inversion
    // incorrectly illuminated the far tip and dimmed the entrance.
    float longitudinal = clamp(UV.y, 0.0, 1.0);
    float side = abs(UV.x - 0.5) * 2.0;
    float transverse = 1.0 - smoothstep(0.61, 0.99, side);
    float reach = 1.0 - smoothstep(0.09, 1.0, longitudinal);
    float band = transverse * pow(reach, 1.20);
    ALBEDO = beam_tint.rgb;
    EMISSION = beam_tint.rgb * band * 6.2;
    ALPHA = clamp(beam_tint.a * band, 0.0, 1.0);
}
"""
static var _pool_shader: Shader
static var _nexus_shutter_beam_shader: Shader
static var _shaft_shader: Shader
static var _fire_floor_shader: Shader
static var _smoke_material: StandardMaterial3D

# A screen-readable additive slit interior, exclusively for the GENERATOR.
# The brightest filament stays at each gap center; feathered edges create
# a contained glow instead of washing the entire machine blue.
const GENERATOR_GAP_LEAK_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
    float horizontal = abs(UV.x - 0.5) * 2.0;
    float vertical = abs(UV.y - 0.5) * 2.0;
    float ends = 1.0 - smoothstep(0.73, 1.0, horizontal);
    float halo = 1.0 - smoothstep(0.54, 1.0, vertical);
    float center = 1.0 - smoothstep(0.10, 0.48, vertical);
    float light = ends * (0.48 * halo + 0.52 * center);
    vec3 ice_blue = vec3(0.62, 0.91, 1.0);
    ALBEDO = ice_blue;
    EMISSION = ice_blue * light * 9.5;
    ALPHA = clamp(light * 0.94, 0.0, 1.0);
}
"""
static var _generator_gap_leak_shader: Shader

# A visible projector shaft is NOT a real volumetric light pass: three
# crossed, tapered planes use the same forward vector as SpotLight3D. Their
# soft shape is depth-tested against buildings and batched once per site.
const SEARCHLIGHT_SHAFT_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
varying vec4 shaft_tint;
void vertex() {
    shaft_tint = INSTANCE_CUSTOM;
}
void fragment() {
    float side = abs(UV.x * 2.0 - 1.0);
    float soft_edge = 1.0 - smoothstep(0.42, 0.99, side);
    float center = pow(max(0.0, 1.0 - side), 2.0);
    float along = clamp(UV.y, 0.0, 1.0);
    // The fixture contains the first few centimetres. The beam remains
    // legible down to its intended work point, without a hard cut-off.
    float start = smoothstep(0.01, 0.09, along);
    // Preserve the broad fan almost to the impact point; the final tip
    // still fades smoothly instead of showing a hard polygon edge.
    float end_fade = 1.0 - smoothstep(0.90, 1.0, along);
    float light = (0.56 * soft_edge + 0.44 * center) *
        start * end_fade * (0.96 - 0.18 * along);
    ALBEDO = shaft_tint.rgb;
    EMISSION = shaft_tint.rgb * light * 1.65;
    ALPHA = clamp(shaft_tint.a * light, 0.0, 0.30);
}
"""
static var _searchlight_shaft_shader: Shader
static var _searchlight_shaft_material: ShaderMaterial
static var _searchlight_shaft_mesh: ArrayMesh
var _searchlight_shafts: Array[Dictionary] = []

# Runtime-generated 24x24 radial alpha tile, shared by every BASE facility.
# One small MultiMesh draw per facility replaces fullscreen bloom/blur.
const SOFT_HALO_SHADER: String = """
shader_type spatial;
// RENDER_POLICY: FACILITY_VFX_FOREGROUND; depth_test=on
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D soft_halo_mask : source_color, filter_linear, repeat_disable;
// Raise the soft fringe without overexposing the sharp authored light core.
uniform float halo_strength : hint_range(0.5, 3.0) = 1.8;
varying vec4 halo_tint;
void vertex() {
    halo_tint = INSTANCE_CUSTOM;
}
void fragment() {
    float mask = texture(soft_halo_mask, UV).a;
    ALBEDO = halo_tint.rgb;
    ALPHA = clamp(halo_tint.a * mask * halo_strength, 0.0, 0.7);
}
"""
static var _soft_halo_texture: ImageTexture
static var _soft_halo_material: ShaderMaterial
# All bright authored line details share one draw call per facility. Bound
# the number of tiny quads to avoid screen-wide translucent overdraw.
const MAX_SOFT_HALO_PATCHES: int = 160
var _soft_halos: Array[Dictionary] = []

const FIRE_FLOOR_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
    vec2 p = UV;
    float longfade = 1.0 - smoothstep(0.27, 1.0, p.y);
    float crossfade = pow(max(0.0, 1.0 - abs(p.x - 0.5) * 2.0), 1.25);
    float tongues = 0.72 + 0.18 * sin(TIME * 7.1 + p.x * 8.0)
        + 0.10 * sin(TIME * 11.3 - p.y * 12.0 + p.x * 14.0);
    float shaped = crossfade * longfade * clamp(tongues, 0.25, 1.0);
    vec3 orange = mix(vec3(1.0, 0.19, 0.035),
        vec3(1.0, 0.61, 0.22), clamp(shaped * 1.4, 0.0, 1.0));
    ALBEDO = orange;
    EMISSION = orange * 3.2 * shaped;
    ALPHA = shaped * 0.72;
}
"""
var _model: Node3D
var _furnace_lamp: OmniLight3D
var _elapsed: float = 0.0
var _visual_scale: float = 1.0
var _beacon_emitter: StandardMaterial3D
var _beacon_light: OmniLight3D
var _beacon_timer: Timer
var _beacon_lit: bool = false
var _beacon_symbols_left: int = 0
var _beacon_random := RandomNumberGenerator.new()
# Non-emissive fixture paints are immutable and can be reused across boxes.
# Emissive materials stay unique: the beacon and generator alter them later.
var _fixture_paint_cache: Dictionary = {}

func setup(model: Node3D, key: String) -> void:
    name = "BaseFacilityVFX"
    set_meta("FX_NO_OUTLINE", true)
    _model = model
    var yaw: float = float(model.get_meta("body_yaw", 0.0))
    _visual_scale = float(model.get_meta("visual_model_scale", 1.0))
    transform = Transform3D(Basis(Vector3.UP, yaw).scaled(
        Vector3.ONE * _visual_scale), Vector3.ZERO)
    model.add_child(self)
    _soft_halos.clear()
    _searchlight_shafts.clear()
    if key == "SMELTER":
        # Furnace is the sole site retaining its original broad heat shafts,
        # chimney smoke and animated orange floor reflection.
        _add_entrance(key)
        _add_smoke()
        _add_fire_floor()
        # Aimed maintenance spotlight is separate from the molten glow.
        _add_practical_lighting(key)
        _furnace_lamp = model.get_node_or_null(
            "FurnaceHeatLight") as OmniLight3D
        sample_fire(0.0)
        # Furnace entrance remains sharp; add only a faint broad glow.
        _queue_soft_halo(Vector3(0.0, 1.45, 1.38),
            Vector2(1.85, 1.32), Color("#ff9d65"), 0.17)
        set_process(true)
    else:
        # Remove side/entrance shafts entirely at every other BASE site.
        # Add purpose-built local luminaires at their work surfaces instead.
        _add_practical_lighting(key)
        set_process(false)
    # The actual authored emissive architecture should emit soft light too,
    # not only the VFX fixtures. Gather it once before building the batch.
    _collect_authored_emission_halos()
    # Always construct the same low-cost glow batch on the FIRST load and
    # on later scene rebuilds. Never rely on a delayed post-process bloom.
    _finish_soft_halos()
    _finish_searchlight_shafts()

func _queue_soft_halo(at: Vector3, span: Vector2, tint: Color,
        opacity: float, face_angles: Vector3 = Vector3.ZERO) -> void:
    if _soft_halos.size() >= MAX_SOFT_HALO_PATCHES:
        return
    _soft_halos.append({
        "at": at, "span": span, "angles": face_angles,
        "color": Color(tint.r, tint.g, tint.b,
            clampf(opacity, 0.0, 0.60))
    })


static func _shared_soft_halo_material() -> ShaderMaterial:
    if _soft_halo_material != null:
        return _soft_halo_material
    if _soft_halo_texture == null:
        # Tiny precomputed alpha tile: texture filtering supplies the blur,
        # avoiding costly per-frame radial functions/fullscreen postprocessing.
        var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
        for y in range(24):
            for x in range(24):
                var point := (Vector2(float(x), float(y)) -
                    Vector2(11.5, 11.5)) / 11.5
                var intensity: float = pow(
                    maxf(0.0, 1.0 - point.length_squared()), 2.8)
                image.set_pixel(x, y, Color(1.0, 1.0, 1.0, intensity))
        _soft_halo_texture = ImageTexture.create_from_image(image)
    var shader := Shader.new()
    shader.code = SOFT_HALO_SHADER
    _soft_halo_material = ShaderMaterial.new()
    _soft_halo_material.shader = shader
    _soft_halo_material.render_priority = RENDER_ORDER.FACILITY_VFX_FOREGROUND
    _soft_halo_material.set_shader_parameter(
        "soft_halo_mask", _soft_halo_texture)
    _soft_halo_material.set_shader_parameter("halo_strength", 1.8)
    return _soft_halo_material


func _collect_authored_emission_halos() -> void:
    if not is_instance_valid(_model):
        return
    # Every body part already shares its MultiMesh material. Copy only the
    # emissive coordinates into the SAME halo batch; no new real lights.
    # Limit total translucent overdraw on Android overview scenes.
    var remaining: int = maxi(
        0, MAX_SOFT_HALO_PATCHES - _soft_halos.size())
    # Prioritize real emitting architecture. Only after allocating every
    # physical light core, fill remaining space with narrow white accents.
    var ordered_sources: Array[MultiMeshInstance3D] = []
    for child in _model.get_children():
        var source: MultiMeshInstance3D = child as MultiMeshInstance3D
        if source == null or source.multimesh == null:
            continue
        var mat: StandardMaterial3D = source.material_override as StandardMaterial3D
        if mat != null and mat.emission_enabled:
            ordered_sources.append(source)
    for child in _model.get_children():
        var source: MultiMeshInstance3D = child as MultiMeshInstance3D
        if source == null or source.multimesh == null or (
                not source.name.ends_with("_white")):
            continue
        var mat: StandardMaterial3D = source.material_override as StandardMaterial3D
        if mat != null and not mat.emission_enabled:
            ordered_sources.append(source)
    for source in ordered_sources:
        if remaining <= 0:
            break
        var mat: StandardMaterial3D = source.material_override as StandardMaterial3D
        var emissive: bool = mat.emission_enabled
        var white_detail: bool = not emissive
        var many: int = source.multimesh.instance_count
        for i in range(many):
            var pose: Transform3D = source.multimesh.get_instance_transform(i)
            var center: Vector3 = to_local(source.to_global(pose.origin))
            # Use actual batched instance dimensions in the VFX local frame.
            var width: float = (to_local(source.to_global(
                pose.origin + pose.basis.x)) - center).length()
            var height: float = (to_local(source.to_global(
                pose.origin + pose.basis.y)) - center).length()
            var depth: float = (to_local(source.to_global(
                pose.origin + pose.basis.z)) - center).length()
            var long_axis: float = maxf(width, maxf(height, depth))
            var short_axes: int = (
                int(width < 0.23) + int(height < 0.23) +
                int(depth < 0.23))
            var is_line: bool = short_axes >= 2 and long_axis >= 0.30
            if white_detail and not is_line:
                continue
            var hue: Color = (
                mat.emission if emissive else Color("#d6f1ff"))
            # LABO blue-white strips have a dedicated material and should
            # read from the overhead camera, unlike the former faint glint.
            # Boost only their small masked halos; no additional lights.
            var lab_cyan_line: bool = (
                is_line and source.name.ends_with("_lab_cyan"))
            var thickness: float = (
                2.2 if lab_cyan_line else (
                1.8 if is_line else 1.55))
            # Roof strips are flat on XZ. A standing XY glow quad would
            # become hidden by their solid roof face in an overhead camera.
            var roof_strip: bool = (height < 0.16 and depth >= 0.12 and
                (width >= 0.30 or depth >= 0.30))
            var center_light: Vector3 = center + (
                Vector3(0.0, height * 0.50 + 0.035, 0.0) if roof_strip
                else Vector3(0.0, 0.0, depth * 0.50 + 0.035))
            var halo_span: Vector2 = (
                Vector2(clampf(width * 1.65, 0.19, 2.35),
                    clampf(depth * 1.8, 0.19, 1.48)) if roof_strip
                else Vector2(clampf(width * thickness, 0.19, 2.35),
                    clampf(height * (
                        3.0 if lab_cyan_line else (
                        2.6 if is_line else 2.25)), 0.19,
                        1.85 if lab_cyan_line else 1.48)))
            _queue_soft_halo(center_light, halo_span, hue,
                0.24 if lab_cyan_line else (
                0.16 if is_line else 0.10),
                Vector3(-PI * 0.5, 0.0, 0.0) if roof_strip
                else Vector3.ZERO)
            remaining -= 1
            if remaining <= 0:
                break


func _finish_soft_halos() -> void:
    if _soft_halos.is_empty():
        return
    var tile := QuadMesh.new()
    tile.size = Vector2.ONE
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.use_custom_data = true
    instances.mesh = tile
    instances.instance_count = _soft_halos.size()
    for index in range(_soft_halos.size()):
        var halo: Dictionary = _soft_halos[index]
        var span: Vector2 = halo["span"]
        var face_angles: Vector3 = halo["angles"]
        instances.set_instance_transform(index, Transform3D(
            Basis.from_euler(face_angles).scaled(
                Vector3(span.x * 1.12, span.y * 1.12, 1.0)),
            halo["at"]))
        instances.set_instance_custom_data(index, halo["color"])
    var batch := MultiMeshInstance3D.new()
    batch.name = "FacilitySoftEmissionHalos"
    batch.set_meta("FX_NO_OUTLINE", true)
    batch.multimesh = instances
    batch.material_override = _shared_soft_halo_material()
    batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    # Transparent quads remain depth-tested, hiding behind solid housing.
    add_child(batch)
    _soft_halos.clear()


func _make_surface(label: String, at: Vector3, span: Vector2,
        angles: Vector3, shader_source: String, hue: Color = Color.WHITE,
        is_floor: bool = false) -> MeshInstance3D:
    var surface := MeshInstance3D.new()
    surface.name = label
    surface.set_meta("FX_NO_OUTLINE", true)
    var quad := QuadMesh.new()
    quad.size = span
    surface.mesh = quad
    var shader: Shader
    if shader_source == POOL_SHADER:
        if _pool_shader == null:
            _pool_shader = Shader.new()
            _pool_shader.code = POOL_SHADER
        shader = _pool_shader
    elif shader_source == NEXUS_SHUTTER_BEAM_SHADER:
        if _nexus_shutter_beam_shader == null:
            _nexus_shutter_beam_shader = Shader.new()
            _nexus_shutter_beam_shader.code = NEXUS_SHUTTER_BEAM_SHADER
        shader = _nexus_shutter_beam_shader
    elif shader_source == SHAFT_SHADER:
        if _shaft_shader == null:
            _shaft_shader = Shader.new()
            _shaft_shader.code = SHAFT_SHADER
        shader = _shaft_shader
    elif shader_source == FIRE_FLOOR_SHADER:
        if _fire_floor_shader == null:
            _fire_floor_shader = Shader.new()
            _fire_floor_shader.code = FIRE_FLOOR_SHADER
        shader = _fire_floor_shader
    else:
        shader = Shader.new()
        shader.code = shader_source
    var mat := ShaderMaterial.new()
    mat.shader = shader
    # All translucent shafts and fire reflections draw AFTER the 3D
    # depth-resolved outlines. The FX is still excluded from ID rendering.
    mat.render_priority = RENDER_ORDER.FACILITY_VFX_FOREGROUND
    if shader_source == SHAFT_SHADER:
        mat.set_shader_parameter("hue", hue)
        mat.set_shader_parameter("floor_mode", 1.0 if is_floor else 0.0)
    elif shader_source == POOL_SHADER:
        mat.set_shader_parameter("glow_tint", hue)
    elif shader_source == NEXUS_SHUTTER_BEAM_SHADER:
        mat.set_shader_parameter("beam_tint", hue)
    surface.material_override = mat
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    surface.position = at
    surface.rotation = angles
    add_child(surface)
    return surface

func _add_entrance(key: String) -> void:
    var data: Dictionary = PORTALS.get(key, {})
    if data.is_empty():
        return
    var origin: Vector3 = data["at"]
    var span: Vector2 = data["size"]
    var tint: Color = data["color"]
    # Front vertical opening. A second broad ground shaft projects toward
    # the player, so the interior reads as strongly lit from the real camera.
    _make_surface("DoorLightLeak", origin, span, Vector3.ZERO,
        SHAFT_SHADER, Color(tint.r, tint.g, tint.b, 0.95))
    # Keep the light plane just above the 0.32m industrial foundation slab.
    _make_surface("DoorLightFloor",
        Vector3(origin.x, 0.29, origin.z + 1.55),
        Vector2(span.x * 1.64, 3.14), Vector3(-PI * 0.5, 0, 0),
        SHAFT_SHADER, Color(tint.r, tint.g, tint.b, 0.70), true)


# Each aimed luminaire is an actual 3D object above its work location.
# The parent VFX node is intentionally outside the outline ID pass.
# All of these fixtures are static; there is no per-frame repositioning.
func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3,
        color: Color, glow: bool = false) -> MeshInstance3D:
    var piece := MeshInstance3D.new()
    piece.name = label
    piece.set_meta("FX_NO_OUTLINE", true)
    var shape := BoxMesh.new()
    shape.size = dimensions
    piece.mesh = shape
    piece.position = at
    piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var surface: StandardMaterial3D
    if glow:
        # Never share animated or individually tuned emissive materials.
        surface = StandardMaterial3D.new()
        surface.albedo_color = color
        surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        surface.roughness = 0.74
        surface.metallic = 0.0
        surface.emission_enabled = true
        surface.emission = color
        surface.emission_energy_multiplier = 3.2
        # Glowing opaque glass must cover ID ink, not become ID=0 space
        # into which adjacent 3px facility contours can spread.
        piece.set_meta("sera_outline_occluder_only", true)
        piece.set_meta("sera_outline_emissive_protect", true)
    else:
        # Multiple steel lips/brackets often use exactly the same paint.
        # Cache only the immutable, non-emissive material per facility.
        var paint_key: String = color.to_html(true)
        surface = _fixture_paint_cache.get(paint_key) as StandardMaterial3D
        if surface == null:
            surface = StandardMaterial3D.new()
            surface.albedo_color = color
            surface.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
            surface.roughness = 0.74
            surface.metallic = 0.20
            _fixture_paint_cache[paint_key] = surface
    piece.material_override = surface
    parent.add_child(piece)
    if glow and label == "IlluminatedGap":
        # The oriented projector lens is handled by _directed_searchlight.
        # Do not attach a static halo to an unseen underside or Morse lens.
        var center: Vector3 = to_local(piece.global_position)
        var front_z: float = center.z + dimensions.z * 0.50 + 0.035
        _queue_soft_halo(Vector3(center.x, center.y, front_z),
            Vector2(maxf(0.27, dimensions.x * 1.85),
                maxf(0.25, dimensions.y * 2.85)), color, 0.16)
    return piece


func _work_lamp(label: String, at: Vector3, target: Vector3,
        dimensions: Vector3, tint: Color) -> Node3D:
    # The body, optic and outgoing light are one physically aimed assembly.
    # Godot projectors emit along local -Z. Keep the open luminous lens
    # outside the metal hood, facing the exact target position.
    var lamp := Node3D.new()
    lamp.name = label
    lamp.set_meta("FX_NO_OUTLINE", true)
    lamp.position = at
    add_child(lamp)
    lamp.look_at(to_global(target), Vector3.UP)
    _box(lamp, "SwivelSearchlightHousing",
        Vector3(0.0, 0.0, dimensions.z * 0.07), dimensions,
        Color("#344753"))
    var lip_depth: float = -dimensions.z * 0.51
    _box(lamp, "BeveledSteelLampLip",
        Vector3(0.0, dimensions.y * 0.42, lip_depth),
        Vector3(dimensions.x * 0.96, dimensions.y * 0.14, 0.065),
        Color("#566d7b"))
    _box(lamp, "AimedSearchlightLens",
        Vector3(0.0, 0.0, lip_depth - 0.031),
        Vector3(dimensions.x * 0.78, dimensions.y * 0.66, 0.026),
        tint, true)
    _box(lamp, "SearchlightPivotBracket",
        Vector3(0.0, dimensions.y * 0.81, dimensions.z * 0.15),
        Vector3(dimensions.x * 0.22, dimensions.y * 0.67,
            dimensions.z * 0.29), Color("#546676"))
    return lamp


# These instances share a 3-plane low-poly shaft mesh and one material.
# The source is offset to the luminous lens, never the mounting bracket.
func _queue_searchlight_shaft(at: Vector3, target: Vector3,
        tint: Color, radius: float, strength: float) -> void:
    var span: Vector3 = target - at
    var length: float = span.length()
    if length < 0.32:
        return
    var z_axis: Vector3 = -span / length
    var x_axis: Vector3 = Vector3.UP.cross(z_axis)
    if x_axis.length_squared() < 0.01:
        x_axis = Vector3.FORWARD.cross(z_axis)
    x_axis = x_axis.normalized()
    var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
    _searchlight_shafts.append({
        "pose": Transform3D(
            Basis(x_axis * radius, y_axis * radius, z_axis * length), at),
        "color": Color(tint.r, tint.g, tint.b,
            clampf(strength, 0.05, 0.32))
    })


static func _shared_searchlight_shaft_mesh() -> ArrayMesh:
    if _searchlight_shaft_mesh != null:
        return _searchlight_shaft_mesh
    var vertices := PackedVector3Array()
    var texcoords := PackedVector2Array()
    var indices := PackedInt32Array()
    # Three 60-degree-crossed planes retain the low-cost cone. The end
    # width expands from 0.96 to 1.70 (about 1.77x), while the lens end
    # stays narrow for a clear fan-shaped beam in the BASE overview.
    for plane in range(3):
        var angle: float = float(plane) * PI / 3.0
        var lateral := Vector3(cos(angle), sin(angle), 0.0)
        var start_index: int = vertices.size()
        for ring in range(6):
            var t: float = float(ring) / 5.0
            var width: float = lerpf(0.10, 1.70, pow(t, 1.05)) * 0.50
            for side in [-1.0, 1.0]:
                vertices.append(lateral * width * side +
                    Vector3(0.0, 0.0, -t))
                texcoords.append(Vector2((side + 1.0) * 0.5, t))
        for ring in range(5):
            var idx: int = start_index + ring * 2
            indices.append(idx)
            indices.append(idx + 1)
            indices.append(idx + 3)
            indices.append(idx)
            indices.append(idx + 3)
            indices.append(idx + 2)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = texcoords
    arrays[Mesh.ARRAY_INDEX] = indices
    _searchlight_shaft_mesh = ArrayMesh.new()
    _searchlight_shaft_mesh.add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES, arrays)
    return _searchlight_shaft_mesh


static func _shared_searchlight_shaft_material() -> ShaderMaterial:
    if _searchlight_shaft_material != null:
        return _searchlight_shaft_material
    if _searchlight_shaft_shader == null:
        _searchlight_shaft_shader = Shader.new()
        _searchlight_shaft_shader.code = SEARCHLIGHT_SHAFT_SHADER
    _searchlight_shaft_material = ShaderMaterial.new()
    _searchlight_shaft_material.shader = _searchlight_shaft_shader
    _searchlight_shaft_material.render_priority = (
        RENDER_ORDER.FACILITY_VFX_FOREGROUND)
    return _searchlight_shaft_material


func _finish_searchlight_shafts() -> void:
    if _searchlight_shafts.is_empty():
        return
    var batch_data := MultiMesh.new()
    batch_data.transform_format = MultiMesh.TRANSFORM_3D
    batch_data.use_custom_data = true
    batch_data.mesh = _shared_searchlight_shaft_mesh()
    batch_data.instance_count = _searchlight_shafts.size()
    for index in range(_searchlight_shafts.size()):
        var record: Dictionary = _searchlight_shafts[index]
        batch_data.set_instance_transform(index, record["pose"])
        batch_data.set_instance_custom_data(index, record["color"])
    var draw := MultiMeshInstance3D.new()
    draw.name = "AimedWorklightShaftBatch"
    draw.set_meta("FX_NO_OUTLINE", true)
    draw.multimesh = batch_data
    draw.material_override = _shared_searchlight_shaft_material()
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    add_child(draw)
    _searchlight_shafts.clear()


func _directed_searchlight(label: String, at: Vector3, target: Vector3,
        dimensions: Vector3, tint: Color, energy: float, reach: float,
        cone: float, beam_radius: float = 1.2,
        beam_strength: float = 0.24) -> void:
    var line: Vector3 = target - at
    if line.length_squared() < 0.16:
        return
    var direction: Vector3 = line.normalized()
    var lamp: Node3D = _work_lamp(label + "Housing", at, target,
        dimensions, tint)
    # Aim the real spotlight from the actual outward-facing optical glass.
    var lens_at: Vector3 = at + direction * (
        dimensions.z * 0.56 + 0.06)
    _spot(label + "Illumination", lens_at, target, tint, energy, reach, cone)
    _queue_searchlight_shaft(lens_at, target, tint, beam_radius,
        beam_strength)
    _queue_soft_halo(lens_at, Vector2(
        dimensions.x * 1.78, dimensions.y * 2.25), tint, 0.21,
        lamp.rotation)
    # The shaft visibly ends in a localized lit patch at the work target.
    # Floor and elevated work surfaces need different halo orientations.
    var is_floor: bool = target.y < 0.70
    _queue_soft_halo(target + (
            Vector3(0.0, 0.045, 0.0) if is_floor
            else Vector3(0.0, 0.0, 0.07)),
        Vector2(beam_radius * 1.68, beam_radius * 1.18),
        tint, 0.17, Vector3(-PI * 0.5, 0.0, 0.0) if is_floor
        else Vector3.ZERO)


func _slot_lamp(label: String, at: Vector3, size: Vector3,
        tint: Color) -> void:
    var enclosure := Node3D.new()
    enclosure.name = label
    enclosure.set_meta("FX_NO_OUTLINE", true)
    enclosure.position = at
    add_child(enclosure)
    _box(enclosure, "RecessedSteelRim", Vector3.ZERO,
        Vector3(size.x + 0.08, size.y + 0.06, size.z + 0.04),
        Color("#283944"))
    _box(enclosure, "IlluminatedGap",
        Vector3(0.0, 0.0, size.z * 0.71),
        size, tint, true)


# Generator cabinet vents: the glowing source stays BEHIND dark metal lips.
# Unlike the earlier _slot_lamp, the whole slit is not mounted as a luminous
# sticker over the steel wall. Only the open gap is visibly bright.
func _generator_vent_slit(label: String, at: Vector3, size: Vector3,
        tint: Color) -> void:
    var fixture := Node3D.new()
    fixture.name = label
    fixture.set_meta("FX_NO_OUTLINE", true)
    fixture.position = at
    add_child(fixture)
    var source := _box(fixture, "RecessedBlueEmitter",
        Vector3(0.0, 0.0, -0.012),
        size, tint, true)
    # Preserve metal cut-outs while boosting only the luminous cavity;
    # the general fixture brightness on other buildings stays unchanged.
    var emitter_mat := source.material_override as StandardMaterial3D
    emitter_mat.emission_energy_multiplier = 8.0
    var steel := Color("#223541")
    for side in [-1.0, 1.0]:
        _box(fixture, "ShadowedVentLip",
            Vector3(0.0, side * size.y * 0.75, 0.035),
            Vector3(size.x + 0.10, 0.031, 0.080), steel)
        _box(fixture, "VentFramePost",
            Vector3(side * (size.x * 0.53 + 0.035), 0.0, 0.038),
            Vector3(0.055, size.y * 2.0, 0.086), steel)


# The earlier sub-0.05m 3D emissive filaments became nearly invisible
# after BASE zoom and screen downsampling. Overlay their actual physical
# openings with ten larger, thin, depth-tested emissive faces. All quads
# share ONE MultiMesh draw and do not contribute to outlines or shadows.
func _generator_visible_gap_leaks() -> void:
    if _generator_gap_leak_shader == null:
        _generator_gap_leak_shader = Shader.new()
        _generator_gap_leak_shader.code = GENERATOR_GAP_LEAK_SHADER

    var glow_material := ShaderMaterial.new()
    glow_material.shader = _generator_gap_leak_shader
    glow_material.render_priority = RENDER_ORDER.FACILITY_VFX_FOREGROUND

    var unit_quad := QuadMesh.new()
    unit_quad.size = Vector2.ONE
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = unit_quad
    instances.instance_count = 10

    # Four open channels between five rotor louvers. These faces sit just
    # in front of the 1.144m grille depth but remain between the metal
    # bars, so the dark divisions stay legible in the overview.
    for i in range(4):
        instances.set_instance_transform(i, Transform3D(
            Basis().scaled(Vector3(1.44, 0.081, 1.0)),
            Vector3(-0.27, 1.22 + float(i) * 0.14, 1.153)))
        _queue_soft_halo(
            Vector3(-0.27, 1.22 + float(i) * 0.14, 1.162),
            Vector2(1.62, 0.23), Color("#a1eaff"), 0.12)

    # Four front-facing, boxed cabinet vents. Their VFX steel lips end at
    # z=0.58; moving the narrow luminous core to z=0.586 prevents the
    # original light from being lost behind the geometry at oblique angles.
    for i in range(4):
        instances.set_instance_transform(4 + i, Transform3D(
            Basis().scaled(Vector3(0.41, 0.063, 1.0)),
            Vector3(1.22, 1.70 + float(i) * 0.125, 0.586)))
        _queue_soft_halo(
            Vector3(1.22, 1.70 + float(i) * 0.125, 0.595),
            Vector2(0.58, 0.19), Color("#c9f5ff"), 0.11)

    # Cooling fins have two actual open 0.07m gaps, visible above the rotor.
    for i in range(2):
        instances.set_instance_transform(8 + i, Transform3D(
            Basis().scaled(Vector3(0.56, 0.076, 1.0)),
            Vector3(-1.20, 2.98 + float(i) * 0.16, -0.225)))
        _queue_soft_halo(
            Vector3(-1.20, 2.98 + float(i) * 0.16, -0.215),
            Vector2(0.73, 0.22), Color("#b6edff"), 0.10)

    var strip_batch := MultiMeshInstance3D.new()
    strip_batch.name = "GeneratorVisibleGapLeakBatch"
    strip_batch.set_meta("FX_NO_OUTLINE", true)
    strip_batch.multimesh = instances
    strip_batch.material_override = glow_material
    strip_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(strip_batch)


func _spot(label: String, at: Vector3, target: Vector3,
        tint: Color, energy: float, reach: float, cone: float) -> void:
    # One shadow-free local spotlight replaces an entire broad facade shaft.
    var spot := SpotLight3D.new()
    spot.name = label
    spot.set_meta("FX_NO_OUTLINE", true)
    add_child(spot)
    spot.position = at
    spot.look_at(to_global(target), Vector3.UP)
    spot.light_color = tint
    # BASE equipment now retains original lit StandardMaterial3D so these
    # shadowless spots illuminate real work surfaces, not unshaded copies.
    spot.light_energy = energy * 4.0
    spot.spot_range = reach * 1.12
    # The physical spotlight opens slightly wider as the visible low-poly
    # cone expands. Keep the lighting focused on its original work target.
    spot.spot_angle = minf(75.0, cone + 10.0)
    spot.spot_attenuation = 0.82
    spot.shadow_enabled = false


func _round_floor_pool(label: String, at: Vector3, radius: Vector2,
        tint: Color, opacity: float = 0.24) -> void:
    _make_surface(label, at, radius, Vector3(-PI * 0.5, 0, 0),
        POOL_SHADER, Color(tint.r, tint.g, tint.b, opacity))


func _antenna_beacon() -> void:
    # Old roof mast remains completely fixed. A small, independently
    # addressable lens replaces its former telescoping MultiMesh cube.
    var crown := Node3D.new()
    crown.name = "NexusFixedBeaconHousing"
    crown.position = Vector3(2.42, 6.18, -1.78)
    crown.set_meta("FX_NO_OUTLINE", true)
    add_child(crown)
    _box(crown, "BeaconSteelBase", Vector3(0, -0.080, 0),
        Vector3(0.20, 0.065, 0.20), Color("#465766"))
    var lens := _box(crown, "MorseAmberLens", Vector3.ZERO,
        Vector3(0.135, 0.15, 0.135), Color("#ffba73"), true)
    _beacon_emitter = lens.material_override as StandardMaterial3D
    _beacon_light = OmniLight3D.new()
    _beacon_light.name = "MorseSignalGlow"
    _beacon_light.light_color = Color("#ffb575")
    _beacon_light.omni_range = 0.95 * _visual_scale
    _beacon_light.shadow_enabled = false
    crown.add_child(_beacon_light)
    _beacon_timer = Timer.new()
    _beacon_timer.name = "MorseSignalInterval"
    _beacon_timer.one_shot = true
    _beacon_timer.timeout.connect(_advance_beacon)
    add_child(_beacon_timer)
    _beacon_random.randomize()
    _advance_beacon()


func _advance_beacon() -> void:
    if _beacon_timer == null:
        return
    _beacon_lit = not _beacon_lit
    var interval: float
    if _beacon_lit:
        if _beacon_symbols_left <= 0:
            _beacon_symbols_left = _beacon_random.randi_range(2, 5)
        _beacon_symbols_left -= 1
        # Short dots and long dashes; each cluster uses unpredictable order.
        interval = (
            _beacon_random.randf_range(0.26, 0.40)
            if _beacon_random.randf() < 0.34 else
            _beacon_random.randf_range(0.075, 0.14))
    else:
        # Brief element gaps, occasional medium rests and word gaps.
        interval = (_beacon_random.randf_range(0.45, 0.83)
            if _beacon_symbols_left <= 0 else
            _beacon_random.randf_range(0.07, 0.16))
    if _beacon_emitter != null:
        _beacon_emitter.emission_energy_multiplier = (
            2.8 if _beacon_lit else 0.0)
        _beacon_emitter.albedo_color = (
            Color("#ffba73") if _beacon_lit else Color("#4b3a35"))
    if is_instance_valid(_beacon_light):
        _beacon_light.light_energy = 0.65 if _beacon_lit else 0.0
    _beacon_timer.start(interval)


func _add_practical_lighting(key: String) -> void:
    # Every mounted work projector is aimed at one explicit machine task.
    # The housing, lens, SpotLight3D -Z axis, visible shaft and impact patch
    # all use the SAME pair of local coordinates.
    match key:
        "NEXUS":
            _antenna_beacon()
            # The original shutter gap remains a narrow architectural emitter.
            # A proper high-mounted projector now illuminates the apron,
            # rather than a fake spotlight emerging from floor level.
            _slot_lamp("ShutterLowerGapEmitter",
                Vector3(0.0, 0.34, 2.97),
                Vector3(1.68, 0.050, 0.06), Color("#bbecff"))
            _directed_searchlight("GateApronSearchlight",
                Vector3(0.0, 3.48, 2.93),
                Vector3(0.0, 0.37, 4.76),
                Vector3(0.68, 0.28, 0.43), Color("#c5edff"),
                1.80, 5.25, 37.0, 1.50, 0.29)
            # Keep the independently animated-looking spill geometry at
            # the shutter; it no longer stands in for the aimed projector.
            _make_surface("ShutterLowerGapSpill",
                Vector3(0.0, 0.34, 5.89), Vector2(1.42, 5.80),
                Vector3(-PI * 0.5, 0.0, 0.0),
                NEXUS_SHUTTER_BEAM_SHADER, Color("#bbecff"), false)
            _queue_soft_halo(Vector3(0.0, 0.39, 3.065),
                Vector2(2.28, 0.63), Color("#bceaff"), 0.24)
        "RECYCLER":
            # Two jaws, two actual aimed lamps. The old central spotlight
            # used a different origin than both visible lamp housings.
            for side in [-1.0, 1.0]:
                _directed_searchlight(
                    "CrusherLeftJawSearchlight" if side < 0.0
                    else "CrusherRightJawSearchlight",
                    Vector3(side * 0.90, 2.51, 1.33),
                    Vector3(side * 0.30, 1.38, 0.52),
                    Vector3(0.38, 0.19, 0.34), Color("#ffd8af"),
                    1.34, 3.18, 38.0, 0.88, 0.23)
            _round_floor_pool("CrusherMouthWarmAccent",
                Vector3(0.0, 0.35, 1.12), Vector2(1.75, 1.05),
                Color("#ffca8c"), 0.33)
        "GENERATOR":
            # Exposed turbine has one elevated service lamp aimed directly
            # at its rotor; blue cabinet gaps are independent emissive slots.
            _directed_searchlight("RotorServiceSearchlight",
                Vector3(-1.10, 3.19, -0.22),
                Vector3(-0.27, 1.43, 1.19),
                Vector3(0.42, 0.20, 0.34), Color("#a9e7ff"),
                1.65, 3.70, 37.0, 0.91, 0.22)
            _make_surface("RotorRearBlueGlow",
                Vector3(-0.27, 1.43, 1.085), Vector2(1.56, 0.74),
                Vector3.ZERO, POOL_SHADER, Color(0.60, 0.91, 1.0, 0.96))
            for row in range(4):
                _generator_vent_slit("PowerCabinetWallSlit",
                    Vector3(1.22, 1.70 + row * 0.125, 0.505),
                    Vector3(0.42, 0.060, 0.026), Color("#d0f7ff"))
            _make_surface("CabinetVentInnerBloom",
                Vector3(1.22, 1.89, 0.511), Vector2(0.54, 0.66),
                Vector3.ZERO, POOL_SHADER, Color(0.53, 0.88, 1.0, 0.41))
            _generator_visible_gap_leaks()
            _queue_soft_halo(Vector3(-0.27, 1.45, 1.185),
                Vector2(1.93, 1.35), Color("#8fdcff"), 0.09)
            _queue_soft_halo(Vector3(1.22, 1.89, 0.618),
                Vector2(0.74, 0.87), Color("#b2edff"), 0.08)
        "STORAGE":
            # The actual landing positions are the two loading bays,
            # not a generic forward-facing luminous facade.
            for side in [-1.0, 1.0]:
                _directed_searchlight(
                    "LoadingBayLeftSearchlight" if side < 0.0
                    else "LoadingBayRightSearchlight",
                    Vector3(side * 1.11, 2.79, 1.11),
                    Vector3(side * 0.70, 0.45, 1.78),
                    Vector3(0.46, 0.19, 0.36), Color("#ffdda6"),
                    1.65, 3.95, 35.0, 1.02, 0.26)
                _round_floor_pool("WarehouseRoundFloorGlow",
                    Vector3(side * 0.70, 0.33, 1.74),
                    Vector2(1.35, 1.35), Color("#ffdfac"), 0.32)
        "SCRAP_COLLECTOR":
            # Separate tracking/recognition and collected-bin functions.
            # Both lamps visibly end at the same point the spot illuminates.
            _directed_searchlight("ScrapPickupSearchlight",
                Vector3(-0.38, 3.15, -0.18),
                Vector3(0.23, 1.05, 0.23),
                Vector3(0.41, 0.21, 0.36), Color("#b9e8ff"),
                1.90, 3.65, 34.0, 1.05, 0.28)
            _directed_searchlight("CollectionBinSearchlight",
                Vector3(0.90, 2.89, 1.41),
                Vector3(0.35, 0.77, 1.10),
                Vector3(0.39, 0.19, 0.34), Color("#d0efff"),
                1.65, 3.40, 34.0, 0.89, 0.27)
            _round_floor_pool("CollectorPickupPatch",
                Vector3(0.20, 0.36, 1.23), Vector2(1.32, 1.00),
                Color("#9bdfff"), 0.28)
            _round_floor_pool("CollectorBinPatch",
                Vector3(0.46, 0.35, 1.65), Vector2(1.08, 0.92),
                Color("#c2ebff"), 0.28)
        "LABO":
            # Aim the gantry lamp down onto the fabrication bed. The warm
            # task light is distinct from the cool cyan indicator strips.
            _directed_searchlight("FabricationBedSearchlight",
                Vector3(0.0, 3.12, -0.05),
                Vector3(0.10, 1.13, 1.35),
                Vector3(0.56, 0.23, 0.34), Color("#ffe3b8"),
                1.48, 3.36, 37.0, 0.84, 0.22)
            _queue_soft_halo(Vector3(0.0, 1.56, 1.83),
                Vector2(0.95, 0.85), Color("#ffe6c3"), 0.10)
        "BUILD_TERMINAL":
            # Aim the fixture at the actual interaction keys, not across
            # the terminal's holographic display or into empty space.
            _directed_searchlight("BlueprintConsoleSearchlight",
                Vector3(-0.76, 2.85, -0.16),
                Vector3(0.0, 1.18, 0.79),
                Vector3(0.44, 0.20, 0.33), Color("#acdfff"),
                1.08, 3.18, 37.0, 0.80, 0.21)
            _queue_soft_halo(Vector3(0.0, 1.78, 0.81),
                Vector2(1.12, 1.04), Color("#9bdfff"), 0.20)
        "SMELTER":
            # Furnace fire and its heat light are NOT searchlights.
            # A separate, mounted maintenance projector highlights the
            # front slag intake without replacing the flame reflection.
            _directed_searchlight("FurnaceServiceSearchlight",
                Vector3(-0.86, 2.73, 0.92),
                Vector3(-0.25, 1.24, 1.18),
                Vector3(0.38, 0.18, 0.31), Color("#ffd5a6"),
                1.15, 3.25, 38.0, 0.82, 0.17)


func _smoke_quad_material() -> StandardMaterial3D:
    # Chimney smoke uses the same immutable alpha tile after scene rebuilds.
    if _smoke_material != null:
        return _smoke_material
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    for y in range(32):
        for x in range(32):
            var p: Vector2 = (Vector2(float(x), float(y)) -
                Vector2(15.5, 15.5)) / 15.5
            var radius: float = p.length()
            var softness: float = pow(
                1.0 - smoothstep(0.27, 1.0, radius), 1.65)
            img.set_pixel(x, y, Color(1, 1, 1, softness * 0.65))
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = ImageTexture.create_from_image(img)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mat.render_priority = RENDER_ORDER.FACILITY_VFX_FOREGROUND
    _smoke_material = mat
    return _smoke_material

func _add_smoke() -> void:
    var stack_group := Node3D.new()
    stack_group.name = "SmelterChimneySmoke"
    stack_group.set_meta("FX_NO_OUTLINE", true)
    add_child(stack_group)
    var sprite := QuadMesh.new()
    sprite.size = Vector2(0.76, 0.76)
    sprite.material = _smoke_quad_material()
    var fade := Gradient.new()
    fade.set_color(0, Color(0.51, 0.56, 0.61, 0.00))
    fade.set_color(1, Color(0.50, 0.55, 0.61, 0.00))
    fade.add_point(0.22, Color(0.55, 0.60, 0.66, 0.64))
    fade.add_point(0.60, Color(0.52, 0.57, 0.63, 0.40))
    for side in [-1.0, 1.0]:
        var part := CPUParticles3D.new()
        part.name = "SmelterChimneySmoke"
        part.set_meta("FX_NO_OUTLINE", true)
        part.position = Vector3(side * 0.81, 4.48, -0.84)
        part.amount = 21
        part.lifetime = 2.85
        part.preprocess = 2.85
        part.fixed_fps = 20
        part.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        part.emission_box_extents = Vector3(0.11, 0.02, 0.11)
        part.direction = Vector3.UP
        part.gravity = Vector3(0.04 * side, 0.05, 0.03)
        part.spread = 14.0
        part.initial_velocity_min = 0.48
        part.initial_velocity_max = 0.79
        part.scale_amount_min = 0.75
        part.scale_amount_max = 1.56
        part.color_ramp = fade
        part.mesh = sprite
        part.local_coords = true
        part.emitting = true
        stack_group.add_child(part)

func _add_fire_floor() -> void:
    # Light-pool illusion, not a real screen-space SSR/reflection: this works
    # on mobile GL Compatibility without depth-copy or refraction passes.
    # This plane must clear the foundation top, not clip into the slab.
    _make_surface("SmelterFireFloorReflection",
        Vector3(0.0, 0.30, 2.20), Vector2(3.0, 3.40),
        Vector3(-PI * 0.5, 0.0, 0.0),
        FIRE_FLOOR_SHADER)

func sample_fire(seconds: float) -> void:
    if _furnace_lamp != null:
        var pulse: float = 0.76 + 0.15 * sin(seconds * 7.1) + (
            0.09 * sin(seconds * 11.3))
        _furnace_lamp.light_energy = 2.05 * pulse

func _process(delta: float) -> void:
    _elapsed += maxf(delta, 0.0)
    sample_fire(_elapsed)

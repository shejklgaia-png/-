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
    EMISSION = glow_tint.rgb * round_pool * 1.2;
    ALPHA = glow_tint.a * round_pool;
}
"""
static var _pool_shader: Shader

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

func setup(model: Node3D, key: String) -> void:
    name = "BaseFacilityVFX"
    set_meta("FX_NO_OUTLINE", true)
    _model = model
    var yaw: float = float(model.get_meta("body_yaw", 0.0))
    _visual_scale = float(model.get_meta("visual_model_scale", 1.0))
    transform = Transform3D(Basis(Vector3.UP, yaw).scaled(
        Vector3.ONE * _visual_scale), Vector3.ZERO)
    model.add_child(self)
    if key == "SMELTER":
        # Furnace is the sole site retaining its original broad heat shafts,
        # chimney smoke and animated orange floor reflection.
        _add_entrance(key)
        _add_smoke()
        _add_fire_floor()
        _furnace_lamp = model.get_node_or_null(
            "FurnaceHeatLight") as OmniLight3D
        sample_fire(0.0)
        set_process(true)
    else:
        # Remove side/entrance shafts entirely at every other BASE site.
        # Add purpose-built local luminaires at their work surfaces instead.
        _add_practical_lighting(key)
        set_process(false)

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


# Each luminaire is an actual small 3D object at the real work location.
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
    var surface := StandardMaterial3D.new()
    surface.albedo_color = color
    surface.shading_mode = (
        BaseMaterial3D.SHADING_MODE_UNSHADED if glow else
        BaseMaterial3D.SHADING_MODE_PER_PIXEL)
    surface.roughness = 0.74
    surface.metallic = 0.20 if not glow else 0.0
    if glow:
        surface.emission_enabled = true
        surface.emission = color
        surface.emission_energy_multiplier = 1.7
    piece.material_override = surface
    parent.add_child(piece)
    return piece


func _work_lamp(label: String, at: Vector3, dimensions: Vector3,
        tint: Color) -> Node3D:
    var lamp := Node3D.new()
    lamp.name = label
    lamp.set_meta("FX_NO_OUTLINE", true)
    lamp.position = at
    add_child(lamp)
    _box(lamp, "RuggedMetalLampHousing", Vector3.ZERO, dimensions,
        Color("#344753"))
    _box(lamp, "RecessedLampDiffuser",
        Vector3(0.0, -dimensions.y * 0.49, 0.0),
        Vector3(dimensions.x * 0.77, 0.022, dimensions.z * 0.78),
        tint, true)
    # A physical short bracket connects the industrial fixture to the frame.
    _box(lamp, "LampMountBracket",
        Vector3(0.0, dimensions.y * 0.70, -dimensions.z * 0.28),
        Vector3(dimensions.x * 0.19, dimensions.y * 0.65,
            dimensions.z * 0.22), Color("#546676"))
    return lamp


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
        Vector3(0.0, 0.0, size.z * 0.54),
        size, tint, true)


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
    spot.light_energy = energy
    spot.spot_range = reach * _visual_scale
    spot.spot_angle = cone
    spot.spot_attenuation = 1.8
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
    match key:
        "NEXUS":
            _antenna_beacon()
            # A slim luminaire under the BLAST shutter, not a broad bright
            # panel across the whole building's side.
            _slot_lamp("ShutterLowerGapEmitter",
                Vector3(0.0, 0.34, 2.97),
                Vector3(1.68, 0.050, 0.06), Color("#bbecff"))
            _spot("ShutterGapLight", Vector3(0.0, 0.53, 2.99),
                Vector3(0.0, 0.31, 3.58), Color("#bceaff"),
                0.72, 2.7, 55.0)
            _round_floor_pool("ShutterLowerGapSpill",
                Vector3(0.0, 0.33, 3.36), Vector2(2.35, 1.16),
                Color("#bbecff"), 0.23)
        "RECYCLER":
            for side in [-1.0, 1.0]:
                _work_lamp("ProtectedCrusherWorklamp",
                    Vector3(side * 0.75, 2.05, 0.97),
                    Vector3(0.32, 0.14, 0.32), Color("#ffcc9a"))
            _spot("CrusherBiteSpot",
                Vector3(0.0, 2.05, 1.01),
                Vector3(0.0, 1.11, 0.18),
                Color("#ffd5ab"), 1.34, 2.9, 49.0)
        "GENERATOR":
            # The luminous backing sits BEHIND the real rotating fan.
            # Opaque blades still depth-occlude it; it only shines through
            # the spaces between fan spokes.
            _make_surface("RotorRearBlueGlow",
                Vector3(-0.27, 1.43, 1.055), Vector2(0.83, 0.83),
                Vector3.ZERO, POOL_SHADER, Color(0.38, 0.80, 1.0, 0.75))
            for row in range(4):
                _slot_lamp("PowerCabinetWallSlit",
                    Vector3(0.86, 1.35 + row * 0.125, 0.36),
                    Vector3(0.24, 0.021, 0.025), Color("#8de4ff"))
            _work_lamp("RotorGuardWorklamp", Vector3(-0.61, 1.90, 1.06),
                Vector3(0.30, 0.13, 0.22), Color("#9cdeff"))
            _spot("RotorVentLight", Vector3(-0.54, 1.84, 1.10),
                Vector3(-0.27, 1.42, 1.18),
                Color("#8cdcff"), 0.90, 2.1, 48.0)
        "STORAGE":
            # Two independent protected industrial fixtures make circular
            # warm landing pools in front of the loading opening.
            for side in [-1.0, 1.0]:
                _work_lamp("WarehouseLoadingBayLamp",
                    Vector3(side * 0.72, 2.16, 1.08),
                    Vector3(0.45, 0.15, 0.32), Color("#ffdda6"))
                _spot("WarehouseDoorSpot",
                    Vector3(side * 0.72, 2.10, 1.12),
                    Vector3(side * 0.70, 0.36, 1.78),
                    Color("#ffdda6"), 1.10, 3.4, 39.0)
                _round_floor_pool("WarehouseRoundFloorGlow",
                    Vector3(side * 0.70, 0.33, 1.74),
                    Vector2(1.35, 1.35), Color("#ffdfac"), 0.18)
        "SCRAP_COLLECTOR":
            # Scrap recognition pad and loaded collection bin have SEPARATE
            # spotlights, making the machine's two purposes readable.
            _work_lamp("CollectorPickupSpotHousing",
                Vector3(-0.70, 2.37, 0.71),
                Vector3(0.36, 0.17, 0.31), Color("#c1e9ff"))
            _spot("CollectorPickupSpot",
                Vector3(-0.70, 2.30, 0.71),
                Vector3(0.23, 1.05, 0.23),
                Color("#a6dfff"), 1.16, 3.0, 36.0)
            _work_lamp("CollectorBinSpotHousing",
                Vector3(0.80, 2.31, 0.92),
                Vector3(0.33, 0.16, 0.29), Color("#d2eafa"))
            _spot("CollectorBinSpot", Vector3(0.80, 2.28, 0.92),
                Vector3(0.35, 0.55, 1.10),
                Color("#c2ebff"), 1.0, 2.8, 36.0)
        "LABO":
            # Keep its existing single task light, add its physical housing.
            _work_lamp("ExistingLabTaskLampHousing",
                Vector3(0.0, 2.28, 1.31),
                Vector3(0.52, 0.15, 0.28), Color("#ffe0af"))
        "BUILD_TERMINAL":
            _work_lamp("ExistingTerminalPanelLampHousing",
                Vector3(0.0, 2.23, 0.54),
                Vector3(0.48, 0.14, 0.27), Color("#a9e1ff"))


func _smoke_quad_material() -> StandardMaterial3D:
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
    return mat

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

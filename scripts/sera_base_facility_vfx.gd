extends Node3D
## Separate FX-only graph, NEVER collected into the architectural outline mask.
## CPU chimney plumes are GL Compatibility safe; all light shafts are unshaded
## additive quads. Main solid MultiMesh and archived NEXUS remain untouched.
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

func setup(model: Node3D, key: String) -> void:
    name = "BaseFacilityVFX"
    set_meta("FX_NO_OUTLINE", true)
    _model = model
    var yaw: float = float(model.get_meta("body_yaw", 0.0))
    var size: float = float(model.get_meta("visual_model_scale", 1.0))
    transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size),
        Vector3.ZERO)
    model.add_child(self)
    _add_entrance(key)
    if key == "SMELTER":
        _add_smoke()
        _add_fire_floor()
        _furnace_lamp = model.get_node_or_null(
            "FurnaceHeatLight") as OmniLight3D
        sample_fire(0.0)
        set_process(true)
    else:
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
    var shader := Shader.new()
    shader.code = shader_source
    var mat := ShaderMaterial.new()
    mat.shader = shader
    if shader_source == SHAFT_SHADER:
        mat.set_shader_parameter("hue", hue)
        mat.set_shader_parameter("floor_mode", 1.0 if is_floor else 0.0)
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
    _make_surface("DoorLightFloor",
        Vector3(origin.x, 0.065, origin.z + 1.55),
        Vector2(span.x * 1.64, 3.14), Vector3(-PI * 0.5, 0, 0),
        SHAFT_SHADER, Color(tint.r, tint.g, tint.b, 0.70), true)

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
    _make_surface("SmelterFireFloorReflection",
        Vector3(0.0, 0.071, 2.20), Vector2(3.0, 3.40),
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

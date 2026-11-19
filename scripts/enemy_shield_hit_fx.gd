extends Node3D
## Contact-local radial predictive shield: armor < shield < regular hit sparks.
## The gradient is vertex alpha (no imported texture, no HP bar overlay).
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const SHIELD_SURFACE_OFFSET: float = 0.032
const IMPACT_SECONDS: float = 0.28
const FRACTURE_SECONDS: float = 0.44
const MAX_SIMULTANEOUS: int = 5
const SEGMENTS: int = 28

var view_camera: Camera3D
var mesh: ImmediateMesh
var instance: MeshInstance3D
var material: StandardMaterial3D
var break_audio: AudioStreamPlayer
var impacts: Array[Dictionary] = []

static func state_color(ratio: float) -> Color:
    if ratio >= 0.60:
        return Color("27bafa")
    if ratio >= 0.30:
        return Color("ffda40")
    return Color("ff4e4e")

func _ready() -> void:
    mesh = ImmediateMesh.new()
    instance = MeshInstance3D.new()
    instance.name = "EnemyShieldContactRadialGradient"
    instance.mesh = mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.no_depth_test = false  # The armor and terrain must occlude it.
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.render_priority = RENDER_ORDER.SHIELD_IMPACT
    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
    break_audio = AudioStreamPlayer.new()
    break_audio.name = "EnemyShieldFractureSE"
    break_audio.stream = _make_break_sound()
    break_audio.volume_db = -4.0
    break_audio.max_polyphony = 3
    add_child(break_audio)

func _make_break_sound() -> AudioStreamWAV:
    # Crisp electrostatic crack followed by a brief expanding, airy 'PAAN'.
    # Generated once per scene, so there is no external missing SE asset.
    const RATE: int = 22050
    const LENGTH: float = 0.36
    var frames: int = int(RATE * LENGTH)
    var bytes := PackedByteArray()
    bytes.resize(frames * 2)
    var seed: int = 16381
    for i in range(frames):
        var t: float = float(i) / float(RATE)
        seed = (seed * 1103515245 + 12345) & 0x7fffffff
        var noise: float = float(seed & 65535) / 32767.5 - 1.0
        var crack: float = noise * exp(-t * 80.0) * 0.77
        var impact: float = sin(TAU * (170.0 * t - 100.0 * t * t)) * exp(-t * 20.0) * 0.35
        var airy: float = noise * exp(-t * 14.0) * (1.0 - exp(-t * 110.0)) * 0.32
        var electric: float = sin(TAU * (700.0 * t + 250.0 * t * t)) * exp(-t * 17.0) * 0.18
        var sample: float = clampf(crack + impact + airy + electric, -1.0, 1.0)
        bytes.encode_s16(i * 2, roundi(sample * 30000.0))
    var stream := AudioStreamWAV.new()
    stream.mix_rate = RATE
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.stereo = false
    stream.data = bytes
    return stream

func start_impact(world_hit: Vector3, shield_ratio: float, broken: bool) -> void:
    if not broken and shield_ratio <= 0.0:
        return
    impacts.append({
        "origin": world_hit,
        "elapsed": 0.0,
        "duration": FRACTURE_SECONDS if broken else IMPACT_SECONDS,
        "color": state_color(shield_ratio),
        "broken": broken,
    })
    if impacts.size() > MAX_SIMULTANEOUS:
        impacts.pop_front()
    if broken and break_audio != null:
        break_audio.play()
    _redraw()

func reset() -> void:
    impacts.clear()
    if mesh != null:
        mesh.clear_surfaces()
    if break_audio != null:
        break_audio.stop()

func advance(delta: float) -> void:
    if impacts.is_empty():
        return
    for i in range(impacts.size() - 1, -1, -1):
        var entry: Dictionary = impacts[i]
        entry["elapsed"] = float(entry["elapsed"]) + maxf(0.0, delta)
        if float(entry["elapsed"]) >= float(entry["duration"]):
            impacts.remove_at(i)
        else:
            impacts[i] = entry
    _redraw()

func _tri(a: Vector2, b: Vector2, c: Vector2,
        ca: Color, cb: Color, cc: Color, depth: float) -> void:
    mesh.surface_set_color(ca)
    mesh.surface_add_vertex(view_camera.project_position(a, depth))
    mesh.surface_set_color(cb)
    mesh.surface_add_vertex(view_camera.project_position(b, depth))
    mesh.surface_set_color(cc)
    mesh.surface_add_vertex(view_camera.project_position(c, depth))

func _ring(center: Vector2, inner_radius: float, outer_radius: float,
        inside: Color, outside: Color, depth: float) -> void:
    for i in range(SEGMENTS):
        var a: float = TAU * float(i) / float(SEGMENTS)
        var b: float = TAU * float(i + 1) / float(SEGMENTS)
        var va: Vector2 = Vector2(cos(a), sin(a))
        var vb: Vector2 = Vector2(cos(b), sin(b))
        var inner_a: Vector2 = center + va * inner_radius
        var inner_b: Vector2 = center + vb * inner_radius
        var outer_a: Vector2 = center + va * outer_radius
        var outer_b: Vector2 = center + vb * outer_radius
        _tri(inner_a, outer_a, outer_b, inside, outside, outside, depth)
        _tri(inner_a, outer_b, inner_b, inside, outside, inside, depth)

func _beam(a: Vector2, b: Vector2, half_width: float,
        tint: Color, depth: float) -> void:
    var along: Vector2 = b - a
    if along.length_squared() <= 0.001:
        return
    var normal: Vector2 = Vector2(-along.y, along.x).normalized() * half_width
    _tri(a - normal, b - normal, b + normal, tint, tint, tint, depth)
    _tri(a - normal, b + normal, a + normal, tint, tint, tint, depth)

func _fracture(center: Vector2, depth: float, t: float, scale: float) -> void:
    # A horizontal crack branches from the center in BOTH directions.
    # A bright thin central line is surrounded by a soft blue-white glow.
    var unfold: float = clampf(t / 0.16, 0.0, 1.0)
    var line_fade: float = clampf((0.27 - t) / 0.11, 0.0, 1.0)
    var reach: float = (35.0 + 145.0 * unfold) * scale
    for sign_dir in [-1.0, 1.0]:
        var previous: Vector2 = center
        for i in range(1, 9):
            var f: float = float(i) / 8.0
            var jitter: float = sin(float(i) * 2.47 + sign_dir * 1.6) * 4.5
            var current: Vector2 = center + Vector2(
                sign_dir * reach * f, jitter * scale * f)
            var glow := Color(0.27, 0.83, 1.0, 0.18 * line_fade)
            var core := Color(0.86, 0.97, 1.0, 0.92 * line_fade)
            _beam(previous, current, 5.0 * scale, glow, depth)
            _beam(previous, current, 1.0 * scale, core, depth - 0.001)
            previous = current
    # After the crack, the shield bursts outward in a radial gradient,
    # leaving no opaque disk edge or lingering solid shell.
    var burst: float = clampf((t - 0.045) / 0.33, 0.0, 1.0)
    if burst > 0.0:
        var power: float = pow(1.0 - burst, 1.7)
        var radius: float = (12.0 + 174.0 * burst) * scale
        _ring(center, 0.0, radius * 0.22,
            Color(0.93, 0.99, 1.0, 0.68 * power),
            Color(0.40, 0.88, 1.0, 0.32 * power), depth)
        _ring(center, radius * 0.22, radius,
            Color(0.40, 0.88, 1.0, 0.32 * power),
            Color(0.12, 0.69, 1.0, 0.0), depth)

func _draw_impact(center: Vector2, depth: float, t: float,
        duration: float, tone: Color, scale: float) -> void:
    var progress: float = clampf(t / duration, 0.0, 1.0)
    var opacity: float = pow(1.0 - progress, 1.3)
    var radius: float = (27.0 + 47.0 * progress) * scale
    var bright := Color(tone.r, tone.g, tone.b, 0.63 * opacity)
    var faint := Color(tone.r, tone.g, tone.b, 0.26 * opacity)
    var clear := Color(tone.r, tone.g, tone.b, 0.0)
    _ring(center, 0.0, radius * 0.28, bright, faint, depth)
    _ring(center, radius * 0.28, radius, faint, clear, depth)

func _redraw() -> void:
    if mesh == null:
        return
    mesh.clear_surfaces()
    if view_camera == null or impacts.is_empty():
        return
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
    for entry in impacts:
        var world_hit: Vector3 = entry["origin"]
        if view_camera.is_position_behind(world_hit):
            continue
        var camera_depth: float = (
            world_hit - view_camera.global_position).dot(-view_camera.global_basis.z)
        var depth: float = maxf(view_camera.near + 0.012,
            camera_depth - SHIELD_SURFACE_OFFSET)
        var center: Vector2 = view_camera.unproject_position(world_hit)
        var high: Vector2 = view_camera.unproject_position(world_hit + Vector3.UP)
        var low: Vector2 = view_camera.unproject_position(world_hit - Vector3.UP)
        var scale: float = clampf(high.distance_to(low) / 270.0, 0.58, 1.65)
        var age: float = float(entry["elapsed"])
        if bool(entry["broken"]):
            _fracture(center, depth, age, scale)
        else:
            _draw_impact(center, depth, age,
                float(entry["duration"]), entry["color"], scale)
    mesh.surface_end()

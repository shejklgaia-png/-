extends Node3D
## Contact-local radial predictive shield: armor < shield < regular hit sparks.
## The gradient is vertex alpha (no imported texture, no HP bar overlay).
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
# Separate from opaque armor, while still sorting below HIT_SPARKS.
# The larger camera-facing surface needs more clearance at grazing angles.
const SHIELD_SURFACE_OFFSET: float = 0.14
const IMPACT_SECONDS: float = 0.44
const FRACTURE_SECONDS: float = 0.65
const CRACK_EXTEND_SECONDS: float = 0.13
const CRACK_FADE_END_SECONDS: float = 0.32
const CONTACT_RADIUS_START_PX: float = 100.0
const CONTACT_RADIUS_END_PX: float = 260.0
const FRACTURE_REACH_START_PX: float = 90.0
const FRACTURE_REACH_END_PX: float = 470.0
const BURST_RADIUS_MAX_PX: float = 470.0
const MIN_VISUAL_SCALE: float = 0.85
const MAX_SIMULTANEOUS: int = 5
const SEGMENTS: int = 40

var view_camera: Camera3D
var mesh: ImmediateMesh
var instance: MeshInstance3D
var material: StandardMaterial3D
var break_audio: AudioStreamPlayer
var impacts: Array[Dictionary] = []

static func state_color(ratio: float) -> Color:
    if ratio >= 0.60:
        return Color("007aff")
    if ratio >= 0.30:
        return Color("ffe100")
    return Color("ff2140")

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
    # Additive compositing bleaches blue/yellow/red into pale white on bright
    # armor. Alpha blend preserves the actual state hue and a sharp colored rim.
    material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
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
    # V511: the shield fractures horizontally across much of a phone screen.
    # Both halves grow from the impact, with two luminous widths to read at 60Hz.
    var unfold: float = clampf(t / CRACK_EXTEND_SECONDS, 0.0, 1.0)
    var line_fade: float = 1.0 - smoothstep(0.17, CRACK_FADE_END_SECONDS, t)
    var reach: float = lerpf(
        FRACTURE_REACH_START_PX, FRACTURE_REACH_END_PX, unfold) * scale
    for sign_dir in [-1.0, 1.0]:
        var previous: Vector2 = center
        for i in range(1, 9):
            var f: float = float(i) / 8.0
            var jitter: float = sin(float(i) * 2.47 + sign_dir * 1.6) * 10.5
            var current: Vector2 = center + Vector2(
                sign_dir * reach * f, jitter * scale * f)
            var glow := Color(0.02, 0.68, 1.0, 0.88 * line_fade)
            var core := Color(0.92, 0.99, 1.0, line_fade)
            _beam(previous, current, 15.0 * scale, glow, depth)
            _beam(previous, current, 2.8 * scale, core, depth - 0.001)
            previous = current
    # The first crack kicks off a large, airy blue-white radial shock wave.
    # Transparent outer edges keep the underlying body readable.
    var burst: float = clampf((t - 0.025) / 0.49, 0.0, 1.0)
    if burst > 0.0:
        var power: float = 1.0 - smoothstep(0.14, 0.96, burst)
        var radius: float = lerpf(24.0, BURST_RADIUS_MAX_PX, burst) * scale
        var icy := Color(0.72, 0.96, 1.0, 0.72 * power)
        var blue := Color(0.05, 0.65, 1.0, 0.45 * power)
        var ring_peak := Color(0.12, 0.85, 1.0, 0.94 * power)
        var clear := Color(0.12, 0.85, 1.0, 0.0)
        _ring(center, 0.0, radius * 0.20, icy, blue, depth)
        _ring(center, radius * 0.20, radius * 0.70,
            blue, blue, depth)
        _ring(center, radius * 0.70, radius * 0.85,
            blue, ring_peak, depth)
        _ring(center, radius * 0.85, radius,
            ring_peak, clear, depth)

static func contact_radius_px(progress: float) -> float:
    return lerpf(CONTACT_RADIUS_START_PX, CONTACT_RADIUS_END_PX,
        clampf(progress, 0.0, 1.0))

static func contact_opacity(progress: float) -> float:
    # Strong at the very first frame, bright on contact, then a fast cutoff.
    # Keeps 0.44s effect slots for existing overlap/reset semantics.
    var onset: float = lerpf(0.90, 1.0, clampf(progress / 0.06, 0.0, 1.0))
    return onset * (1.0 - smoothstep(0.16, 0.82,
        clampf(progress, 0.0, 1.0)))

static func contact_core_flash(progress: float) -> float:
    # Brief pale spark only at the center: the rest must remain saturated.
    return 1.0 - smoothstep(0.01, 0.24, clampf(progress, 0.0, 1.0))

func _draw_impact(center: Vector2, depth: float, t: float,
        duration: float, tone: Color, scale: float) -> void:
    var progress: float = clampf(t / duration, 0.0, 1.0)
    var opacity: float = contact_opacity(progress)
    var flash: float = contact_core_flash(progress)
    var radius: float = contact_radius_px(progress) * scale
    var core: Color = tone.lerp(Color.WHITE, 0.72 * flash)
    core.a = (0.44 + 0.54 * flash) * opacity
    var inner := Color(tone.r, tone.g, tone.b, 0.49 * opacity)
    var field := Color(tone.r, tone.g, tone.b, 0.39 * opacity)
    var rim := Color(tone.r, tone.g, tone.b, 0.96 * opacity)
    var clear := Color(tone.r, tone.g, tone.b, 0.0)
    # Large translucent colored field, followed by a high-contrast saturated
    # ring with a short transparent fade. No washed-out additive white disk.
    _ring(center, 0.0, radius * 0.11, core, inner, depth)
    _ring(center, radius * 0.11, radius * 0.51, inner, field, depth)
    _ring(center, radius * 0.51, radius * 0.67, field, rim, depth)
    _ring(center, radius * 0.67, radius * 0.81, rim, rim, depth)
    _ring(center, radius * 0.81, radius, rim, clear, depth)

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
        var scale: float = clampf(
            high.distance_to(low) / 270.0, MIN_VISUAL_SCALE, 1.55)
        var age: float = float(entry["elapsed"])
        if bool(entry["broken"]):
            _fracture(center, depth, age, scale)
        else:
            _draw_impact(center, depth, age,
                float(entry["duration"]), entry["color"], scale)
    mesh.surface_end()

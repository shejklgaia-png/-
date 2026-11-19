extends Node3D
## Contact-local radial predictive shield: armor < shield < regular hit sparks.
## The gradient is vertex alpha (no imported texture, no HP bar overlay).
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
# Separate from opaque armor, while still sorting below HIT_SPARKS.
# The larger camera-facing surface needs more clearance at grazing angles.
const SHIELD_SURFACE_OFFSET: float = 0.14
# Six concentric thick-edged octagonal fields, not blurred circles.
const FRAME_COUNT: int = 6
const FRAME_SIDES: int = 8
const EXPAND_SECONDS: float = 0.20
const HOLD_SECONDS: float = 0.20
const FADE_SECONDS: float = 0.20
const IMPACT_SECONDS: float = 0.60
const FRACTURE_SECONDS: float = 0.65
# Shatter crack is a fast horizontal electrical split with transparent tips.
const CRACK_EXTEND_SECONDS: float = 0.065
const CRACK_FADE_END_SECONDS: float = 0.16
const GLASS_SHARD_COUNT: int = 14
const CONTACT_RADIUS_START_PX: float = 100.0
const CONTACT_RADIUS_END_PX: float = 260.0
const FRACTURE_REACH_START_PX: float = 90.0
const FRACTURE_REACH_END_PX: float = 470.0
const BURST_RADIUS_MAX_PX: float = 470.0
const MIN_VISUAL_SCALE: float = 0.85
const MAX_SIMULTANEOUS: int = 5

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
    instance.name = "EnemyShieldSixOctagonContactFX"
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
        # Generate once: shards must not rerandomize during redraw/animation.
        "shards": _make_glass_shards() if broken else [],
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

static func _octagon_direction(index: int) -> Vector2:
    var angle: float = TAU * float(index) / float(FRAME_SIDES) + PI / 8.0
    return Vector2(cos(angle), sin(angle))

func _octagon_disc(center: Vector2, radius: float,
        color: Color, depth: float) -> void:
    # Preserve the earlier "no missing center" instruction on intact hits.
    for i in range(FRAME_SIDES):
        var a: Vector2 = center + _octagon_direction(i) * radius
        var b: Vector2 = center + _octagon_direction((i + 1) % FRAME_SIDES) * radius
        _tri(center, a, b, color, color, color, depth)

func _octagon_frame(center: Vector2, radius: float, thickness: float,
        color: Color, depth: float) -> void:
    # Exactly 8 flat sides, uniform alpha across the entire thick polygon
    # perimeter. No gradient, feathered mask or blurred outer edges.
    var inner_radius: float = maxf(1.0, radius - thickness)
    for i in range(FRAME_SIDES):
        var va: Vector2 = _octagon_direction(i)
        var vb: Vector2 = _octagon_direction((i + 1) % FRAME_SIDES)
        var ia: Vector2 = center + va * inner_radius
        var ib: Vector2 = center + vb * inner_radius
        var oa: Vector2 = center + va * radius
        var ob: Vector2 = center + vb * radius
        _tri(ia, oa, ob, color, color, color, depth)
        _tri(ia, ob, ib, color, color, color, depth)

static func visible_frame_count(t: float) -> int:
    if t < 0.0 or t >= IMPACT_SECONDS:
        return 0
    var total: int = 0
    for i in range(FRAME_COUNT):
        if t + 0.00001 >= float(i) * EXPAND_SECONDS / float(FRAME_COUNT):
            total += 1
    return total

static func frame_alpha(index: int, t: float) -> float:
    if index < 0 or index >= FRAME_COUNT or t >= IMPACT_SECONDS:
        return 0.0
    var delay: float = float(index) * EXPAND_SECONDS / float(FRAME_COUNT)
    if t < delay:
        return 0.0
    var local: float = clampf(
        (t - delay) / (EXPAND_SECONDS / float(FRAME_COUNT)), 0.0, 1.0)
    var intro: float = 0.25 + 0.75 * smoothstep(0.0, 1.0, local)
    var fade: float = 1.0 - smoothstep(
        EXPAND_SECONDS + HOLD_SECONDS, IMPACT_SECONDS, t)
    # Outer octagons become systematically more transparent.
    return (0.95 - float(index) * 0.12) * intro * fade

static func contact_radius_px(progress: float) -> float:
    return lerpf(CONTACT_RADIUS_START_PX, CONTACT_RADIUS_END_PX,
        clampf(progress, 0.0, 1.0))

static func contact_opacity(progress: float) -> float:
    # Kept for earlier impact intensity regressions; each frame's real
    # envelope is driven by frame_alpha and the three 0.2-second phases.
    var onset: float = lerpf(0.90, 1.0, clampf(progress / 0.06, 0.0, 1.0))
    return onset * (1.0 - smoothstep(0.16, 0.82,
        clampf(progress, 0.0, 1.0)))

static func contact_core_flash(progress: float) -> float:
    return 1.0 - smoothstep(0.01, 0.24, clampf(progress, 0.0, 1.0))

static func membrane_center_color(
        tone: Color, opacity: float, flash: float) -> Color:
    var core: Color = tone.lerp(Color.WHITE, 0.38 * flash)
    core.a = 0.94 * opacity
    return core

func _draw_impact(center: Vector2, depth: float, t: float,
        duration: float, tone: Color, scale: float) -> void:
    var outer_radius: float = contact_radius_px(
        clampf(t / EXPAND_SECONDS, 0.0, 1.0)) * scale
    var inner_alpha: float = frame_alpha(0, t)
    if inner_alpha > 0.0:
        var flash: float = contact_core_flash(t / duration)
        var core: Color = membrane_center_color(tone, inner_alpha, flash)
        var core_radius: float = outer_radius / float(FRAME_COUNT) * 0.55
        _octagon_disc(center, core_radius, core, depth)
    for i in range(FRAME_COUNT):
        var alpha: float = frame_alpha(i, t)
        if alpha <= 0.0:
            continue
        var delay: float = float(i) * EXPAND_SECONDS / float(FRAME_COUNT)
        var emerge: float = smoothstep(0.0, 1.0,
            clampf((t - delay) * float(FRAME_COUNT) / EXPAND_SECONDS, 0.0, 1.0))
        var radius: float = outer_radius * (
            float(i + 1) / float(FRAME_COUNT)) * lerpf(0.82, 1.0, emerge)
        var thickness: float = (12.0 + float(i) * 1.7) * scale
        var frame_color := Color(tone.r, tone.g, tone.b, alpha)
        _octagon_frame(center, radius, thickness, frame_color, depth)

static func crack_tip_opacity(progress: float) -> float:
    return 1.0 - smoothstep(0.68, 1.0, clampf(progress, 0.0, 1.0))

func _beam_taper(a: Vector2, b: Vector2, half_width: float,
        near_color: Color, far_color: Color, depth: float) -> void:
    # Constant-width lightning with a fading *lengthwise* tip, not blur.
    var along: Vector2 = b - a
    if along.length_squared() < 0.001:
        return
    var normal: Vector2 = Vector2(-along.y, along.x).normalized() * half_width
    _tri(a - normal, b - normal, b + normal,
        near_color, far_color, far_color, depth)
    _tri(a - normal, b + normal, a + normal,
        near_color, far_color, near_color, depth)

func _make_glass_shards() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var result: Array = []
    for i in range(GLASS_SHARD_COUNT):
        result.append({
            "angle": TAU * (float(i) + rng.randf_range(-0.34, 0.34)) /
                float(GLASS_SHARD_COUNT),
            "speed": rng.randf_range(0.82, 1.42),
            "spin": rng.randf_range(-2.7, 2.7),
            "length": rng.randf_range(55.0, 110.0),
            "width": rng.randf_range(30.0, 68.0),
            "tilt": rng.randf_range(-0.4, 0.4),
        })
    return result

func _draw_glass_shard(center: Vector2, depth: float, shard: Dictionary,
        t: float, scale: float) -> void:
    var decay: float = 1.0 - smoothstep(0.35, 0.62, t)
    if decay <= 0.0:
        return
    var angle: float = float(shard["angle"])
    var travel: float = clampf(t / 0.52, 0.0, 1.0)
    var displacement: float = (
        44.0 + 270.0 * pow(travel, 0.76)) * float(shard["speed"]) * scale
    var center_piece: Vector2 = center + Vector2(cos(angle), sin(angle)) * displacement
    var rotation: float = angle + float(shard["tilt"]) + float(shard["spin"]) * t
    var axis: Vector2 = Vector2(cos(rotation), sin(rotation))
    var side: Vector2 = Vector2(-axis.y, axis.x)
    var length: float = float(shard["length"]) * scale
    var width: float = float(shard["width"]) * scale
    # Two large hard-edged triangular facets form a single glass-like shard.
    var a: Vector2 = center_piece - axis * (length * 0.46) - side * (width * 0.20)
    var b: Vector2 = center_piece - axis * (length * 0.11) + side * (width * 0.56)
    var c: Vector2 = center_piece + axis * (length * 0.56) + side * (width * 0.08)
    var d: Vector2 = center_piece + axis * (length * 0.05) - side * (width * 0.50)
    var bright := Color(0.76, 0.96, 1.0, 0.88 * decay)
    var cyan := Color(0.10, 0.77, 1.0, 0.76 * decay)
    _tri(a, b, c, bright, bright, bright, depth)
    _tri(a, c, d, cyan, cyan, cyan, depth)

func _fracture(center: Vector2, depth: float, t: float,
        scale: float, entry: Dictionary) -> void:
    # Horizontal crack: fast split, then the energy vanishes outward toward
    # two alpha-zero endpoints. Never leave a blurred halo on the screen.
    var extend: float = clampf(t / CRACK_EXTEND_SECONDS, 0.0, 1.0)
    var flash: float = 1.0 - smoothstep(0.065, CRACK_FADE_END_SECONDS, t)
    if flash > 0.0:
        var reach: float = lerpf(FRACTURE_REACH_START_PX,
            FRACTURE_REACH_END_PX, extend) * scale
        for sign_dir in [-1.0, 1.0]:
            var previous: Vector2 = center
            for i in range(1, 9):
                var f0: float = float(i - 1) / 8.0
                var f1: float = float(i) / 8.0
                var jitter: float = sin(float(i) * 2.47 + sign_dir * 1.6) * 7.0
                var current: Vector2 = center + Vector2(
                    sign_dir * reach * f1, jitter * scale * f1)
                var near_a: float = flash * crack_tip_opacity(f0)
                var far_a: float = flash * crack_tip_opacity(f1)
                _beam_taper(previous, current, 12.0 * scale,
                    Color(0.02, 0.68, 1.0, 0.85 * near_a),
                    Color(0.02, 0.68, 1.0, 0.85 * far_a), depth)
                _beam_taper(previous, current, 2.8 * scale,
                    Color(0.92, 0.98, 1.0, near_a),
                    Color(0.92, 0.98, 1.0, far_a), depth - 0.001)
                previous = current
    # Reuse randomized shard descriptors across frames; no circular blurred
    # shockwave, soft gradients, or centrally filled shatter mesh.
    var shard_data: Array = entry["shards"]
    for shard in shard_data:
        _draw_glass_shard(center, depth, shard, t, scale)

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
            _fracture(center, depth, age, scale, entry)
        else:
            _draw_impact(center, depth, age,
                float(entry["duration"]), entry["color"], scale)
    mesh.surface_end()

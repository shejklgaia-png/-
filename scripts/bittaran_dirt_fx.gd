extends Node3D
## Reusable procedural earth/dust impacts for the three authored boss moves.
## Particles have no collision; all damage is still owned by battle.gd.
## Emission requires ground contact measured from the rendered foot mesh.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
# v465: nuanced sandy-brown/grey impact dust; all three moves share
# the same runtime-generated noise/alpha sprite (96x96), no asset PNG.
const DUST_COLOR: Color = Color(0.69, 0.63, 0.55, 0.72)
const EARTH_COLOR: Color = Color(0.31, 0.28, 0.24, 1.0)
const DUST_SPRITE_SIZE: int = 96
const SWEEP_EMISSION_INTERVAL: float = 0.075

var dust_sprite_mesh: QuadMesh
var stomp_core: CPUParticles3D
var stomp_dust: CPUParticles3D
var stomp_ground: CPUParticles3D
var stomp_chunks: CPUParticles3D
var kick_dust: CPUParticles3D
var kick_chunks: CPUParticles3D
var sweep_dust: CPUParticles3D
var sweep_chunks: CPUParticles3D
var sweep_elapsed: float = 0.0
var sweep_active: bool = false
var kicked_this_attack: bool = false
var stomped_this_attack: bool = false
var last_kind: String = ""

## Generated ONCE at startup; 96^2 RGBA8 pixels (~36 KiB).
## Soft feathered outline, turbulent internal opacity and uneven rim
## replace the former solid low-poly sphere "popcorn" dust blobs.
## A single sprite material is shared by every fog emitter.
func _build_dust_sprite() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 46512
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 3
    noise.frequency = 0.048
    var atlas: Image = Image.create(
        DUST_SPRITE_SIZE, DUST_SPRITE_SIZE, false, Image.FORMAT_RGBA8)
    var radius_denominator: float = float(DUST_SPRITE_SIZE) * 0.5
    for y in range(DUST_SPRITE_SIZE):
        for x in range(DUST_SPRITE_SIZE):
            var uv: Vector2 = Vector2(
                (float(x) + 0.5 - radius_denominator)
                    / radius_denominator,
                (float(y) + 0.5 - radius_denominator)
                    / radius_denominator)
            var distance: float = uv.length()
            var turbulence: float = noise.get_noise_2d(
                float(x), float(y))
            var fine: float = noise.get_noise_2d(
                float(x) + 180.0, float(y) + 273.0)
            var edge_radius: float = 0.79 + turbulence * 0.18
            var feather: float = clampf(
                (edge_radius - distance) / 0.38, 0.0, 1.0)
            feather = feather * feather * (3.0 - 2.0 * feather)
            var heart: float = clampf(1.0 - distance, 0.0, 1.0)
            var density: float = clampf(
                0.72 + turbulence * 0.22 + fine * 0.18,
                0.25, 1.0)
            var opacity: float = feather * density * (
                0.30 + 0.46 * heart)
            var tone: float = clampf(
                0.90 + turbulence * 0.055 + fine * 0.04,
                0.74, 0.99)
            atlas.set_pixel(x, y, Color(
                tone, tone * 0.955, tone * 0.89, opacity))
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.vertex_color_use_as_albedo = true
    material.albedo_color = Color.WHITE
    material.albedo_texture = ImageTexture.create_from_image(atlas)
    material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    dust_sprite_mesh = QuadMesh.new()
    dust_sprite_mesh.size = Vector2(0.78, 0.78)
    dust_sprite_mesh.material = material


## The alpha fade is on per-particle vertex color. The shared
## StandardMaterial3D must opt into vertex color for this to render.
func _make_dust_fade() -> Gradient:
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.08))
    ramp.add_point(0.10, Color(1.0, 1.0, 1.0, 0.95))
    ramp.add_point(0.40, Color(1.0, 1.0, 1.0, 0.70))
    ramp.add_point(0.73, Color(1.0, 1.0, 1.0, 0.30))
    ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    return ramp


func _make_dust_scale() -> Curve:
    var growing := Curve.new()
    growing.add_point(Vector2(0.0, 0.42))
    growing.add_point(Vector2(0.42, 0.84))
    growing.add_point(Vector2(1.0, 1.0))
    return growing


func _make_particles(name: String, dust: bool,
        one_shot: bool, count: int) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = name
    p.one_shot = one_shot
    p.emitting = false
    # Stagger the particles slightly, so impacts are not a rigid
    # single-frame wall. Never emit continuously for a stomp.
    p.local_coords = false
    p.explosiveness = 0.91 if one_shot else 0.0
    p.amount = count
    p.lifetime = 0.98 if dust else 0.74
    p.direction = Vector3.UP
    p.spread = 58.0 if dust else 45.0
    p.gravity = Vector3(0.0, -0.60, 0.0) if dust else Vector3(0.0, -8.0, 0.0)
    p.initial_velocity_min = 0.8 if dust else 2.0
    p.initial_velocity_max = 2.5 if dust else 4.2
    p.color = DUST_COLOR if dust else EARTH_COLOR
    if dust:
        p.mesh = dust_sprite_mesh
        p.color_ramp = _make_dust_fade()
        p.scale_amount_curve = _make_dust_scale()
        p.scale_amount_min = 0.80
        p.scale_amount_max = 1.65
        p.damping_min = 0.2
        p.damping_max = 0.7
        p.angular_velocity_min = -28.0
        p.angular_velocity_max = 28.0
    else:
        var pebble := BoxMesh.new()
        pebble.size = Vector3(0.07, 0.04, 0.065)
        var stone := StandardMaterial3D.new()
        stone.albedo_color = Color(0.70, 0.66, 0.61, 1.0)
        pebble.material = stone
        p.mesh = pebble
        p.scale_amount_min = 0.45
        p.scale_amount_max = 1.40
        p.angular_velocity_min = -210.0
        p.angular_velocity_max = 210.0
    add_child(p)
    return p


func _ready() -> void:
    _build_dust_sprite()
    # 4 inexpensive layers: darker heart, airborne turbulent haze,
    # low rolling dust and a few genuinely 3D grit pieces.
    # About 110 tiny quad/box particles at the most intense frame;
    # no full-screen translucent image or 3D smoke simulation.
    stomp_core = _make_particles("StompCompactDust", true, true, 25)
    stomp_core.color = Color(0.49, 0.42, 0.36, 0.81)
    stomp_core.spread = 44.0
    stomp_core.initial_velocity_min = 0.75
    stomp_core.initial_velocity_max = 2.15
    stomp_core.gravity = Vector3(0.0, -0.42, 0.0)
    stomp_core.lifetime = 1.0
    stomp_core.scale_amount_min = 1.0
    stomp_core.scale_amount_max = 1.9

    stomp_dust = _make_particles("StompRisingDust", true, true, 42)
    stomp_dust.color = Color(0.73, 0.68, 0.61, 0.67)
    stomp_dust.spread = 30.0
    stomp_dust.initial_velocity_min = 2.0
    stomp_dust.initial_velocity_max = 4.7
    stomp_dust.gravity = Vector3(0.0, -0.70, 0.0)
    stomp_dust.lifetime = 1.30
    stomp_dust.scale_amount_min = 0.70
    stomp_dust.scale_amount_max = 1.48

    stomp_ground = _make_particles("StompRollingDust", true, true, 26)
    stomp_ground.color = Color(0.65, 0.59, 0.52, 0.54)
    stomp_ground.spread = 85.0
    stomp_ground.initial_velocity_min = 0.35
    stomp_ground.initial_velocity_max = 1.40
    # This layer stays low rather than looking like a second plume.
    stomp_ground.gravity = Vector3(0.0, -0.85, 0.0)
    stomp_ground.lifetime = 1.18
    stomp_ground.scale_amount_min = 0.85
    stomp_ground.scale_amount_max = 1.85

    stomp_chunks = _make_particles("StompEarthChunks", false, true, 19)
    stomp_chunks.spread = 42.0
    stomp_chunks.initial_velocity_min = 2.2
    stomp_chunks.initial_velocity_max = 4.8
    stomp_chunks.gravity = Vector3(0.0, -9.2, 0.0)
    stomp_chunks.lifetime = 0.75
    stomp_chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX

    kick_dust = _make_particles("KickGroundDust", true, true, 19)
    kick_chunks = _make_particles("KickEjectedDirt", false, true, 22)
    sweep_dust = _make_particles("SweepDustTrail", true, false, 34)
    sweep_dust.color = Color(0.66, 0.62, 0.56, 0.50)
    sweep_dust.initial_velocity_max = 1.3
    sweep_dust.lifetime = 0.88
    sweep_chunks = _make_particles("SweepScatteredEarth", false, true, 10)


func _burst(p: CPUParticles3D, point: Vector3,
        direction: Vector3) -> void:
    p.global_position = point
    p.direction = direction.normalized()
    p.restart()
    p.emitting = true


func emit_stomp(point: Vector3,
        half_extents: Vector2 = Vector2(0.35, 0.35)) -> void:
    var origin := Vector3(point.x, 0.04, point.z)
    # The plume starts under the 1.5x foot-wide impact patch,
    # then rises into the air. Particle gravity brings it down later.
    var spread: Vector3 = Vector3(
        maxf(half_extents.x, 0.05), 0.03,
        maxf(half_extents.y, 0.05))
    # Dense core is tight, the high plume is moderately spread and
    # rolling dust covers the full foot-sized contact patch.
    stomp_core.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    stomp_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    stomp_ground.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    stomp_core.emission_box_extents = spread * 0.50
    stomp_dust.emission_box_extents = spread * 0.82
    stomp_ground.emission_box_extents = spread * 1.12
    stomp_chunks.emission_box_extents = spread * 0.64
    _burst(stomp_core, origin, Vector3.UP)
    _burst(stomp_dust, origin, Vector3.UP)
    _burst(stomp_ground, origin, Vector3.UP)
    _burst(stomp_chunks, origin, Vector3.UP)


func emit_kick(point: Vector3, outward: Vector3) -> void:
    var planar: Vector3 = Vector3(outward.x, 0.0, outward.z)
    if planar.length_squared() < 0.000001:
        planar = Vector3.FORWARD
    var flow: Vector3 = (planar.normalized() * 1.35
        + Vector3.UP * 0.38).normalized()
    var origin := Vector3(point.x, 0.04, point.z)
    _burst(kick_dust, origin, flow)
    _burst(kick_chunks, origin, flow)


func trace_sweep(point: Vector3, delta: float) -> void:
    sweep_active = true
    var origin := Vector3(point.x, 0.05, point.z)
    sweep_dust.global_position = origin
    sweep_dust.direction = Vector3.UP
    sweep_dust.emitting = true
    sweep_elapsed += maxf(delta, 0.0)
    if sweep_elapsed >= SWEEP_EMISSION_INTERVAL:
        sweep_elapsed = fposmod(sweep_elapsed, SWEEP_EMISSION_INTERVAL)
        _burst(sweep_chunks, origin, Vector3.UP)


func end_sweep() -> void:
    sweep_active = false
    if sweep_dust != null:
        sweep_dust.emitting = false


func reset() -> void:
    end_sweep()
    sweep_elapsed = 0.0
    kicked_this_attack = false
    stomped_this_attack = false
    last_kind = ""
    for p in [stomp_core, stomp_dust, stomp_ground, stomp_chunks,
            kick_dust, kick_chunks, sweep_dust, sweep_chunks]:
        if p != null:
            p.emitting = false


func advance_attack(frame: Dictionary, point: Vector3,
        previous_point: Vector3, delta: float,
        foot_grounded: bool = false) -> void:
    var kind: String = str(frame.get("kind", ""))
    if kind != last_kind or frame.is_empty():
        end_sweep()
        kicked_this_attack = false
        stomped_this_attack = false
        last_kind = kind
    if frame.is_empty():
        return
    var elapsed: float = float(frame.get("time", 0.0))
    var windup: float = float(frame.get("windup", 0.7))
    var strike: float = float(frame.get("strike", 1.0))
    var striking: bool = elapsed >= windup and elapsed <= windup + strike
    if kind == "stomp":
        # Stomp ring + both particle bursts are issued together by
        # _emit_bittaran_shockwave on its single real contact tick.
        pass
    elif kind == "kick":
        if striking and foot_grounded and not kicked_this_attack:
            var travel: Vector3 = point - previous_point
            travel.y = 0.0
            # Emit from the ground where the authored foot actually
            # accelerates, toward the authored kick direction.
            if travel.length_squared() > 0.0036 or elapsed > windup + 0.15:
                emit_kick(point, travel)
                kicked_this_attack = true
    elif kind == "sweep":
        # Releasing the foot from the ground ends the active emitter
        # immediately. Existing airborne particles can finish fading.
        if striking and foot_grounded:
            trace_sweep(point, delta)
        else:
            end_sweep()

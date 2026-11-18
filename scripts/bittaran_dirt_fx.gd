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
# v466: deliberately different physically readable dust/material layers.
# Two tiny procedural sprites, no extra PNG or mobile shader pass.
const DENSE_SOIL_PARTICLES: int = 38
const RISING_POWDER_PARTICLES: int = 54
const ROLLING_SAND_PARTICLES: int = 34
const FLOATING_FINES_PARTICLES: int = 26
const ROCK_CHUNKS_PARTICLES: int = 22
const FLYING_GRIT_PARTICLES: int = 35

var dust_sprite_mesh: QuadMesh
var dense_soil_sprite_mesh: QuadMesh
var stomp_core: CPUParticles3D
var stomp_dust: CPUParticles3D
var stomp_ground: CPUParticles3D
var stomp_fines: CPUParticles3D
var stomp_chunks: CPUParticles3D
var stomp_grit: CPUParticles3D
var kick_dust: CPUParticles3D
var kick_forward_dust: CPUParticles3D
var kick_trailing_dust: CPUParticles3D
var kick_chunks: CPUParticles3D
var kick_grit: CPUParticles3D
var sweep_dust: CPUParticles3D
var sweep_chunks: CPUParticles3D
var sweep_elapsed: float = 0.0
var sweep_active: bool = false
var kicked_this_attack: bool = false
var kick_last_direction: Vector3 = Vector3.ZERO
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
    # Independent high-density, jagged soil-cloud texture. It has a
    # more compact/opaque body than the airy powder sprite.
    var dense_atlas: Image = Image.create(
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
            var clumps: float = noise.get_noise_2d(
                float(x) + 319.0, float(y) + 178.0)
            var coarse_rim: float = 0.77 + clumps * 0.19
            var coarse_feather: float = clampf(
                (coarse_rim - distance) / 0.23, 0.0, 1.0)
            coarse_feather = coarse_feather * coarse_feather * (
                3.0 - 2.0 * coarse_feather)
            var coarse_density: float = clampf(
                0.86 + clumps * 0.21 + fine * 0.15,
                0.49, 1.0)
            var coarse_opacity: float = coarse_feather * (
                0.73 + heart * 0.22) * coarse_density
            var coarse_tone: float = clampf(
                0.83 + clumps * 0.14 + fine * 0.04,
                0.64, 0.98)
            dense_atlas.set_pixel(x, y, Color(
                coarse_tone, coarse_tone * 0.96,
                coarse_tone * 0.91, coarse_opacity))
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
    var dense_material: StandardMaterial3D = (
        material.duplicate() as StandardMaterial3D)
    dense_material.albedo_texture = ImageTexture.create_from_image(
        dense_atlas)
    dense_soil_sprite_mesh = QuadMesh.new()
    dense_soil_sprite_mesh.size = Vector2(0.90, 0.90)
    dense_soil_sprite_mesh.material = dense_material


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
        one_shot: bool, count: int,
        substance: String = "") -> CPUParticles3D:
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
        p.mesh = (dense_soil_sprite_mesh
            if substance == "soil" else dust_sprite_mesh)
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
        pebble.size = (
            Vector3(0.030, 0.022, 0.038)
            if substance == "grit"
            else Vector3(0.10, 0.065, 0.088))
        var stone := StandardMaterial3D.new()
        stone.albedo_color = (
            Color(0.78, 0.66, 0.49, 1.0)
            if substance == "grit"
            else Color(0.39, 0.35, 0.31, 1.0))
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
    # Dense brown SOIL, translucent pale POWDER, lateral SAND,
    # slowly suspended fines, big rocks and tiny fast grit each
    # carry a different silhouette, tone, size, speed and gravity.
    stomp_core = _make_particles(
        "StompCompactSoil", true, true, DENSE_SOIL_PARTICLES, "soil")
    stomp_core.color = Color(0.43, 0.34, 0.27, 0.96)
    stomp_core.spread = 39.0
    stomp_core.initial_velocity_min = 0.75
    stomp_core.initial_velocity_max = 2.20
    stomp_core.gravity = Vector3(0.0, -0.48, 0.0)
    stomp_core.lifetime = 1.18
    stomp_core.scale_amount_min = 1.12
    stomp_core.scale_amount_max = 2.08

    stomp_dust = _make_particles(
        "StompRisingPowder", true, true, RISING_POWDER_PARTICLES)
    stomp_dust.color = Color(0.79, 0.74, 0.68, 0.77)
    stomp_dust.spread = 31.0
    stomp_dust.initial_velocity_min = 2.15
    stomp_dust.initial_velocity_max = 4.90
    stomp_dust.gravity = Vector3(0.0, -0.62, 0.0)
    stomp_dust.lifetime = 1.42
    stomp_dust.scale_amount_min = 0.72
    stomp_dust.scale_amount_max = 1.60

    stomp_ground = _make_particles(
        "StompRollingSand", true, true, ROLLING_SAND_PARTICLES,
        "soil")
    stomp_ground.color = Color(0.64, 0.54, 0.43, 0.83)
    stomp_ground.spread = 79.0
    stomp_ground.initial_velocity_min = 0.42
    stomp_ground.initial_velocity_max = 1.55
    stomp_ground.gravity = Vector3(0.0, -0.91, 0.0)
    stomp_ground.lifetime = 1.02
    stomp_ground.scale_amount_min = 0.65
    stomp_ground.scale_amount_max = 1.45

    stomp_fines = _make_particles(
        "StompSuspendedFines", true, true, FLOATING_FINES_PARTICLES)
    stomp_fines.color = Color(0.87, 0.82, 0.77, 0.48)
    stomp_fines.spread = 49.0
    stomp_fines.initial_velocity_min = 0.60
    stomp_fines.initial_velocity_max = 2.35
    stomp_fines.gravity = Vector3(0.0, -0.20, 0.0)
    stomp_fines.lifetime = 1.85
    stomp_fines.scale_amount_min = 0.38
    stomp_fines.scale_amount_max = 1.04

    stomp_chunks = _make_particles(
        "StompDarkRockFragments", false, true,
        ROCK_CHUNKS_PARTICLES)
    stomp_chunks.spread = 43.0
    stomp_chunks.initial_velocity_min = 2.10
    stomp_chunks.initial_velocity_max = 4.80
    stomp_chunks.gravity = Vector3(0.0, -9.2, 0.0)
    stomp_chunks.lifetime = 0.79
    stomp_chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX

    stomp_grit = _make_particles(
        "StompFlyingSandGrit", false, true,
        FLYING_GRIT_PARTICLES, "grit")
    stomp_grit.spread = 62.0
    stomp_grit.initial_velocity_min = 2.80
    stomp_grit.initial_velocity_max = 5.60
    stomp_grit.gravity = Vector3(0.0, -11.3, 0.0)
    stomp_grit.lifetime = 0.55
    stomp_grit.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX

    # Kick/flick: five distinct directionally ejected layers.
    kick_forward_dust = _make_particles(
        "KickForwardSoilJet", true, true, 33, "soil")
    kick_forward_dust.color = Color(0.43, 0.34, 0.27, 0.95)
    kick_forward_dust.spread = 18.0
    kick_forward_dust.initial_velocity_min = 3.5
    kick_forward_dust.initial_velocity_max = 6.0
    kick_forward_dust.gravity = Vector3(0.0, -1.0, 0.0)
    kick_forward_dust.lifetime = 1.07
    kick_forward_dust.scale_amount_min = 0.75
    kick_forward_dust.scale_amount_max = 1.72

    kick_dust = _make_particles(
        "KickFineForwardPowder", true, true, 35)
    kick_dust.color = Color(0.81, 0.74, 0.67, 0.79)
    kick_dust.spread = 25.0
    kick_dust.initial_velocity_min = 2.5
    kick_dust.initial_velocity_max = 5.0
    kick_dust.gravity = Vector3(0.0, -0.50, 0.0)
    kick_dust.lifetime = 1.37
    kick_dust.scale_amount_min = 0.65
    kick_dust.scale_amount_max = 1.44

    kick_trailing_dust = _make_particles(
        "KickBackwardResidualDust", true, true, 18, "soil")
    kick_trailing_dust.color = Color(0.55, 0.47, 0.39, 0.68)
    kick_trailing_dust.spread = 57.0
    kick_trailing_dust.initial_velocity_min = 0.45
    kick_trailing_dust.initial_velocity_max = 1.55
    kick_trailing_dust.gravity = Vector3(0.0, -0.95, 0.0)
    kick_trailing_dust.lifetime = 0.94
    kick_trailing_dust.scale_amount_min = 0.68
    kick_trailing_dust.scale_amount_max = 1.19

    kick_chunks = _make_particles(
        "KickForwardRockFragments", false, true, 22)
    kick_chunks.spread = 17.0
    kick_chunks.initial_velocity_min = 3.55
    kick_chunks.initial_velocity_max = 6.45
    kick_chunks.gravity = Vector3(0.0, -9.4, 0.0)
    kick_chunks.lifetime = 0.80
    kick_chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX

    kick_grit = _make_particles(
        "KickDirectionalFineGrit", false, true, 34, "grit")
    kick_grit.spread = 15.0
    kick_grit.initial_velocity_min = 4.00
    kick_grit.initial_velocity_max = 6.90
    kick_grit.gravity = Vector3(0.0, -11.0, 0.0)
    kick_grit.lifetime = 0.59
    kick_grit.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX

    sweep_dust = _make_particles("SweepDustTrail", true, false, 34)
    sweep_dust.color = Color(0.66, 0.62, 0.56, 0.50)
    sweep_dust.initial_velocity_max = 1.3
    sweep_dust.lifetime = 0.88
    sweep_chunks = _make_particles(
        "SweepScatteredEarth", false, true, 10)


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
    for p in [stomp_core, stomp_dust, stomp_ground, stomp_fines]:
        p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    stomp_core.emission_box_extents = spread * 0.51
    stomp_dust.emission_box_extents = spread * 0.83
    stomp_ground.emission_box_extents = spread * 1.13
    stomp_fines.emission_box_extents = spread * 0.76
    stomp_chunks.emission_box_extents = spread * 0.63
    stomp_grit.emission_box_extents = spread * 0.90
    for p in [stomp_core, stomp_dust, stomp_ground, stomp_fines,
            stomp_chunks, stomp_grit]:
        _burst(p, origin, Vector3.UP)


func emit_kick(point: Vector3, outward: Vector3) -> void:
    var planar: Vector3 = Vector3(outward.x, 0.0, outward.z)
    if planar.length_squared() <= 0.000001:
        planar = Vector3.FORWARD
    var forward: Vector3 = planar.normalized()
    # The material jet is biased decisively along the actual flick
    # direction; rock/grit has a tighter cone and ballistic gravity.
    var soil_jet: Vector3 = (
        forward * 1.90 + Vector3.UP * 0.27).normalized()
    var powder_jet: Vector3 = (
        forward * 1.32 + Vector3.UP * 0.53).normalized()
    var debris_jet: Vector3 = (
        forward * 1.76 + Vector3.UP * 0.39).normalized()
    var residue: Vector3 = (
        -forward * 0.22 + Vector3.UP * 0.52).normalized()
    var origin: Vector3 = Vector3(point.x, 0.04, point.z)
    var ahead: Vector3 = origin + forward * 0.08
    _burst(kick_forward_dust, ahead, soil_jet)
    _burst(kick_dust, ahead, powder_jet)
    _burst(kick_chunks, ahead, debris_jet)
    _burst(kick_grit, ahead, debris_jet)
    _burst(kick_trailing_dust, origin, residue)


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
    kick_last_direction = Vector3.ZERO
    stomped_this_attack = false
    last_kind = ""
    for p in [stomp_core, stomp_dust, stomp_ground, stomp_fines,
            stomp_chunks, stomp_grit, kick_forward_dust, kick_dust,
            kick_trailing_dust, kick_chunks, kick_grit,
            sweep_dust, sweep_chunks]:
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

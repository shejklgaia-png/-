extends Node3D
## Reusable procedural earth/dust impacts for the three authored boss moves.
## Particles have no collision; all damage is still owned by battle.gd.
## Emission requires ground contact measured from the rendered foot mesh.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const DUST_COLOR: Color = Color(0.48, 0.46, 0.43, 0.68)
const EARTH_COLOR: Color = Color(0.35, 0.33, 0.30, 1.0)
const SWEEP_EMISSION_INTERVAL: float = 0.075

var stomp_dust: CPUParticles3D
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

func _make_particles(name: String, dust: bool,
        one_shot: bool, count: int) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = name
    p.one_shot = one_shot
    p.emitting = false
    p.local_coords = false
    p.explosiveness = 0.98 if one_shot else 0.0
    p.amount = count
    p.lifetime = 0.72 if dust else 0.60
    p.direction = Vector3.UP
    p.spread = 65.0 if dust else 42.0
    p.gravity = Vector3(0.0, -2.1, 0.0) if dust else Vector3(0.0, -8.0, 0.0)
    p.initial_velocity_min = 0.65 if dust else 2.2
    p.initial_velocity_max = 2.40 if dust else 5.2
    p.color = DUST_COLOR if dust else EARTH_COLOR
    var mesh: PrimitiveMesh
    if dust:
        var cloud := SphereMesh.new()
        cloud.radius = 0.16
        cloud.height = 0.32
        cloud.radial_segments = 6
        cloud.rings = 3
        mesh = cloud
    else:
        var debris := BoxMesh.new()
        debris.size = Vector3(0.11, 0.065, 0.13)
        mesh = debris
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color.WHITE
    if dust:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.albedo_color.a = 0.70
        mat.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    mesh.material = mat
    p.mesh = mesh
    add_child(p)
    return p


func _ready() -> void:
    stomp_dust = _make_particles("StompRisingDust", true, true, 36)
    stomp_chunks = _make_particles("StompEarthChunks", false, true, 30)
    kick_dust = _make_particles("KickGroundDust", true, true, 22)
    kick_chunks = _make_particles("KickEjectedDirt", false, true, 34)
    sweep_dust = _make_particles("SweepDustTrail", true, false, 50)
    sweep_chunks = _make_particles("SweepScatteredEarth", false, true, 12)


func _burst(p: CPUParticles3D, point: Vector3,
        direction: Vector3) -> void:
    p.global_position = point
    p.direction = direction.normalized()
    p.restart()
    p.emitting = true


func emit_stomp(point: Vector3) -> void:
    var origin := Vector3(point.x, 0.04, point.z)
    _burst(stomp_dust, origin, Vector3.UP)
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
    for p in [stomp_dust, stomp_chunks, kick_dust,
            kick_chunks, sweep_dust, sweep_chunks]:
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

extends SceneTree
## v454: Effects must be dense, grayscale, ground-anchored and follow
## the actual post-IK toe stroke. No artificial off-foot origin.
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_GROUND_FX_REBUILD_FAIL " + message)
    quit(1)


func _near_xz(a: Vector3, b: Vector3, radius: float) -> bool:
    return Vector2(a.x - b.x, a.z - b.z).length() <= radius


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var boss: Node3D = battle.get("target")
    if fx == null or boss == null:
        _fail("battle FX/boss was not instantiated")
        return
    # Every reflected foot's actual lowest world-space sole must
    # generate an FX anchor inside the rendered mesh's world AABB.
    for id in IDS:
        var bounds: AABB = battle.call(
            "_bittaran_attack_foot_bounds", id)
        var point: Vector3 = battle.call(
            "_bittaran_ground_fx_contact", id)
        if not bounds.has_volume() or absf(
                point.y - bounds.position.y) > 0.001:
            _fail("incorrect ground surface " + str([id, point, bounds]))
            return
        if point.x < bounds.position.x - 0.001 or (
                point.x > bounds.end.x + 0.001) or (
                point.z < bounds.position.z - 0.001) or (
                point.z > bounds.end.z + 0.001):
            _fail("FX point detached from toe " + str([id, point, bounds]))
            return
    # The dust generator is world-anchored even when its parent moves.
    fx.position = Vector3(-4.0, 0.0, 7.0)
    var sole: Vector3 = Vector3(12.0, 0.0, -8.0)
    fx.call("emit_stomp", sole, Vector2(0.40, 0.50))
    for name in ["stomp_core", "stomp_dust",
            "stomp_ground", "stomp_fines"]:
        var particle: CPUParticles3D = fx.get(name)
        if particle == null or not particle.emitting or (
                particle.local_coords) or (
                not _near_xz(particle.global_position, sole, 0.001)):
            _fail("stomp cloud scattered away from world contact " + name)
            return
        if particle.amount < 36:
            _fail("stomp cloud too sparse " + name)
            return
    if (fx.get("rock_debris") as Array).size() < 15 or (
            fx.get("grit_debris") as Array).size() < 25:
        _fail("ground contact failed to spawn dense layered debris")
        return
    for record in fx.get("rock_debris"):
        if not _near_xz(record["position"], sole, 0.85):
            _fail("stomp rock spawned outside live footprint")
            return
    fx.call("reset")

    var kick_point: Vector3 = Vector3(-6.0, 0.0, 9.0)
    fx.call("emit_kick", kick_point, Vector3.RIGHT)
    for name in ["kick_dust", "kick_forward_dust",
            "kick_trailing_dust"]:
        var cloud: CPUParticles3D = fx.get(name)
        if cloud == null or not cloud.emitting or (
                not _near_xz(cloud.global_position, kick_point, 0.15)):
            _fail("kick dust detached from contact " + name)
            return
        if cloud.emission_shape != CPUParticles3D.EMISSION_SHAPE_BOX:
            _fail("kick plume not spread across toe surface " + name)
            return
    if (fx.get("rock_debris") as Array).size() < 15:
        _fail("kick grit/rocks missing")
        return
    fx.call("reset")

    var origin: Vector3 = Vector3(14.0, 0.0, -11.0)
    for t in range(18):
        var pos: Vector3 = origin + Vector3(0.048 * float(t), 0, 0)
        fx.call("trace_sweep", pos, DT, Vector3(0.048, 0.0, 0.0))
    var puffs: Array = fx.get("sweep_dust_emitters")
    var pulse_count: int = int(fx.get("sweep_burst_count"))
    var last: Vector3 = fx.get("last_sweep_fx_origin")
    if puffs.size() < 8 or pulse_count < 5 or (
            not _near_xz(last, origin + Vector3(0.816, 0, 0), 0.25)):
        _fail("sweep did not fill the grounded toe path " +
            str([puffs.size(), pulse_count, last]))
        return
    var emitted: int = 0
    for p in puffs:
        if p == null or p.local_coords or (
                p.amount < 30) or (
                p.emission_shape != CPUParticles3D.EMISSION_SHAPE_BOX):
            _fail("sweep puff has sparse or unanchored particles")
            return
        if p.emitting:
            emitted += 1
    if emitted < 5:
        _fail("short sweep emitted too few visible bursts " + str(emitted))
        return
    for record in fx.get("rock_debris"):
        var pos: Vector3 = record["position"]
        if absf(pos.z - origin.z) > 0.85 or (
                pos.x < origin.x - 0.8) or (
                pos.x > origin.x + 1.6):
            _fail("sweep gravel detached from ground stroke " + str(pos))
            return
    fx.call("end_sweep")
    if bool(fx.get("sweep_active")) or (
            int(fx.get("sweep_burst_count")) != pulse_count):
        _fail("sweep end left an active or extra eruption")
        return
    # Stop means NO fresh particles; already emitted puffs remain
    # in world space to fade independently (unlike old moving emitter).
    fx.call("reset")
    if not (fx.get("rock_debris") as Array).is_empty() or (
            int(fx.get("sweep_burst_count")) != 0):
        _fail("reset left orphaned dirt particles")
        return

    # Actual auto-animated toe contacts in real battle, with no
    # guesswork based on the projectile or player position.
    var player: CharacterBody3D = battle.get("player")
    var attacks: RefCounted = battle.get("bittaran_attacks")
    if player == null or attacks == null:
        _fail("live attacks unavailable")
        return
    player.global_position = boss.global_position + Vector3(0, 0, 18)
    if not bool(attacks.call("force_start", "leg_fl", "sweep")):
        _fail("no actual sweep clip")
        return
    var live_pulses: int = 0
    for tick in range(270):
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        battle.call("_finalize_target_pose", DT)
        live_pulses = int(fx.get("sweep_burst_count"))
        if live_pulses > 0:
            var foot: AABB = battle.call(
                "_bittaran_attack_foot_bounds", "leg_fl")
            var emission: Vector3 = fx.get("last_sweep_fx_origin")
            if foot.has_volume() and (
                    not _near_xz(emission, foot.get_center(), 0.85)):
                _fail("live effect diverged from striking toe " +
                    str([emission, foot]))
                return
    if live_pulses < 4:
        _fail("real authored ground sweep had sparse/no effects " +
            str(live_pulses))
        return
    print("GODOT_BITTARAN_GROUND_FX_REBUILD_PASS ",
        "four_sole_anchors=true dense_stomp=true ",
        "grounded_kick=true sweep_world_track=true ",
        "live_sweep_puffs=", live_pulses)
    quit(0)

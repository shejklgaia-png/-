extends SceneTree
## v455: detect actual regressions seen on Android:
## swept powder blinking from early emitter reuse, wrong transient
## source-foot coordinates, and contact FX silently never spawning.
const FX = preload("res://scripts/bittaran_dirt_fx.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_FX_CONTINUITY_FAIL " + message)
    quit(1)


func _plane_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


func _verify_pool_lifetime() -> bool:
    var fx: Node3D = FX.new()
    root.add_child(fx)
    var pool: Array = fx.get("sweep_dust_emitters")
    var previous: Array = (fx.get("sweep_emitter_last_burst") as Array).duplicate()
    if pool.size() < 26 or previous.size() != pool.size():
        _fail("premature-restart pool too small " + str(pool.size()))
        return false
    var used: Dictionary = {}
    var reuses: int = 0
    for tick in range(100):
        # Continuous 1.67s stress: long enough to reuse emitters
        # properly AFTER they finish fading, not while still alive.
        var position: Vector3 = Vector3(
            float(tick) * 0.055, 0.0, -3.0)
        fx.call("trace_sweep", position, DT,
            Vector3(0.055, 0.0, 0.0))
        var now: Array = fx.get("sweep_emitter_last_burst")
        for i in range(now.size()):
            var timestamp: float = now[i]
            var old: float = previous[i]
            if timestamp == old:
                continue
            used[i] = true
            if is_finite(old):
                reuses += 1
                if timestamp - old < (
                        (pool[i] as CPUParticles3D).lifetime
                        + FX.SWEEP_REUSE_SAFETY_SECONDS - 0.001):
                    _fail("live dust emitter abruptly restarted " +
                        str([i, old, timestamp]))
                    return false
            previous[i] = timestamp
    if int(fx.get("sweep_dropped_bursts")) != 0 or (
            used.size() < 26) or reuses < 4 or (
            int(fx.get("sweep_burst_count")) < 31):
        _fail("dense sustained trail contained gaps/restart " +
            str([used.size(), reuses,
                fx.get("sweep_dropped_bursts"),
                fx.get("sweep_burst_count")]))
        return false
    fx.call("end_sweep")
    fx.call("reset")
    var first: Vector3 = Vector3(1.0, 0.0, 2.0)
    fx.call("trace_sweep", first, DT, Vector3.ZERO)
    var before: int = int(fx.get("sweep_burst_count"))
    fx.call("trace_sweep", first + Vector3(3, 0, 0),
        DT, Vector3(3, 0, 0))
    if int(fx.get("sweep_discontinuities")) < 1 or (
            int(fx.get("sweep_burst_count")) != before):
        _fail("one-frame toe teleport created detached dust")
        return false
    var puffs_before: int = int(fx.get("sweep_burst_count"))
    for k in range(8):
        fx.call("trace_sweep",
            first + Vector3(3.0 + float(k) * 0.05, 0, 0),
            DT, Vector3(0.05, 0, 0))
    if int(fx.get("sweep_burst_count")) <= puffs_before:
        _fail("FX never resumed after landing stabilized")
        return false
    print("FX_POOL_TIMELINE_PASS slots=", pool.size(),
        " used=", used.size(), " lifetime_safe_reuses=", reuses,
        " discontinuities_suppressed=",
        fx.get("sweep_discontinuities"))
    fx.queue_free()
    return true


func _verify_authored_attack(leg_id: String, kind: String) -> bool:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    battle.set("player_hp", 99999.0)
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var director: RefCounted = battle.get("bittaran_attacks")
    if fx == null or director == null or player == null or boss == null:
        _fail("live battle missing FX or attack director")
        return false
    player.global_position = boss.global_position + Vector3(0, 0, 18)
    if not bool(director.call("force_start", leg_id, kind)):
        _fail("failed to start real " + str([leg_id, kind]))
        return false
    var observed: bool = false
    var latest_count: int = 0
    var max_surface_step: float = 0.0
    var previous_contact: Vector3 = Vector3.INF
    for tick in range(320):
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        battle.call("_finalize_target_pose", DT)
        var phase: String = str(frame.get("phase", ""))
        if phase != "strike":
            continue
        var foot: AABB = battle.call(
            "_bittaran_attack_foot_bounds", leg_id)
        var anchor: Vector3 = battle.call(
            "_bittaran_ground_fx_contact", leg_id)
        if foot.has_volume() and (
                anchor.x < foot.position.x - 0.003 or
                anchor.x > foot.end.x + 0.003 or
                anchor.z < foot.position.z - 0.003 or
                anchor.z > foot.end.z + 0.003):
            _fail("continuous anchor escaped toe mesh " +
                str([leg_id, kind, anchor, foot]))
            return false
        if previous_contact != Vector3.INF:
            max_surface_step = maxf(max_surface_step,
                _plane_distance(anchor, previous_contact))
        previous_contact = anchor
        if kind == "sweep":
            var total: int = fx.get("sweep_burst_count")
            if total > latest_count:
                observed = true
                latest_count = total
                var emitted: Vector3 = fx.get(
                    "last_sweep_fx_origin")
                if foot.has_volume() and (
                        emitted.x < foot.position.x - 0.23 or
                        emitted.x > foot.end.x + 0.23 or
                        emitted.z < foot.position.z - 0.23 or
                        emitted.z > foot.end.z + 0.23):
                    _fail("sweep puff teleported off foot " +
                        str([leg_id, emitted, foot]))
                    return false
        elif kind == "kick":
            observed = observed or bool(
                fx.get("kicked_this_attack"))
        else:
            observed = observed or bool(
                fx.get("stomped_this_attack"))
    if not observed:
        _fail("source attack played with NO ground FX " +
            str([leg_id, kind, latest_count, max_surface_step]))
        return false
    if kind == "sweep" and (
            int(fx.get("sweep_dropped_bursts")) != 0 or
            latest_count < 4):
        _fail("source sweep had missing intermittent clouds " +
            str([leg_id, latest_count,
                fx.get("sweep_dropped_bursts")]))
        return false
    print("FX_LIVE_ATTACK_PASS ", leg_id, "/", kind,
        " observed=", observed, " puffs=", latest_count,
        " max_toe_step=", max_surface_step)
    battle.queue_free()
    return true


func _run() -> void:
    if not _verify_pool_lifetime():
        return
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        if not _verify_authored_attack(id, "stomp"):
            return
        if not _verify_authored_attack(id, "sweep"):
            return
    for id in ["leg_fl", "leg_fr"]:
        if not _verify_authored_attack(id, "kick"):
            return
    print("GODOT_BITTARAN_FX_CONTINUITY_PASS ",
        "nonrestarting_pool=true surface_anchor_continuous=true ",
        "4_stomps=visible 4_sweeps=visible 2_kicks=visible")
    quit(0)

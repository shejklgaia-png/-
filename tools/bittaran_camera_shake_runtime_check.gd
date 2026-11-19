extends SceneTree
## v486: verify typed camera impacts, repeat sweep tremor, planar footfall fade
## and a vertical-dominant oscillation against the real Bittaran scene.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_CAMERA_SHAKE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("missing Bittaran battle scene")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    var camera: Camera3D = battle.get("camera")
    var player: CharacterBody3D = battle.get("player")
    if camera == null or player == null:
        _fail("missing camera or player")
        return
    battle.set("target_hp", 500.0)
    battle.set("player_hp", 100.0)

    # Walking footsteps fade smoothly in horizontal PLAYER-to-FOOT space:
    # up/down separation has no bearing, and the effect is zero at 10m.
    var origin: Vector3 = player.global_position
    var near: float = battle.call("_footfall_shake_factor",
        origin + Vector3(0, 2, 0))
    var middle: float = battle.call("_footfall_shake_factor",
        origin + Vector3(3, 20, 4))
    var boundary: float = battle.call("_footfall_shake_factor",
        origin + Vector3(6, 0, 8))
    var beyond: float = battle.call("_footfall_shake_factor",
        origin + Vector3(0, 0, 12))
    if absf(near - 1.0) > 0.0001 or absf(middle - 0.5) > 0.0001 or (
            boundary != 0.0 or beyond != 0.0):
        _fail("footfall 0/5/10/12m planar smoothstep is incorrect")
        return
    if not (battle.call("_footfall_shake_factor",
            origin + Vector3(0, 0, 2)) > middle
            and battle.call("_footfall_shake_factor",
            origin + Vector3(0, 0, 8)) < middle):
        _fail("footfall shake must monotonically fade with distance")
        return

    # Stomp = large but quickly damped; kick = bigger, shorter impulse;
    # sweep = medium pulse ONLY during the actual authored hit window.
    battle.set("impact_shake_strength", 0.0)
    battle.call("_add_bittaran_attack_shake", "stomp", origin)
    var stomp: float = battle.get("impact_shake_strength")
    var stomp_decay: float = battle.get("impact_shake_decay_rate")
    if stomp < 0.25 or stomp_decay < 12.0:
        _fail("stomp must be strong and quickly settle")
        return
    battle.call("_tick_impact_shake", 0.25)
    if float(battle.get("impact_shake_strength")) >= stomp * 0.06:
        _fail("stomp shake tail was not short")
        return

    battle.set("impact_shake_strength", 0.0)
    battle.call("_add_bittaran_attack_shake", "kick", origin)
    var kick: float = battle.get("impact_shake_strength")
    if kick < 0.50 or float(battle.get(
            "impact_shake_decay_rate")) <= stomp_decay:
        _fail("kick must be an instantaneous strong, faster-decaying jolt")
        return
    # Source hitboxes are valid ONLY in these front/rear source-clock
    # ranges. Recovery, windup and the rest of STRIKE cannot shake.
    # The damage one-hit latch must not prematurely cut the impact window.
    var shake_cases: Array = [
        ["leg_fl", 0.67, 1.38],
        ["leg_fr", 0.67, 1.38],
        ["leg_rl", 0.17, 0.63],
        ["leg_rr", 0.17, 0.63],
    ]
    for spec in shake_cases:
        var leg_id: String = str(spec[0])
        var begin: float = float(spec[1])
        var end: float = float(spec[2])
        var samples: Array[float] = [
            begin - 0.01, begin, (begin + end) * 0.5,
            end, end + 0.01
        ]
        for t in samples:
            var authored_active: bool = ATTACKS.source_hit_window(
                "sweep", leg_id, t)
            var expected: bool = t >= begin and t <= end
            if authored_active != expected:
                _fail("wrong source hit timing " + str([leg_id, t]))
                return
            battle.set("impact_shake_strength", 0.0)
            battle.set("sweep_shake_strength", 0.0)
            battle.set("sweep_shake_interval_remaining", 0.0)
            battle.set("bittaran_attack_frame", {
                "kind": "sweep", "phase": "strike", "id": leg_id,
                "authored_time": t, "original_attack_only": true,
                "hit_window": authored_active
            })
            battle.call("_tick_bittaran_sweep_shake", 0.016)
            var strength: float = battle.get("sweep_shake_strength")
            if expected and strength < 0.20:
                _fail("missing shake inside hit window " + str([leg_id, t]))
                return
            if not expected and strength != 0.0:
                _fail("shake outside hit window " + str([leg_id, t]))
                return
            battle.call("_tick_impact_shake", 0.016)
            if not expected and (camera.h_offset != 0.0
                    or camera.v_offset != 0.0):
                _fail("off-window camera must be still " +
                    str([leg_id, t]))
                return
            # A completed one-hit damage latch must not stop the
            # rhythmic shake while the attack still has a hitbox.
            if expected:
                var director: RefCounted = battle.get("bittaran_attacks")
                director.set("hit_consumed", true)
                battle.set("sweep_shake_strength", 0.0)
                battle.set("sweep_shake_interval_remaining", 0.0)
                battle.call("_tick_bittaran_sweep_shake", 0.016)
                if float(battle.get("sweep_shake_strength")) < 0.20:
                    _fail("early shake cutoff after one damage hit")
                    return
                director.set("hit_consumed", false)

    battle.set("bittaran_attack_frame", {
        "kind": "sweep", "phase": "strike", "id": "leg_fl",
        "hit_window": true
    })
    battle.set("impact_shake_strength", 0.0)
    battle.set("sweep_shake_strength", 0.0)
    battle.set("sweep_shake_interval_remaining", 0.0)
    battle.call("_tick_bittaran_sweep_shake", 0.016)
    var first: float = battle.get("sweep_shake_strength")
    if first < 0.20 or first >= kick:
        _fail("active sweep must be a moderate shake")
        return
    battle.call("_tick_impact_shake", 0.10)
    var decayed: float = battle.get("sweep_shake_strength")
    battle.call("_tick_bittaran_sweep_shake", 0.15)
    if float(battle.get("sweep_shake_strength")) <= decayed:
        _fail("active sweep must repeatedly refresh")
        return
    battle.set("bittaran_attack_frame", {
        "kind": "sweep", "phase": "recovery", "id": "leg_fl",
        "hit_window": false
    })
    battle.call("_tick_bittaran_sweep_shake", 0.016)
    battle.call("_tick_impact_shake", 0.016)
    if float(battle.get("sweep_shake_interval_remaining")) != 0.0 or (
            float(battle.get("sweep_shake_strength")) != 0.0) or (
            camera.h_offset != 0.0 or camera.v_offset != 0.0):
        _fail("sweep must stop instantly outside hit window")
        return
    # A stray FX pulse cannot revive the now-disabled sweep.
    battle.call("_add_bittaran_attack_shake", "sweep", origin)
    if float(battle.get("sweep_shake_strength")) != 0.0:
        _fail("sweep FX cannot bypass the hitbox window")
        return

    # Sample the same deterministic noise without damping to compare axes.
    var max_horizontal: float = 0.0
    var max_vertical: float = 0.0
    for i in range(100):
        battle.set("impact_shake_strength", 0.30)
        battle.set("impact_shake_time", float(i) * 0.01)
        battle.call("_tick_impact_shake", 0.0)
        max_horizontal = maxf(max_horizontal, absf(camera.h_offset))
        max_vertical = maxf(max_vertical, absf(camera.v_offset))
    if max_vertical <= max_horizontal * 1.5:
        _fail("camera shake should be predominantly vertical")
        return
    battle.set("impact_shake_strength", 0.0)
    battle.call("_tick_impact_shake", 0.02)
    if camera.h_offset != 0.0 or camera.v_offset != 0.0:
        _fail("camera offsets must return exactly to zero")
        return
    print("BITTARAN_CAMERA_SHAKE_PASS: stomp/kick/sweep/footstep, authored 4-leg hit window, hard cutoff, falloff and vertical axis")
    quit(0)

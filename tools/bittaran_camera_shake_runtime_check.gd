extends SceneTree
## v486: verify typed camera impacts, repeat sweep tremor, planar footfall fade
## and a vertical-dominant oscillation against the real Bittaran scene.
const BATTLE = preload("res://scripts/bittaran_battle.gd")

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
    # sweep = medium pulse, repeatedly refreshed during the strike only.
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
    battle.set("impact_shake_strength", 0.0)
    battle.call("_add_bittaran_attack_shake", "sweep", origin)
    var sweep: float = battle.get("impact_shake_strength")
    if not (sweep >= 0.20 and sweep < kick):
        _fail("sweep must be a moderate shake")
        return

    battle.set("impact_shake_strength", 0.0)
    battle.set("sweep_shake_interval_remaining", 0.0)
    battle.set("bittaran_attack_frame", {
        "kind": "sweep", "phase": "strike", "id": "leg_fl"
    })
    battle.call("_tick_bittaran_sweep_shake", 0.016)
    var first: float = battle.get("impact_shake_strength")
    if first < 0.20:
        _fail("sweep should pulse as soon as its strike begins")
        return
    battle.call("_tick_impact_shake", 0.10)
    var decayed: float = battle.get("impact_shake_strength")
    battle.call("_tick_bittaran_sweep_shake", 0.15)
    if float(battle.get("impact_shake_strength")) <= decayed:
        _fail("sweep strike must continually refresh moderate impacts")
        return
    battle.set("bittaran_attack_frame", {
        "kind": "sweep", "phase": "recovery", "id": "leg_fl"
    })
    battle.call("_tick_bittaran_sweep_shake", 0.016)
    if float(battle.get("sweep_shake_interval_remaining")) != 0.0:
        _fail("sweep must stop shaking outside strike")
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
    print("BITTARAN_CAMERA_SHAKE_PASS: stomp/kick/sweep/footstep, falloff, decay and vertical axis")
    quit(0)

extends SceneTree
## Actual boss scene: four embedded creator cues and one-shot dispatch.
const IK = preload("res://scripts/bittaran_foot_ik.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    push_error("BITTARAN_SOUND_CUES_FAIL " + msg)
    quit(1)

func _count(battle: Node, name: String) -> int:
    return int((battle.get("bittaran_sfx_event_counts") as Dictionary).get(name, 0))

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var players: Dictionary = battle.get("bittaran_sfx_players")
    for key in ["footstep", "arm", "collapse", "punch"]:
        if not players.has(key):
            _fail("missing SFX channel " + key)
            return
        var player: AudioStreamPlayer = players[key]
        if player.stream == null or not player.stream is AudioStreamOggVorbis:
            _fail("creator audio missing " + key)
            return
        if player.stream.get_length() < 0.8:
            _fail("creator audio truncated " + key)
            return
    # An attack includes a stance phase; only actual animation entry emits.
    battle.set("bittaran_attack_frame", {"stance_prepare": true})
    battle.call("_tick_bittaran_attack_sfx")
    if _count(battle, "arm") != 0:
        _fail("arm sound fired during stance prep")
        return
    battle.set("bittaran_attack_frame",
        {"id": "leg_fl", "kind": "stomp", "phase": "entry"})
    battle.call("_tick_bittaran_attack_sfx")
    battle.call("_tick_bittaran_attack_sfx")
    if _count(battle, "arm") != 1:
        _fail("arm sound did not fire exactly once at attack start")
        return
    battle.set("bittaran_attack_frame", {})
    battle.call("_tick_bittaran_attack_sfx")
    battle.set("bittaran_attack_frame",
        {"id": "leg_rr", "kind": "sweep", "phase": "entry"})
    battle.call("_tick_bittaran_attack_sfx")
    if _count(battle, "arm") != 2:
        _fail("next attack was not independently sounded")
        return
    battle.set("bittaran_attack_frame", {})
    battle.call("_tick_bittaran_attack_sfx")
    # Only an actual locomotion touchdown, never an ongoing step, gets a footstep.
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var feet: Array = ik.get("legs")
    battle.set("bittaran_motion", "Approach")
    battle.set("footfall_prev_stepping", [true, false, false, false])
    feet[0]["stepping"] = false
    battle.call("_tick_bittaran_footfalls")
    if _count(battle, "footstep") != 1:
        _fail("source footstep did not sound on completed gait contact")
        return
    battle.call("_tick_bittaran_footfalls")
    if _count(battle, "footstep") != 1:
        _fail("walking footstep looped without new contact")
        return
    # Real break handler is also the shared manual-debug leg-break path.
    battle.call("_handle_bittaran_leg_break", "leg_fl",
        {"broken": true, "kind": "leg", "broken_legs": 1}, false, "")
    if _count(battle, "punch") != 1:
        _fail("recoil punch missing at first breakdown start")
        return
    # Additional break during same fall does NOT restart recoil or collapse.
    battle.call("_handle_bittaran_leg_break", "leg_fr",
        {"broken": true, "kind": "leg", "broken_legs": 2}, false, "")
    if _count(battle, "punch") != 1:
        _fail("duplicate punch during the same recoil")
        return
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    ik.set("authored_down_source_seconds", 1.749)
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 0:
        _fail("front impact sounded before 1.75")
        return
    ik.set("authored_down_source_seconds", 1.75)
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 1 or (
            int(fx.get("body_fall_burst_count")) != 1):
        _fail("front collapse SE and plume did not synchronize")
        return
    if float(battle.get("fall_vertical_shake_strength")) < 1.0:
        _fail("front impact missing large vertical camera impulse")
        return
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 1:
        _fail("front collapse replayed")
        return
    # Rear 0.75 FX uses the same one-shot routing, not the 1.75 DOWN timer.
    battle.call("_reset_target_after_respawn")
    ik = battle.get("bittaran_foot_ik")
    fx = battle.get("bittaran_dirt_fx")
    var head: Vector3 = battle.get("target_parts").call(
        "get_part_aim_world", "head")
    ik.call("start_leg_break_slide", "leg_rl", head.y, false)
    ik.set("authored_down_source_seconds", 0.749)
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 0:
        _fail("rear collapse triggered before 0.75")
        return
    ik.set("authored_down_source_seconds", 0.75)
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 1 or (
            int(fx.get("body_fall_burst_count")) != 1):
        _fail("rear collapse did not synchronize SE and plume at 0.75")
        return
    if float(ik.get("break_elapsed")) >= 0.0:
        _fail("rear down hold incorrectly started at dust timestamp")
        return
    ik.set("authored_down_source_seconds", 1.75)
    battle.call("_tick_bittaran_body_fall_fx")
    if _count(battle, "collapse") != 1:
        _fail("rear collapse replayed at 1.75")
        return
    print("GODOT_BITTARAN_SOUND_CUES_PASS four_sources=true timed_events=true independent_down_clock=true")
    quit(0)

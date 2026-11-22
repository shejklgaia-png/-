extends SceneTree
## Real four-leg sweep hit window controls a 1x, looped sound and 3s fade.
const A = preload("res://scripts/bittaran_attacks.gd")
const B = preload("res://scripts/bittaran_battle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_SWEEP_AUDIO_V545_FAIL " + message)
    quit(1)

func _frame(kind: String, id: String, source_time: float) -> Dictionary:
    return {
        "kind": kind, "id": id, "phase": "strike",
        "stance_prepare": false,
        "hit_window": A.source_hit_window(kind, id, source_time),
        "authored_time": source_time
    }

func _near(a: float, b: float, eps: float = 0.03) -> bool:
    return absf(a - b) <= eps

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("player_hp", 10000.0)
    battle.set("target_hp", 2500.0)
    var sound: AudioStreamPlayer = battle.get("bittaran_sweep_loop_audio")
    if sound == null or sound.stream == null:
        _fail("actual sweep loop player/embedded source missing")
        return
    if not sound.stream is AudioStreamMP3 or (
            not bool(sound.stream.loop)):
        _fail("provided audio is not a loopable MP3")
        return
    if sound.stream.get_length() < 3.8 or sound.stream.get_length() > 4.3:
        _fail("source is not a repeatable four-second unit")
        return
    if sound.pitch_scale != 1.0 or (
            not _near(sound.volume_db, 2.0, 0.001)):
        _fail("sweep must play at 1x with loud +2dB level")
        return
    # No attack and stance windup must be silent.
    battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
    if sound.playing:
        _fail("started outside source hit window")
        return
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        battle.call("_reset_bittaran_sweep_loop_audio")
        var start: float = 0.17 if id.begins_with("leg_r") else 0.67
        var end: float = 0.63 if id.begins_with("leg_r") else 1.38
        battle.set("bittaran_attack_frame", _frame("sweep", id, start - 0.02))
        battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
        if sound.playing:
            _fail("played before the real attack window: " + id)
            return
        battle.set("bittaran_attack_frame", _frame("sweep", id, start + 0.02))
        battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
        if not sound.playing or not _near(sound.volume_db, 2.0, 0.001):
            _fail("missing loud loop inside actual hit window: " + id)
            return
        # A consumed hit must NOT stop the audio while mesh remains live.
        var director: RefCounted = battle.get("bittaran_attacks")
        director.set("hit_consumed", true)
        battle.call("_tick_bittaran_sweep_loop_audio", 0.60)
        if not sound.playing or not _near(sound.volume_db, 2.0, 0.001):
            _fail("sound fades during valid hit window: " + id)
            return
        battle.set("bittaran_attack_frame", _frame("sweep", id, end + 0.02))
        battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
        var t: float = float(battle.get("bittaran_sweep_loop_fade_remaining"))
        if not _near(t, 2.984, 0.002) or not sound.playing:
            _fail("three-second fade did not start at hit end: " + id)
            return
        battle.call("_tick_bittaran_sweep_loop_audio", 1.484)
        if not _near(sound.volume_db, 2.0 + linear_to_db(0.5), 0.06):
            _fail("fade not halfway after 1.5 seconds: " + id)
            return
        battle.call("_tick_bittaran_sweep_loop_audio", 1.5)
        if sound.playing:
            _fail("sound did not stop at exactly 3 seconds: " + id)
            return
    # A new sweep during the previous tail cancels its fade and returns
    # instantly to full level without stacking another sound player.
    battle.call("_reset_bittaran_sweep_loop_audio")
    battle.set("bittaran_attack_frame", _frame("sweep", "leg_fl", 0.90))
    battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
    battle.set("bittaran_attack_frame", _frame("sweep", "leg_fl", 1.40))
    battle.call("_tick_bittaran_sweep_loop_audio", 1.5)
    if not sound.playing:
        _fail("fade ended prematurely")
        return
    battle.set("bittaran_attack_frame", _frame("sweep", "leg_rr", 0.35))
    battle.call("_tick_bittaran_sweep_loop_audio", 0.016)
    if not _near(sound.volume_db, 2.0, 0.001) or (
            float(battle.get("bittaran_sweep_loop_fade_remaining")) != 0.0):
        _fail("next sweep did not restore 1x full volume")
        return
    battle.call("_reset_target_after_respawn")
    if sound.playing:
        _fail("loop leaked into next battle")
        return
    print("GODOT_BITTARAN_SWEEP_AUDIO_V545_PASS all_four_hit_keys=true 1x=true loud=true fade_3_seconds=true")
    quit(0)

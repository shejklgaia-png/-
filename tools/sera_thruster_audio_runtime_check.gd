extends SceneTree
## v457: 01 continuous exhaust/13-1 acceleration coexist through
## boost, full step and every melee pursuit start. Playback uses
## independent loop+one-shot players and always fades on stop.
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_THRUSTER_AUDIO_RUNTIME_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    var sound: Node = game.get("thruster_audio")
    if sound == null:
        _fail("SeraThrusterAudio missing from real scene")
        return
    var steady: AudioStreamPlayer = sound.get("sustained")
    var burst: AudioStreamPlayer = sound.get("acceleration")
    if not bool(sound.get("sound_ready")) or (
            int(sound.get("load_attempts")) != 1) or (
            steady == null or burst == null) or (
            not steady.stream is AudioStreamOggVorbis) or (
            not burst.stream is AudioStreamOggVorbis):
        _fail("supplied 01/13-1 Ogg streams not loaded")
        return
    var loop: AudioStreamOggVorbis = steady.stream
    if not loop.loop or absf(loop.get_length() - 4.9) > 0.08:
        _fail("01 stable waveform loop length/loop flag invalid " +
            str(loop.get_length()))
        return
    if burst.stream.get_length() < 0.7 or (
            burst.stream.get_length() > 1.06):
        _fail("13-1 should be one trimmed launch sound " +
            str(burst.stream.get_length()))
        return
    if sound.get("sustained_gain") != 0.0:
        _fail("initial sustained jet is audible")
        return
    # v461: verify both sound layers are -6.0206 dB below v460.
    if steady.volume_db > -75.0 or (
            absf(burst.volume_db - (-9.0206)) > 0.001):
        _fail("13-1 acceleration must be half of v460 amplitude")
        return
    # Reproduce Android GitSync BEFORE Godot generates an import cache:
    # a raw Ogg living in user:// has no .import metadata at all.
    var src_path: String = "res://assets/sera_thruster_01_loop.ogg"
    var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(src_path)
    if raw_bytes.is_empty():
        _fail("missing physical Ogg asset; APK cannot reproduce audio")
        return
    var no_import_path: String = (
        "user://SERA_v458_unimported_thruster_source.ogg")
    var writable: FileAccess = FileAccess.open(
        no_import_path, FileAccess.WRITE)
    if writable == null:
        _fail("cannot construct Android raw-Ogg source fixture")
        return
    writable.store_buffer(raw_bytes)
    writable.close()
    var directly_loaded: AudioStreamOggVorbis = sound.call(
        "_load_ogg", no_import_path) as AudioStreamOggVorbis
    if directly_loaded == null or (
            absf(directly_loaded.get_length() - 4.9) > 0.08):
        _fail("Android unimported raw Ogg did not decode")
        return
    DirAccess.remove_absolute(
        ProjectSettings.globalize_path(no_import_path))
    # A partial GitSync transfer can bring 01 before 13-1. It must
    # still play the continuous jet while re-trying the other file.
    var saved_burst_stream: AudioStream = burst.stream
    burst.stream = null
    sound.set("sound_ready", false)
    sound.call("update_audio", DT, true, false)
    if not steady.playing or int(sound.get(
            "sustained_starts")) != 1:
        _fail("01 is muted when only 13-1 has not synced yet")
        return
    steady.stop()
    burst.stream = saved_burst_stream
    sound.set("sound_ready", true)
    sound.set("sustained_gain", 0.0)
    sound.set("sustained_starts", 0)
    # BOOST: 01 only; repeated frames must never retrigger 13-1.
    for tick in range(18):
        sound.call("update_audio", DT, true, false)
    if not steady.playing or (
            absf(steady.volume_db - (-18.5206)) > 0.01) or (
            int(sound.get("sustained_starts")) != 1) or (
            int(sound.get("acceleration_triggers")) != 0):
        _fail("boost did not start 01-only loop")
        return
    # STEP: 13-1 one-shot at acceleration start while 01 keeps its
    # original playhead through the full 0.267s horizontal move.
    sound.call("update_audio", DT, true, true)
    var starts: int = int(sound.get("sustained_starts"))
    if not burst.playing or int(sound.get(
            "acceleration_triggers")) != 1:
        _fail("no overlapping 13-1 on step launch")
        return
    for tick in range(16):
        sound.call("update_audio", DT, true, false)
        if not steady.playing or int(sound.get(
                "sustained_starts")) != starts:
            _fail("01 restarted/ended during STEP travel")
            return
    # New melee pursue after a step: new 13-1, 01 never interrupts.
    sound.call("update_audio", DT, true, true)
    if int(sound.get("acceleration_triggers")) != 2 or (
            int(sound.get("sustained_starts")) != starts):
        _fail("melee chase did not share 01 and relaunch 13-1")
        return
    # End of nozzle FX: 220ms linear amplitude fade, no hard stop.
    var previous: float = sound.get("sustained_gain")
    sound.call("update_audio", DT, false, false)
    var faded: float = sound.get("sustained_gain")
    if not steady.playing or not (faded < previous and faded > 0.0):
        _fail("01 cut sharply instead of fading")
        return
    for tick in range(18):
        sound.call("update_audio", DT, false, false)
    if steady.playing or float(sound.get(
            "sustained_gain")) > 0.00001 or int(sound.get(
            "fade_completions")) != 1:
        _fail("01 failed to finish fade safely")
        return
    # A new boost after silence starts a fresh Ogg loop.
    sound.call("update_audio", DT, true, false)
    if int(sound.get("sustained_starts")) != 2:
        _fail("new BOOST did not restart after silence")
        return
    # Check the actual boss BGM stays at its ORIGINAL volume while
    # the thruster and acceleration are simultaneously running.
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var bgm: AudioStreamPlayer = (
        battle.get("bittaran_bgm") as AudioStreamPlayer)
    var jet: Node = battle.get("thruster_audio")
    if bgm == null or jet == null or not bool(jet.get("sound_ready")):
        _fail("Bittaran battle cannot load thruster under BGM")
        return
    for tick in range(30):
        jet.call("update_audio", DT, true, tick == 0)
        battle.call("_process", DT)
    if absf(bgm.volume_db - (-5.0)) > 0.001:
        _fail("BGM must stay at original -5 dB during thruster use " +
            str(bgm.volume_db))
        return
    for tick in range(90):
        jet.call("update_audio", DT, false, false)
        battle.call("_process", DT)
    if absf(bgm.volume_db - (-5.0)) > 0.001:
        _fail("BGM volume shifted on thruster end " +
            str(bgm.volume_db))
        return
    print("GODOT_SERA_THRUSTER_AUDIO_HALF_GAIN_PASS ",
        "01=-18.5206dB 13-1=-9.0206dB BittaranBGM=-5.0dB ",
        "no_music_duck=true android_raw_ogg_fallback=true")
    print("GODOT_SERA_THRUSTER_AUDIO_RUNTIME_PASS ",
        "01_gapless_loop=4.9s continuous_boost_step_homing=true ",
        "13_1_step_and_tracking_onsets=true overlap=true ",
        "fade_out=0.22s natural=true")
    quit(0)

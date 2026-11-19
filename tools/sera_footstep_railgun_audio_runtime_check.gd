extends SceneTree
## v480: 3 creator-supplied audio assignments on LIVE SERA/Bittaran scenes.
## Validate asset presence/import, visual sole contacts, charge phase,
## one-time laser onset, seamless sustain loop and smooth shot-end fade.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const FOOTSTEP_SOURCE_PATH: String = "res://assets/sera_player_footstep_v480.ogg"
const DT: float = 1.0 / 60.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("SERA_V480_USER_AUDIO_FAIL: " + reason)
    quit(1)


func _near(a: float, b: float, tolerance: float = 0.05) -> bool:
    return absf(a - b) <= tolerance


func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: CharacterBody3D = scene.get("player")
    var footstep: AudioStreamPlayer = scene.get("footstep_audio")
    var gun: Node3D = scene.get("bittaran_railgun")
    if player == null or footstep == null or gun == null:
        _fail("live boss battle missing audio owners")
        return
    var foot_path: String = FOOTSTEP_SOURCE_PATH
    if not FileAccess.file_exists(foot_path) or (
            not footstep.stream is AudioStreamOggVorbis) or (
            not _near(footstep.stream.get_length(), 0.53, 0.08)):
        _fail("robot impact was not loaded as real model-sole footstep")
        return
    player.position.y = 0.0
    footstep.stop()
    scene.call("_on_foot_contact", "L")
    if not footstep.playing or (
            not _near(footstep.pitch_scale, 0.96, 0.001)):
        _fail("left mechanical sole contact failed to play the user sound")
        return
    scene.call("_on_foot_contact", "R")
    if not footstep.playing or (
            not _near(footstep.pitch_scale, 1.03, 0.001)):
        _fail("right mechanical sole contact failed to play the user sound")
        return
    footstep.stop()
    player.position.y = 0.4
    scene.call("_on_foot_contact", "L")
    if footstep.playing:
        _fail("airborne footstep falsely played")
        return
    player.position.y = 0.0

    var charge: AudioStreamPlayer = gun.get("charge_audio")
    var attack: AudioStreamPlayer = gun.get("laser_attack_audio")
    var sustain: AudioStreamPlayer = gun.get("laser_loop_audio")
    if charge == null or attack == null or sustain == null:
        _fail("missing separate charge/laser-onset/laser-sustain audio owners")
        return
    if not FileAccess.file_exists(GUN.CHARGE_AUDIO_PATH) or (
            not FileAccess.file_exists(GUN.LASER_ATTACK_AUDIO_PATH)) or (
            not FileAccess.file_exists(GUN.LASER_LOOP_AUDIO_PATH)):
        _fail("sound asset missing from res://; Android APK cannot import it")
        return
    if not charge.stream is AudioStreamOggVorbis or (
            not attack.stream is AudioStreamOggVorbis) or (
            not sustain.stream is AudioStreamOggVorbis):
        _fail("all creator-supplied sounds must decode via Godot Ogg")
        return
    if not _near(charge.stream.get_length(), 2.015, 0.10) or (
            not _near(attack.stream.get_length(), 0.386, 0.09)) or (
            not _near(sustain.stream.get_length(), 0.61, 0.08)):
        _fail("charge or laser waveform was changed unexpectedly")
        return
    if not (sustain.stream as AudioStreamOggVorbis).loop or (
            (charge.stream as AudioStreamOggVorbis).loop) or (
            (attack.stream as AudioStreamOggVorbis).loop):
        _fail("only the sustained laser section may be looped")
        return
    var raw: PackedByteArray = FileAccess.get_file_as_bytes(
        GUN.LASER_LOOP_AUDIO_PATH)
    var direct: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(raw)
    if direct == null or not _near(direct.get_length(), 0.61, 0.08):
        _fail("cannot decode raw loop before Android GitSync import finishes")
        return

    gun.call("reset")
    var src: Vector3 = player.global_position
    gun.call("advance", 9.999, src, true)
    if charge.playing or attack.playing or sustain.playing:
        _fail("the 10-second lamp fill must remain silent")
        return
    var charge_count: int = int(gun.get("charge_starts"))
    gun.call("advance", 0.002, src, true)
    if not charge.playing or attack.playing or sustain.playing or (
            int(gun.get("charge_starts")) != charge_count + 1):
        _fail("blue sphere appearance t=10 must play gravity charge ONCE")
        return
    gun.call("advance", 0.999, src, true)
    if int(gun.get("charge_starts")) != charge_count + 1 or (
            not charge.playing):
        _fail("charge shrink restarted/stopped sound before laser fire")
        return
    var attack_count: int = int(gun.get("laser_attack_starts"))
    var sustain_count: int = int(gun.get("laser_loop_starts"))
    gun.call("advance", 1.001, src, true)
    if charge.playing or not attack.playing or not sustain.playing or (
            int(gun.get("laser_attack_starts")) != attack_count + 1) or (
            int(gun.get("laser_loop_starts")) != sustain_count + 1):
        _fail("t=12 must start the laser attack and sustain, ending charge")
        return
    gun.call("advance", 0.5, src, true)
    if not sustain.playing or (
            int(gun.get("laser_loop_starts")) != sustain_count + 1) or (
            float(gun.get("laser_loop_gain")) < 0.99):
        _fail("laser sustained layer restarted or did not reach normal volume")
        return
    gun.call("advance", 1.498, src, true)
    if not sustain.playing or (
            int(gun.get("laser_loop_starts")) != sustain_count + 1):
        _fail("laser sustain failed to loop through the complete beam")
        return
    gun.call("advance", 0.002, src, true)
    if not sustain.playing or (
            float(gun.get("laser_loop_gain")) >= 0.99):
        _fail("laser sustain did not enter smooth fade on beam end")
        return
    gun.call("advance", 0.06, src, true)
    var fade_level: float = float(gun.get("laser_loop_gain"))
    if not (sustain.playing and fade_level > 0.0 and fade_level < 1.0):
        _fail("laser sustain ended abruptly without an intermediate fade")
        return
    gun.call("advance", 0.12, src, true)
    if sustain.playing or float(gun.get("laser_loop_gain")) > 0.00001:
        _fail("laser sustain failed to finish its 0.14s fade")
        return
    # Encounter reset or boss death must silence all three gun layers.
    gun.call("reset")
    if charge.playing or attack.playing or sustain.playing:
        _fail("gun reset leaked SFX")
        return
    print("SERA_V480_USER_AUDIO_PASS foot_contacts=true airborne_silent=true ",
        "creator_ogg_files_present=true raw_android_ogg_decode=true ",
        "charge_starts_at_sphere=true shrink_no_retrigger=true ",
        "laser_onset_once=true sustain_loop_gapless=true ",
        "fade_at_t14=true reset_silences_all=true")
    quit(0)

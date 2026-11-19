extends Node
## User-supplied SERA v480 sounds. All transitions follow the active
## gun phase: no timer duplication or repeated play() on physics ticks.
## Ogg is also decoded directly on Android when GitSync has not yet
## created its Godot import cache.
const CHARGE_PATH: String = "res://assets/bittaran_charge_v480.ogg"
const LASER_ATTACK_PATH: String = "res://assets/bittaran_laser_attack_v480.ogg"
const LASER_LOOP_PATH: String = "res://assets/bittaran_laser_sustain_loop_v480.ogg"
const LASER_RELEASE_SECONDS: float = 0.14
const LASER_LOOP_VOLUME_DB: float = -10.0

var charge: AudioStreamPlayer
var laser_attack: AudioStreamPlayer
var laser_loop: AudioStreamPlayer
var sound_ready: bool = false
var charge_started: int = 0
var laser_started: int = 0
var laser_fade_remaining: float = 0.0
var last_charging: bool = false
var last_firing: bool = false

func _load_ogg(path: String) -> AudioStreamOggVorbis:
    var imported: AudioStreamOggVorbis = null
    if ResourceLoader.exists(path):
        imported = ResourceLoader.load(path) as AudioStreamOggVorbis
    if imported != null:
        return imported
    if not FileAccess.file_exists(path):
        return null
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return null
    return AudioStreamOggVorbis.load_from_buffer(bytes)

func _make_player(node_name: String, sound: AudioStreamOggVorbis,
        gain_db: float) -> AudioStreamPlayer:
    var speaker := AudioStreamPlayer.new()
    speaker.name = node_name
    speaker.bus = "Master"
    speaker.stream = sound
    speaker.volume_db = gain_db
    add_child(speaker)
    return speaker

func setup() -> void:
    var charge_stream := _load_ogg(CHARGE_PATH)
    var attack_stream := _load_ogg(LASER_ATTACK_PATH)
    var loop_stream := _load_ogg(LASER_LOOP_PATH)
    if charge_stream == null or attack_stream == null or loop_stream == null:
        push_error("SERA_BITTARAN_RAILGUN_AUDIO_MISSING: required user SFX "
            + "not included in Android asset import")
        sound_ready = false
        return
    charge_stream.loop = false
    attack_stream.loop = false
    loop_stream.loop = true
    loop_stream.loop_offset = 0.0
    charge = _make_player("GravityChargeSFX", charge_stream, -2.0)
    laser_attack = _make_player("SnBiLaserAttackSFX", attack_stream, -5.0)
    laser_loop = _make_player("SnBiLaserContinuousSFX", loop_stream,
        LASER_LOOP_VOLUME_DB)
    sound_ready = true
    reset()

func reset() -> void:
    if charge != null:
        charge.stop()
    if laser_attack != null:
        laser_attack.stop()
    if laser_loop != null:
        laser_loop.stop()
        laser_loop.volume_db = LASER_LOOP_VOLUME_DB
    charge_started = 0
    laser_started = 0
    last_charging = false
    last_firing = false
    laser_fade_remaining = 0.0

func tick(delta: float, charging: bool, firing: bool) -> void:
    if not sound_ready:
        return
    if charging and not last_charging:
        charge.play()
        charge_started += 1
    elif not charging and last_charging:
        charge.stop()

    if firing and not last_firing:
        # Attack crack + independently looping sustain from the supplied
        # Sn_bi sample. Sustain never restarts while the beam is visible.
        laser_loop.volume_db = LASER_LOOP_VOLUME_DB
        laser_fade_remaining = 0.0
        laser_attack.play()
        laser_loop.play()
        laser_started += 1
    elif firing and not laser_loop.playing:
        # Defensive resumption after an Android mixer interruption.
        laser_loop.play()
    elif not firing and last_firing:
        laser_attack.stop()
        laser_fade_remaining = LASER_RELEASE_SECONDS

    if not firing and laser_fade_remaining > 0.0:
        laser_fade_remaining = maxf(
            0.0, laser_fade_remaining - maxf(delta, 0.0))
        var remain_fraction: float = (
            laser_fade_remaining / LASER_RELEASE_SECONDS)
        if remain_fraction <= 0.0:
            laser_loop.stop()
            laser_loop.volume_db = LASER_LOOP_VOLUME_DB
        else:
            laser_loop.volume_db = LASER_LOOP_VOLUME_DB + (
                20.0 * log(remain_fraction) / log(10.0))
    last_charging = charging
    last_firing = firing

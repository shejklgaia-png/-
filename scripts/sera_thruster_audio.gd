extends Node
## v457 SERA dedicated two-layer booster soundtrack.
## 01 = true gapless sustained exhaust; 13-1 = independent acceleration.
## They overlap deliberately: the sustained layer never restarts during
## consecutive steps, booster input, or an ongoing melee homing phase.
# An Android GitSync download can expose a raw .ogg BEFORE Godot has
# generated its imported cache. Static preload() silently prevents
# playback (or fails scene compilation) on such devices. Decode from
# the raw Ogg bytes when the imported stream is not ready.
const CONTINUOUS_PATH: String = "res://assets/sera_thruster_01_loop.ogg"
const ACCELERATION_PATH: String = "res://assets/sera_thruster_13_1_acceleration.ogg"
const FADE_IN_SECONDS: float = 0.075
const FADE_OUT_SECONDS: float = 0.22
# The original jet is a broadband -15 dBFS RMS signal. At -12.5 dB
# its effective RMS was ~-27.5 dBFS, masked by boss BGM at -5 dB.
# These levels preserve ~4 dB true peak headroom for the Ogg.
const SUSTAINED_VOLUME_DB: float = -3.0
# Source 13-1 has only -10.8 dBFS peak; +6 dB remains unclipped.
const ACCELERATION_VOLUME_DB: float = 6.0
const LOAD_RETRY_SECONDS: float = 2.0
const SILENT_DB: float = -80.0

var sustained: AudioStreamPlayer
var acceleration: AudioStreamPlayer
var sustained_gain: float = 0.0
var acceleration_triggers: int = 0
var sustained_starts: int = 0
var fade_completions: int = 0
var sound_ready: bool = false
var source_mode: Dictionary = {}
var load_attempts: int = 0
var load_retry_elapsed: float = 0.0

## ResourceLoader works in exported APKs with imports. Fresh
## Android GitSync files may exist only as raw Oggs until the next
## editor import; read those Ogg bytes directly, as the Bittaran BGM
## loader already does.
func _load_ogg(path: String) -> AudioStreamOggVorbis:
    var stream: AudioStreamOggVorbis = null
    var loaded_via: String = ""
    if ResourceLoader.exists(path):
        stream = ResourceLoader.load(path) as AudioStreamOggVorbis
        if stream != null:
            loaded_via = "imported"
    if stream == null and FileAccess.file_exists(path):
        var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
        if not data.is_empty():
            stream = AudioStreamOggVorbis.load_from_buffer(data)
            if stream != null:
                loaded_via = "direct-ogg"
    if stream == null:
        # Useful with the Android SERA Loader when the project source
        # has been copied into the app-writable data directory.
        var alternative: String = "user://" + path.get_file()
        if FileAccess.file_exists(alternative):
            stream = AudioStreamOggVorbis.load_from_file(alternative)
            if stream != null:
                loaded_via = "user-ogg"
    source_mode[path] = loaded_via if stream != null else "missing"
    return stream


func _refresh_streams() -> void:
    load_attempts += 1
    if sustained != null and sustained.stream == null:
        sustained.stream = _load_ogg(CONTINUOUS_PATH)
    if acceleration != null and acceleration.stream == null:
        acceleration.stream = _load_ogg(ACCELERATION_PATH)
    sound_ready = (sustained != null and sustained.stream != null
        and acceleration != null and acceleration.stream != null)
    if sound_ready:
        if sustained.stream is AudioStreamOggVorbis:
            var ogg: AudioStreamOggVorbis = sustained.stream
            ogg.loop = true
            ogg.loop_offset = 0.0
        print("SERA_THRUSTER_AUDIO_READY: 01=", source_mode.get(
            CONTINUOUS_PATH, ""), " 13-1=", source_mode.get(
            ACCELERATION_PATH, ""), " lengths=",
            sustained.stream.get_length(), ",",
            acceleration.stream.get_length())
    elif load_attempts == 1:
        push_warning("SERA_THRUSTER_AUDIO_MISSING: "
            + str(source_mode) + ". Retrying raw GitSync Ogg.")


func _ready() -> void:
    sustained = AudioStreamPlayer.new()
    sustained.name = "Thruster01SustainedLoop"
    sustained.volume_db = SILENT_DB
    sustained.max_polyphony = 1
    add_child(sustained)
    # The loop was crossfaded offline; imported and raw Oggs share it.
    # Set loop after decoding in _refresh_streams().

    acceleration = AudioStreamPlayer.new()
    acceleration.name = "Thruster13_1Acceleration"
    acceleration.volume_db = ACCELERATION_VOLUME_DB
    acceleration.max_polyphony = 3
    add_child(acceleration)
    _refresh_streams()


func update_audio(delta: float, exhaust_visible: bool,
        acceleration_burst: bool) -> void:
    if sustained == null or acceleration == null:
        return
    if not sound_ready:
        load_retry_elapsed += maxf(delta, 0.0)
        if load_retry_elapsed >= LOAD_RETRY_SECONDS:
            load_retry_elapsed = 0.0
            _refresh_streams()
        if not sound_ready:
            return
    var target: float = 1.0 if exhaust_visible else 0.0
    var duration: float = (
        FADE_IN_SECONDS if exhaust_visible else FADE_OUT_SECONDS)
    # Animate LINEAR AMPLITUDE, not dB. This avoids an abrupt click at
    # engine exit and gives the last 220 ms of 01 an audible smooth tail.
    sustained_gain = move_toward(
        sustained_gain, target,
        maxf(delta, 0.0) / maxf(duration, 0.001))
    if exhaust_visible and not sustained.playing:
        sustained.volume_db = SILENT_DB
        sustained.play()
        sustained_starts += 1
    if sustained.playing:
        sustained.volume_db = (
            SUSTAINED_VOLUME_DB
            + linear_to_db(maxf(sustained_gain, 0.0001)))
        if not exhaust_visible and sustained_gain <= 0.00001:
            sustained.stop()
            sustained.volume_db = SILENT_DB
            fade_completions += 1
    # STEP onset / melee target chase / bash tracking / follow-up lunge:
    # use the SAME existing gameplay acceleration edge as nozzle FX.
    # BOOST alone has no artificial launch pulse: only the steady 01.
    if acceleration_burst and exhaust_visible:
        acceleration.play()
        acceleration_triggers += 1


func stop_immediately() -> void:
    # Scene teardown/reset only. Normal player movement always fades.
    sustained_gain = 0.0
    if sustained != null:
        sustained.stop()
        sustained.volume_db = SILENT_DB
    if acceleration != null:
        acceleration.stop()

extends Node
## v457 SERA dedicated two-layer booster soundtrack.
## 01 = true gapless sustained exhaust; 13-1 = independent acceleration.
## They overlap deliberately: the sustained layer never restarts during
## consecutive steps, booster input, or an ongoing melee homing phase.
const CONTINUOUS_STREAM: AudioStream = preload(
    "res://assets/sera_thruster_01_loop.ogg")
const ACCELERATION_STREAM: AudioStream = preload(
    "res://assets/sera_thruster_13_1_acceleration.ogg")
const FADE_IN_SECONDS: float = 0.075
const FADE_OUT_SECONDS: float = 0.22
const SUSTAINED_VOLUME_DB: float = -12.5
const ACCELERATION_VOLUME_DB: float = -3.0
const SILENT_DB: float = -80.0

var sustained: AudioStreamPlayer
var acceleration: AudioStreamPlayer
var sustained_gain: float = 0.0
var acceleration_triggers: int = 0
var sustained_starts: int = 0
var fade_completions: int = 0

func _ready() -> void:
    sustained = AudioStreamPlayer.new()
    sustained.name = "Thruster01SustainedLoop"
    sustained.stream = CONTINUOUS_STREAM
    sustained.volume_db = SILENT_DB
    sustained.max_polyphony = 1
    add_child(sustained)
    # The Ogg file was offline crossfaded at a stable waveform segment.
    # The Godot Vorbis decoder loops this encoded stream sample-accurately.
    if sustained.stream is AudioStreamOggVorbis:
        (sustained.stream as AudioStreamOggVorbis).loop = true

    acceleration = AudioStreamPlayer.new()
    acceleration.name = "Thruster13_1Acceleration"
    acceleration.stream = ACCELERATION_STREAM
    acceleration.volume_db = ACCELERATION_VOLUME_DB
    acceleration.max_polyphony = 3
    add_child(acceleration)


func update_audio(delta: float, exhaust_visible: bool,
        acceleration_burst: bool) -> void:
    if sustained == null or acceleration == null:
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

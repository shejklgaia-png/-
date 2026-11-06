extends Node
## v104 training-stage music: play the drum intro once, then loop the main track.
## Deliberately independent of gameplay, combat SFX and camera scripts.

const INTRO_PATH: String = "res://assets/sera_training_v08_intro.ogg"
const LOOP_PATH: String = "res://assets/sera_training_v08_loop.ogg"
const MUSIC_VOLUME_DB: float = -9.0

var intro_player: AudioStreamPlayer
var loop_player: AudioStreamPlayer

func _ready() -> void:
    if not ResourceLoader.exists(INTRO_PATH) or not ResourceLoader.exists(LOOP_PATH):
        push_warning("SERA stage BGM missing: both .ogg files must be under res://assets/")
        return

    var intro_stream: AudioStreamOggVorbis = load(INTRO_PATH) as AudioStreamOggVorbis
    var loop_stream: AudioStreamOggVorbis = load(LOOP_PATH) as AudioStreamOggVorbis
    if intro_stream == null or loop_stream == null:
        push_warning("SERA stage BGM files must be valid Ogg Vorbis resources")
        return

    intro_stream.loop = false
    loop_stream.loop = true
    loop_stream.loop_offset = 0.0

    intro_player = AudioStreamPlayer.new()
    intro_player.name = "StageBGMIntro"
    intro_player.stream = intro_stream
    intro_player.volume_db = MUSIC_VOLUME_DB
    add_child(intro_player)

    loop_player = AudioStreamPlayer.new()
    loop_player.name = "StageBGMLoop"
    loop_player.stream = loop_stream
    loop_player.volume_db = MUSIC_VOLUME_DB
    add_child(loop_player)

    intro_player.finished.connect(_on_intro_finished)
    intro_player.play()

func _on_intro_finished() -> void:
    if is_instance_valid(loop_player) and loop_player.stream != null:
        loop_player.play()

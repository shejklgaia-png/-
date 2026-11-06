extends Node
## v105: Decode Ogg directly from the project files so Android GitSync imports
## are not a prerequisite for starting the stage music.

const INTRO_PATH: String = "res://BGM/sera_training_v08_intro.ogg"
const LOOP_PATH: String = "res://BGM/sera_training_v08_loop.ogg"
const MUSIC_VOLUME_DB: float = -9.0

var intro_player: AudioStreamPlayer
var loop_player: AudioStreamPlayer

func _ready() -> void:
    # Start after the scene is fully attached to the tree/audio system.
    call_deferred("_start_bgm")

func _start_bgm() -> void:
    # Do not use ResourceLoader.exists/load here: it can depend on the import
    # cache, which may be stale immediately after an Android GitSync pull.
    var intro_stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(INTRO_PATH)
    var loop_stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(LOOP_PATH)
    if intro_stream == null or loop_stream == null:
        push_error("SERA BGM: failed to load Ogg. intro file=" + str(FileAccess.file_exists(INTRO_PATH)) + ", loop file=" + str(FileAccess.file_exists(LOOP_PATH)) + ". Check BGM/ in the Godot project folder.")
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
    print("SERA BGM: intro playing (" + str(intro_stream.get_length()) + " s)")

func _on_intro_finished() -> void:
    if is_instance_valid(loop_player) and loop_player.stream != null:
        loop_player.play()
        print("SERA BGM: loop playing")

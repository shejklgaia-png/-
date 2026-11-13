extends Node
## v105: Decode Ogg directly from the project files so Android GitSync imports
## are not a prerequisite for starting the stage music.

# The provided 130 BPM track has its ending crossfaded into bar 9.
# AudioStreamOggVorbis loops inside one decoder, avoiding a two-player gap.
const SECTOR_PATH: String = "res://BGM/dennou_sector_seamless.ogg"
const SECTOR_LOOP_OFFSET_SECONDS: float = 18.46153846
const INTRO_PATH: String = "res://BGM/sera_training_v08_intro.ogg"
const LOOP_PATH: String = "res://BGM/sera_training_v08_loop.ogg"
const MUSIC_VOLUME_DB: float = -9.0

var intro_player: AudioStreamPlayer
var loop_player: AudioStreamPlayer

func _ready() -> void:
    # Start after the scene is fully attached to the tree/audio system.
    call_deferred("_start_bgm")

func _start_bgm() -> void:
    # Prefer the user-supplied new song. If the binary asset has not been
    # synced yet, leave the existing BGM fully functional rather than erroring.
    if FileAccess.file_exists(SECTOR_PATH):
        var sector_stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(SECTOR_PATH)
        if sector_stream != null:
            sector_stream.loop = true
            sector_stream.loop_offset = SECTOR_LOOP_OFFSET_SECONDS
            intro_player = AudioStreamPlayer.new()
            intro_player.name = "StageBGMSector"
            intro_player.stream = sector_stream
            intro_player.volume_db = MUSIC_VOLUME_DB
            add_child(intro_player)
            intro_player.play()
            print("SERA BGM: Dennou Sector playing; loop offset " + str(SECTOR_LOOP_OFFSET_SECONDS))
            return
        push_warning("SERA BGM: Dennou Sector failed to decode; keeping the previous track.")
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

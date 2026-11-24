extends CanvasLayer
## The root overlay covers both completed-frame scenes throughout BASE construction.
const FADE_OUT_SECONDS := 0.55
const FADE_IN_SECONDS := 0.8
const BGM_FADE_OUT_SECONDS := 2.4
var _bgm_fade: Tween
var _cover: ColorRect
var _source: Node3D
var _music: AudioStreamPlayer
var _volume: float = -9.0

func run(source: Node3D, music: AudioStreamPlayer, scene_path: String) -> void:
    _source = source
    _music = music
    layer = 200
    _cover = ColorRect.new()
    _cover.color = Color.BLACK
    _cover.modulate.a = 0.0
    _cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_cover)
    _cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var fade := create_tween().set_parallel(true)
    fade.tween_property(_cover, "modulate:a", 1.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    if is_instance_valid(_music):
        _volume = _music.volume_db
        _begin_bgm_fade()
    await fade.finished
    var tree := get_tree()
    await tree.process_frame
    await tree.process_frame
    var request := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if request != OK:
        await _recover("BASE threaded load request failed: %d" % request)
        return
    var status := ResourceLoader.load_threaded_get_status(scene_path)
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        await tree.process_frame
        status = ResourceLoader.load_threaded_get_status(scene_path)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        await _recover("BASE threaded load failed: %d" % status)
        return
    var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
    if packed == null:
        await _recover("BASE packed scene invalid")
        return
    # The real load proceeds concurrently with the sound tail. Do not free
    # the outgoing scene (and its player) before the fade is finished.
    if _bgm_fade != null and _bgm_fade.is_running():
        await _bgm_fade.finished
    if is_instance_valid(_music):
        _music.stop()
    var error := tree.change_scene_to_packed(packed)
    if error != OK:
        await _recover("BASE scene change failed: %d" % error)
        return
    await tree.scene_changed
    var world := tree.current_scene.get_node_or_null("CompletedFrameContainer/CompletedFrame/BaseExplorationWorld")
    # scene_changed alone is insufficient: BASE builds over several frames.
    while is_instance_valid(world) and not bool(world.get_meta("sera_base_boot_complete", false)):
        await tree.process_frame
    await tree.process_frame
    await tree.process_frame
    if is_instance_valid(world) and world.has_method("_start_base_bgm"):
        world.call("_start_base_bgm", true)
    var reveal := create_tween()
    reveal.tween_property(_cover, "modulate:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await reveal.finished
    queue_free()

func _input(_event: InputEvent) -> void:
    # Block underlying raw input as well as normal GUI while covered.
    get_viewport().set_input_as_handled()

func _begin_bgm_fade() -> void:
    if not is_instance_valid(_music) or not _music.playing:
        return
    _bgm_fade = create_tween()
    # Interpolate audible amplitude, not dB. A dB-linear sweep loses most
    # perceived volume early. A sine ease preserves the opening tail.
    _bgm_fade.tween_method(_set_bgm_gain, db_to_linear(_volume), 0.0,
        BGM_FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_bgm_gain(gain: float) -> void:
    if is_instance_valid(_music):
        _music.volume_db = linear_to_db(maxf(gain, 0.0001))

func _recover(message: String) -> void:
    if _bgm_fade != null and _bgm_fade.is_valid():
        _bgm_fade.kill()
    push_error(message)
    var reveal := create_tween().set_parallel(true)
    reveal.tween_property(_cover, "modulate:a", 0.0, FADE_IN_SECONDS)
    if is_instance_valid(_music):
        if not _music.playing:
            _music.play()
        reveal.tween_property(_music, "volume_db", _volume, FADE_IN_SECONDS)
    await reveal.finished
    queue_free()

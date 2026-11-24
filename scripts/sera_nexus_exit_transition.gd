extends CanvasLayer
## The root overlay covers both completed-frame scenes throughout BASE construction.
const FADE_OUT_SECONDS := 0.55
const FADE_IN_SECONDS := 0.8
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
        fade.tween_property(_music, "volume_db", -60.0, FADE_OUT_SECONDS)
    await fade.finished
    if is_instance_valid(_music):
        _music.stop()
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

func _recover(message: String) -> void:
    push_error(message)
    var reveal := create_tween().set_parallel(true)
    reveal.tween_property(_cover, "modulate:a", 0.0, FADE_IN_SECONDS)
    if is_instance_valid(_music):
        if not _music.playing:
            _music.play()
        reveal.tween_property(_music, "volume_db", _volume, FADE_IN_SECONDS)
    await reveal.finished
    queue_free()

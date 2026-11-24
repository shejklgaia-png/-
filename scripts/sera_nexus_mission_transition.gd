extends CanvasLayer
## Root overlay survives the completed-frame viewport scene swap.
const DOLLY_SECONDS := 2.4
const REVEAL_SECONDS := 0.8
const COVER_SECONDS := 0.65
const GATE_COLOR := Color("#c6e6f0")
var _cover: ColorRect
var _source: Node3D
var _camera: Camera3D
var _hud: Control
var _music: AudioStreamPlayer
var _pose: Transform3D
var _fov: float
var _volume: float
var _hud_visible: bool
var _was_playing: bool
var _music_position: float

func run(source: Node3D, camera: Camera3D, portal: Node3D,
        hud: Control, music: AudioStreamPlayer, motion: Node3D,
        scene_path: String) -> void:
    _source = source
    _camera = camera
    _hud = hud
    _music = music
    _pose = camera.global_transform
    _fov = camera.fov
    _hud_visible = hud.visible
    _hud.hide()
    layer = 200
    _cover = ColorRect.new()
    _cover.color = GATE_COLOR
    _cover.modulate.a = 0.0
    _cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_cover)
    _cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if is_instance_valid(_music):
        _volume = _music.volume_db
        _was_playing = _music.playing
        _music_position = _music.get_playback_position()

    # The mission row can be tapped before the sliding leaves finish.
    # Never advance through partially closed armor.
    if is_instance_valid(motion):
        motion.call("set_deployment_open", true)
        var remaining := 3.0
        while not bool(motion.call("is_deployment_fully_open")):
            await get_tree().process_frame
            remaining -= get_process_delta_time()
            if remaining <= 0.0:
                await _recover("NEXUS mission gate did not open")
                return
    # Actual perspective dolly through the physical aperture, not a
    # zoom of the UI or an unrelated camera focus point.
    var eye := portal.to_global(Vector3(0.0, 2.36, -1.55))
    var forward := -portal.global_transform.basis.z.normalized()
    var destination := Transform3D(Basis.looking_at(forward, Vector3.UP), eye)
    var departure := create_tween().set_parallel(true)
    departure.tween_method(_dolly.bind(destination), 0.0, 1.0,
        DOLLY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    departure.tween_property(_cover, "modulate:a", 1.0, COVER_SECONDS
        ).set_delay(DOLLY_SECONDS - COVER_SECONDS).set_trans(Tween.TRANS_SINE
        ).set_ease(Tween.EASE_IN_OUT)
    if _was_playing:
        # Fade audible amplitude rather than decibels, avoiding an early
        # apparent cutoff. Silence is reached BEFORE requesting the load.
        departure.tween_method(_set_gain, db_to_linear(_volume), 0.0,
            DOLLY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await departure.finished
    _cover.modulate.a = 1.0
    if is_instance_valid(_music):
        _music.stop()
    var tree := get_tree()
    await tree.process_frame
    await tree.process_frame
    var request := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if request != OK:
        await _recover("Mission load request failed: %d" % request)
        return
    var status := ResourceLoader.load_threaded_get_status(scene_path)
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        await tree.process_frame
        status = ResourceLoader.load_threaded_get_status(scene_path)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        await _recover("Mission load failed: %d" % status)
        return
    var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
    if packed == null:
        await _recover("Mission packed scene invalid")
        return
    var error := tree.change_scene_to_packed(packed)
    if error != OK:
        await _recover("Mission scene change failed: %d" % error)
        return
    await tree.scene_changed
    # The root overlay also covers the first completed battle viewport.
    await tree.process_frame
    await tree.process_frame
    var world := tree.current_scene.get_node_or_null(
        "CompletedFrameContainer/CompletedBattleFrame/BittaranBattleWorld")
    var reveal := create_tween()
    reveal.tween_property(_cover, "modulate:a", 0.0, REVEAL_SECONDS
        ).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await reveal.finished
    if is_instance_valid(world) and world.has_method("begin_mission_battle"):
        world.call("begin_mission_battle")
    queue_free()

func _input(_event: InputEvent) -> void:
    get_viewport().set_input_as_handled()

func _dolly(progress: float, destination: Transform3D) -> void:
    if is_instance_valid(_camera):
        _camera.global_transform = _pose.interpolate_with(destination, progress)

func _set_gain(gain: float) -> void:
    if is_instance_valid(_music):
        _music.volume_db = linear_to_db(maxf(gain, 0.0001))

func _recover(message: String) -> void:
    push_error(message)
    if is_instance_valid(_source):
        _camera.global_transform = _pose
        _camera.fov = _fov
        _hud.visible = _hud_visible
        if is_instance_valid(_music):
            _music.volume_db = _volume
            if _was_playing and not _music.playing:
                _music.play(_music_position)
    var reveal := create_tween()
    reveal.tween_property(_cover, "modulate:a", 0.0, 0.35)
    await reveal.finished
    if is_instance_valid(_source):
        _source.call("recover_mission_departure")
    queue_free()

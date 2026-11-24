extends CanvasLayer
## Root-window overlay survives removal of the BASE completed-frame viewport.
const TARGET_SECONDS := 4.0
const OPEN_SECONDS := 0.65
const ZOOM_SECONDS := 0.95
const REVEAL_SECONDS := 0.8
const SOFT_WHITE := Color("#dce4e8")
const SHUTTER_FEATURES := ["NexusBlastDoor", "NexusBlastShutterSlat"]
const SHUTTER_SFX_PATH := "res://BGM/巨大シャッターが開く.mp3"
const SHUTTER_SFX_VOLUME_DB := -6.0
# Waveform: 0.00s RMS -61dBFS, 0.23s RMS -18.7dBFS.
const SHUTTER_SFX_START_SECONDS := 0.23
const SHUTTER_SFX_FADE_SECONDS := 0.35
var _cover: ColorRect
var _model: Node3D
var _camera: Camera3D
var _base: Node3D
var _hud: Control
var _music: AudioStreamPlayer
var _shutter_sfx: AudioStreamPlayer
var _start_pose: Transform3D
var _start_size: float
var _start_volume: float
var _hud_visible: bool
var _started_ms: int

func run(base: Node3D, camera: Camera3D, model: Node3D, hud: Control,
        music: AudioStreamPlayer, scene_path: String, shutter_clip: AudioStreamMP3 = null) -> void:
    _base = base
    _camera = camera
    _model = model
    _hud = hud
    _music = music
    _started_ms = Time.get_ticks_msec()
    _start_pose = camera.global_transform
    _start_size = camera.size
    _hud_visible = hud.visible
    _hud.hide()
    layer = 200
    _cover = ColorRect.new()
    _cover.color = SOFT_WHITE
    _cover.modulate.a = 0.0
    _cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_cover)
    _cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if is_instance_valid(_music):
        _start_volume = _music.volume_db
        var audio_fade := create_tween()
        audio_fade.tween_property(_music, "volume_db", -60.0, 1.4).set_trans(Tween.TRANS_SINE)
    _play_shutter_sfx(shutter_clip)
    var opening := create_tween()
    opening.tween_method(_set_shutter, 0.0, 1.0, OPEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await opening.finished
    var yaw := float(model.get_meta("body_yaw", 0.0))
    var scale_factor := float(model.get_meta("visual_model_scale", 1.0))
    var turn := Basis(Vector3.UP, yaw)
    var portal := model.to_global(turn * (Vector3(0, 1.65, 2.54) * scale_factor))
    var eye := portal + turn * Vector3(0, 0.18, 7.0)
    var end_pose := Transform3D(Basis.IDENTITY, eye).looking_at(portal, Vector3.UP)
    var zoom := create_tween().set_parallel(true)
    zoom.tween_method(_zoom_camera.bind(end_pose), 0.0, 1.0, ZOOM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    zoom.tween_property(_cover, "modulate:a", 1.0, 0.40).set_delay(ZOOM_SECONDS - 0.40).set_trans(Tween.TRANS_SINE)
    if is_instance_valid(_shutter_sfx):
        zoom.tween_property(_shutter_sfx, "volume_db", -60.0, SHUTTER_SFX_FADE_SECONDS).set_delay(ZOOM_SECONDS - SHUTTER_SFX_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    await zoom.finished
    _stop_shutter_sfx()
    _cover.modulate.a = 1.0
    if is_instance_valid(_music):
        _music.stop()
    var tree := get_tree()
    # Ensure at least one fully white frame has been presented before loading.
    await tree.process_frame
    await tree.process_frame
    var request := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if request != OK:
        await _recover("NEXUS threaded load request failed: %d" % request)
        return
    var status := ResourceLoader.load_threaded_get_status(scene_path)
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        await tree.process_frame
        status = ResourceLoader.load_threaded_get_status(scene_path)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        await _recover("NEXUS threaded load failed: %d" % status)
        return
    var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
    if packed == null:
        await _recover("NEXUS loaded scene is invalid")
        return
    var error := tree.change_scene_to_packed(packed)
    if error != OK:
        await _recover("NEXUS scene change failed: %d" % error)
        return
    await tree.scene_changed
    # NEXUS synchronous _ready and deferred placement restoration finish
    # behind the root overlay, including the first completed viewport frame.
    await tree.process_frame
    await tree.process_frame
    var world := tree.current_scene.get_node_or_null("CompletedFrameContainer/CompletedFrame/CommandNexusWorld")
    var elapsed := float(Time.get_ticks_msec() - _started_ms) / 1000.0
    var hold := TARGET_SECONDS - REVEAL_SECONDS - elapsed
    if hold > 0.0:
        await tree.create_timer(hold).timeout
    if is_instance_valid(world) and world.has_method("start_entry_bgm"):
        world.call("start_entry_bgm")
    var reveal := create_tween()
    reveal.tween_property(_cover, "modulate:a", 0.0, REVEAL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await reveal.finished
    queue_free()

static func load_shutter_clip() -> AudioStreamMP3:
    # Raw MP3 for GitSync before import, imported resource for exported APKs.
    var clip: AudioStreamMP3
    if FileAccess.file_exists(SHUTTER_SFX_PATH):
        clip = AudioStreamMP3.load_from_file(SHUTTER_SFX_PATH)
    if clip == null and ResourceLoader.exists(SHUTTER_SFX_PATH):
        clip = ResourceLoader.load(SHUTTER_SFX_PATH) as AudioStreamMP3
        if clip != null:
            clip = clip.duplicate() as AudioStreamMP3
    if clip != null:
        clip.loop = false
    return clip

func _play_shutter_sfx(prepared_clip: AudioStreamMP3) -> void:
    var clip: AudioStreamMP3 = prepared_clip
    if clip == null:
        clip = load_shutter_clip()
    if clip == null:
        push_warning("SERA: NEXUS shutter SFX unavailable")
        return
    _shutter_sfx = AudioStreamPlayer.new()
    _shutter_sfx.name = "NexusShutterOpenSFX"
    _shutter_sfx.stream = clip
    _shutter_sfx.volume_db = SHUTTER_SFX_VOLUME_DB
    add_child(_shutter_sfx)
    _shutter_sfx.play(SHUTTER_SFX_START_SECONDS)

func _stop_shutter_sfx() -> void:
    if is_instance_valid(_shutter_sfx):
        _shutter_sfx.stop()
        _shutter_sfx.queue_free()
        _shutter_sfx = null

func _set_shutter(progress: float) -> void:
    if not is_instance_valid(_model):
        return
    var records: Dictionary = _model.get_meta("motion_entries", {})
    var scale_factor := float(_model.get_meta("visual_model_scale", 1.0))
    var header_y := 3.04 * scale_factor
    var remaining := lerpf(1.0, 0.015, progress)
    # Roll the slats into the header, rather than pushing them through the roof.
    for feature in SHUTTER_FEATURES:
        for record in records.get(feature, []):
            var mesh: MultiMesh = record["mesh"]
            var rest: Transform3D = record["bind"]
            var pose := rest
            pose.origin.y = header_y + (rest.origin.y - header_y) * remaining
            pose.basis = rest.basis.scaled_local(Vector3(1.0, remaining, 1.0))
            mesh.set_instance_transform(int(record["index"]), pose)

func _zoom_camera(progress: float, end_pose: Transform3D) -> void:
    _camera.global_transform = _start_pose.interpolate_with(end_pose, progress)
    # Exponential zoom feels continuous across the large orthographic range.
    _camera.size = _start_size * pow(1.9 / _start_size, progress)

func _recover(message: String) -> void:
    _stop_shutter_sfx()
    push_error(message)
    if is_instance_valid(_base):
        _camera.global_transform = _start_pose
        _camera.size = _start_size
        _set_shutter(0.0)
        _hud.visible = _hud_visible
        if is_instance_valid(_music):
            _music.volume_db = _start_volume
            if not _music.playing:
                _music.play()
    var fade := create_tween()
    fade.tween_property(_cover, "modulate:a", 0.0, 0.35)
    await fade.finished
    if is_instance_valid(_base):
        _base.set("scene_changing", false)
    queue_free()

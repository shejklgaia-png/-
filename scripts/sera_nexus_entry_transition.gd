extends CanvasLayer
## Root-window overlay survives removal of the BASE completed-frame viewport.
const TARGET_SECONDS := 4.0
const OPEN_SECONDS := 0.65
const ZOOM_SECONDS := 0.95
const REVEAL_SECONDS := 0.8
const BGM_FADE_OUT_SECONDS := 2.4
var _bgm_fade: Tween
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
        _begin_bgm_fade()
    _play_shutter_sfx(shutter_clip)
    var opening := create_tween()
    opening.tween_method(_set_shutter, 0.0, 1.0, OPEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await opening.finished
    var yaw := float(model.get_meta("body_yaw", 0.0))
    var scale_factor := float(model.get_meta("visual_model_scale", 1.0))
    var turn := Basis(Vector3.UP, yaw)
    var portal := model.to_global(turn * (Vector3(0, 1.65, 2.54) * scale_factor))
    # Orthographic dolly/pan: retain the overhead camera orientation and
    # depth. The entrance moves along one straight screen-space line.
    var view_back := _start_pose.basis.z.normalized()
    var eye := portal + view_back * (_start_pose.origin - portal).dot(view_back)
    var zoom := create_tween().set_parallel(true)
    zoom.tween_method(_zoom_camera.bind(eye), 0.0, 1.0, ZOOM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    zoom.tween_property(_cover, "modulate:a", 1.0, 0.40).set_delay(ZOOM_SECONDS - 0.40).set_trans(Tween.TRANS_SINE)
    if is_instance_valid(_shutter_sfx):
        zoom.tween_property(_shutter_sfx, "volume_db", -60.0, SHUTTER_SFX_FADE_SECONDS).set_delay(ZOOM_SECONDS - SHUTTER_SFX_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    await zoom.finished
    _stop_shutter_sfx()
    _cover.modulate.a = 1.0
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
    # The real load proceeds concurrently with the sound tail. Do not free
    # the outgoing scene (and its player) before the fade is finished.
    if _bgm_fade != null and _bgm_fade.is_running():
        await _bgm_fade.finished
    if is_instance_valid(_music):
        _music.stop()
    var error := tree.change_scene_to_packed(packed)
    if error != OK:
        await _recover("NEXUS scene change failed: %d" % error)
        return
    await tree.scene_changed
    # The world can now build over several frames under this opaque cover.
    # Do not reveal until construction and deferred placement have completed.
    var world := tree.current_scene.get_node_or_null("CompletedFrameContainer/CompletedFrame/CommandNexusWorld")
    while is_instance_valid(world) and not bool(world.get_meta("sera_nexus_boot_complete", false)):
        await tree.process_frame
    await tree.process_frame
    await tree.process_frame
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
    var geometry: Dictionary = _model.get_meta("nexus_shutter_geometry", {})
    if geometry.is_empty():
        return
    var yaw := float(_model.get_meta("body_yaw", 0.0))
    var travel := float(geometry["travel"]) * clampf(progress, 0.0, 1.0)
    var pitch := float(geometry["pitch"])
    var first_y := float(geometry["first_y"])
    var store_y := float(geometry["store_y"])
    var rear := Basis(Vector3.UP, yaw) * Vector3.FORWARD
    for feature in SHUTTER_FEATURES:
        for record in records.get(feature, []):
            var mesh: MultiMesh = record["mesh"]
            var rest: Transform3D = record["bind"]
            var pose := rest
            var local_y := rest.origin.y / scale_factor
            var row := roundi((local_y - first_y) / pitch)
            var rise := maxf(0.0, store_y - local_y)
            pose.origin.y += minf(travel, rise) * scale_factor
            # Above the visible opening, slide each section into its own
            # depth slot. No scaling, rotation, or travel above the cassette.
            var tucked := smoothstep(0.0, 0.45, maxf(0.0, travel - rise))
            pose.origin += rear * (float(row) * float(geometry["stack_depth"]) * tucked * scale_factor)
            mesh.set_instance_transform(int(record["index"]), pose)
    var vfx := _model.get_node_or_null("BaseFacilityVFX")
    if is_instance_valid(vfx) and vfx.has_method("set_nexus_shutter_open"):
        vfx.call("set_nexus_shutter_open", progress)

func _zoom_camera(progress: float, end_position: Vector3) -> void:
    var size := _start_size * pow(1.9 / _start_size, progress)
    # Compensate for orthographic magnification so the entrance stays on
    # the straight line from its initial screen position to screen center.
    var pan := 1.0 - (1.0 - progress) * size / _start_size
    _camera.global_transform = Transform3D(_start_pose.basis,
        _start_pose.origin.lerp(end_position, pan))
    _camera.size = size

func _begin_bgm_fade() -> void:
    if not is_instance_valid(_music) or not _music.playing:
        return
    _bgm_fade = create_tween()
    # Interpolate audible amplitude, not dB. A dB-linear sweep loses most
    # perceived volume early. A sine ease preserves the opening tail.
    _bgm_fade.tween_method(_set_bgm_gain, db_to_linear(_start_volume), 0.0,
        BGM_FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_bgm_gain(gain: float) -> void:
    if is_instance_valid(_music):
        _music.volume_db = linear_to_db(maxf(gain, 0.0001))

func _recover(message: String) -> void:
    if _bgm_fade != null and _bgm_fade.is_valid():
        _bgm_fade.kill()
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

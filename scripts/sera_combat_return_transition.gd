extends CanvasLayer
## Combat/Training -> NEXUS. Root-owned black cover survives the old
## CompletedBattleFrame and the new CompletedFrame SubViewport.
const FADE_OUT_SECONDS: float = 0.55
const FADE_IN_SECONDS: float = 0.8
const NEXUS_WORLD_PATH: NodePath = ^"CompletedFrameContainer/CompletedFrame/CommandNexusWorld"

var _cover: ColorRect
var _source: Node3D

func run(source: Node3D, scene_path: String) -> void:
    _source = source
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 200
    _cover = ColorRect.new()
    _cover.color = Color.BLACK
    _cover.modulate.a = 0.0
    _cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_cover)
    _cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var fade := create_tween()
    fade.set_ignore_time_scale(true)
    fade.tween_property(_cover, "modulate:a", 1.0, FADE_OUT_SECONDS
        ).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await fade.finished
    _cover.modulate.a = 1.0
    var tree := get_tree()
    # Present an entirely black frame before any destination loading.
    await tree.process_frame
    if RenderingServer.render_loop_enabled:
        await RenderingServer.frame_post_draw
    else:
        await tree.process_frame
    var request := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if request != OK:
        await _recover("Combat return load request failed: %d" % request)
        return
    var status := ResourceLoader.load_threaded_get_status(scene_path)
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        await tree.process_frame
        status = ResourceLoader.load_threaded_get_status(scene_path)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        await _recover("Combat return load failed: %d" % status)
        return
    var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
    if packed == null:
        await _recover("Combat return scene invalid")
        return
    var error := tree.change_scene_to_packed(packed)
    if error != OK:
        await _recover("Combat return scene change failed: %d" % error)
        return
    await tree.scene_changed
    var world := tree.current_scene.get_node_or_null(NEXUS_WORLD_PATH)
    # scene_changed alone does not mean the budgeted NEXUS world is ready.
    while is_instance_valid(world) and not bool(world.get_meta("sera_nexus_boot_complete", false)):
        await tree.process_frame
    if not is_instance_valid(world):
        push_error("Combat return: NEXUS world missing")
    # Deferred placement, HUD and compositor receive the same two-frame
    # settling interval as the established NEXUS entry transition.
    await tree.process_frame
    await tree.process_frame
    if RenderingServer.render_loop_enabled:
        await RenderingServer.frame_post_draw
    if is_instance_valid(world) and world.has_method("start_entry_bgm"):
        world.call("start_entry_bgm")
    await _reveal()
    queue_free()

func _input(_event: InputEvent) -> void:
    get_viewport().set_input_as_handled()

func _reveal() -> void:
    var fade := create_tween()
    fade.set_ignore_time_scale(true)
    fade.tween_property(_cover, "modulate:a", 0.0, FADE_IN_SECONDS
        ).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await fade.finished

func _recover(message: String) -> void:
    push_error(message)
    await _reveal()
    if is_instance_valid(_source):
        _source.set("_returning_to_nexus", false)
    queue_free()

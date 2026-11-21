extends Control
## One on-demand real SeraRig viewer per active preview. Paused when hidden.
## The identical source is used by LABO, WAREHOUSE and NEXUS; never per card.
const EquipmentPreview = preload("res://tools/equipment_intake/godot_preview.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const DEFAULT_YAW: float = -34.0
const DEFAULT_PITCH: float = 26.0

var render_viewport: SubViewport
var preview_scene: Node3D
var preview_host: SubViewportContainer
var ready_for_commands: bool = false
var current_blueprint: String = ""
var active_preview: bool = false
var selected_parts: Dictionary = {}
var _request_serial: int = 0
var _pressed_mouse: bool = false
var _last_mouse: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    preview_host = SubViewportContainer.new()
    preview_host.name = "RealPartPreviewHost"
    preview_host.stretch = true
    preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(preview_host)
    var cue: Control = RotateMark.new()
    cue.name = "RotateCue"
    cue.position = Vector2(6, 6)
    cue.size = Vector2(28, 28)
    cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(cue)
    resized.connect(_resize_viewport)

func _make_viewport() -> void:
    if render_viewport != null:
        return
    render_viewport = SubViewport.new()
    render_viewport.name = "PartViewerViewport"
    render_viewport.size = Vector2i(384, 384)
    render_viewport.own_world_3d = true
    render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    preview_host.add_child(render_viewport)
    preview_scene = EquipmentPreview.new()
    preview_scene.name = "RealEquipmentRigPreview"
    render_viewport.add_child(preview_scene)
    _resize_viewport()

func _resize_viewport() -> void:
    if render_viewport == null:
        return
    var edge: int = clampi(roundi(minf(maxf(size.x, 1.0),
        maxf(size.y, 1.0))), 96, 512)
    render_viewport.size = Vector2i(edge, edge)

func show_part(blueprint: String, selections: Dictionary = {}) -> void:
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return
    current_blueprint = blueprint
    selected_parts = selections.duplicate(true)
    active_preview = true
    show()
    _request_serial += 1
    _make_viewport()
    render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _load_part.call_deferred(_request_serial)

func _load_part(request: int) -> void:
    for i in range(40):
        if not is_instance_valid(preview_scene) or request != _request_serial:
            return
        if bool(preview_scene.get("ready_for_commands")):
            break
        await get_tree().process_frame
    if request != _request_serial or not is_instance_valid(preview_scene) or (
            not bool(preview_scene.get("ready_for_commands"))):
        push_warning("SERA part preview rig unavailable")
        return
    ready_for_commands = true
    var spec: Dictionary = Catalog.spec(current_blueprint)
    if spec.is_empty():
        return
    var parts: Dictionary = {}
    for slot in EquipmentPreview.SLOT_ORDER:
        parts[slot] = str(selected_parts.get(slot, "A"))
    var chosen_slot: String = str(spec.get("slot", "head"))
    parts[chosen_slot] = str(spec.get("rig_set", "A"))
    preview_scene.call("_apply_command", {
        "mode": "icon", "editing_slot": chosen_slot,
        "selected": parts, "size": 1.0, "keep_aspect": true,
        "background_mode": "grid",
        "camera": {"yaw": DEFAULT_YAW, "pitch": DEFAULT_PITCH,
            "roll": 0.0, "panX": 0.0, "panY": 0.0,
            "zoom": 1.0, "outlinePx": 3.0},
        "seq": request
    })

func set_preview_active(enabled: bool) -> void:
    active_preview = enabled
    if render_viewport != null:
        render_viewport.render_target_update_mode = (
            SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED)
    if not enabled:
        _request_serial += 1
        _pressed_mouse = false
        if is_instance_valid(preview_scene):
            preview_scene.call("_on_preview_touch", 0, false, Vector2.ZERO)

func feed_touch(index: int, pressed: bool, point: Vector2) -> void:
    if ready_for_commands and active_preview and is_instance_valid(preview_scene):
        preview_scene.call("_on_preview_touch", index, pressed, point)

func feed_drag(index: int, point: Vector2) -> void:
    if ready_for_commands and active_preview and is_instance_valid(preview_scene):
        preview_scene.call("_on_preview_drag", index, point)

func _gui_input(event: InputEvent) -> void:
    if not active_preview or not ready_for_commands:
        return
    if event is InputEventScreenTouch:
        feed_touch(event.index, event.pressed, event.position)
        accept_event()
    elif event is InputEventScreenDrag:
        feed_drag(event.index, event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _pressed_mouse = event.pressed
        _last_mouse = event.position
        feed_touch(-10, event.pressed, event.position)
        accept_event()
    elif event is InputEventMouseMotion and _pressed_mouse:
        _last_mouse = event.position
        feed_drag(-10, event.position)
        accept_event()

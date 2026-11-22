extends Control
## One on-demand real SeraRig viewer per active preview. Paused when hidden.
## The identical source is used by LABO, WAREHOUSE and NEXUS; never per card.
const EquipmentPreview = preload("res://tools/equipment_intake/godot_preview.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const IrisIDContour = preload("res://scripts/sera_iris_id_silhouette_preview.gd")
const IrisPolygonLight = preload("res://shaders/sera_iris_polygon_light.gdshader")
const SHADING_MODES = [0, 2, 3, 4]
const double_tap_window_msec: int = 330
signal preview_fullscreen_requested(enabled: bool)
# The live part preview starts at the same angle as the approved 19 PNGs.
const DEFAULT_YAW: float = 156.900744628906
const DEFAULT_PITCH: float = 11.8749389648438

var render_viewport: SubViewport
var preview_scene: Node3D
var preview_host: SubViewportContainer
var ready_for_commands: bool = false
var current_blueprint: String = ""
var active_preview: bool = false
## Opt-in ONLY for NEXUS. LABO/STORAGE keep the original 3D renderer.
var enable_nexus_iris_id_contour: bool = false
var _iris_contour: Control
var selected_parts: Dictionary = {}
var _request_serial: int = 0
var _pressed_mouse: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var shade_levels: int = 4
var fullscreen: bool = false
var _shade_column: VBoxContainer
var _shade_buttons: Dictionary = {}
var _fullscreen_close: Button
var _original_materials: Dictionary = {}
var _light_materials: Dictionary = {}
var _white_texture: ImageTexture
var _touch_starts: Dictionary = {}
var _ui_mode_touches: Dictionary = {}
var _last_tap_time: int = 0
var _last_tap_position: Vector2 = Vector2.ZERO

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
    _create_iris_controls()
    resized.connect(_layout_iris_controls)
    # With SubViewportContainer.stretch=true, Godot controls its size.
    # Do not fight it by assigning SubViewport.size after parenting.

func _create_iris_controls() -> void:
    _shade_column = VBoxContainer.new()
    _shade_column.name = "IrisShadeModeColumn"
    _shade_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _shade_column.add_theme_constant_override("separation", 3)
    _shade_column.visible = false
    add_child(_shade_column)
    for mode in SHADING_MODES:
        var button := Button.new()
        button.name = "IrisShade_%d" % mode
        button.text = "OFF" if mode == 0 else "%d段" % mode
        button.custom_minimum_size = Vector2(52, 42)
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 15)
        button.pressed.connect(set_shading_mode.bind(mode))
        _shade_column.add_child(button)
        _shade_buttons[mode] = button
    _fullscreen_close = Button.new()
    _fullscreen_close.name = "IrisFullscreenClose"
    _fullscreen_close.text = "縮小"
    _fullscreen_close.focus_mode = Control.FOCUS_NONE
    _fullscreen_close.custom_minimum_size = Vector2(76, 48)
    _fullscreen_close.pressed.connect(_request_close_fullscreen)
    _fullscreen_close.visible = false
    add_child(_fullscreen_close)
    _style_shading_buttons()
    _layout_iris_controls()


func _layout_iris_controls() -> void:
    if _shade_column == null:
        return
    _shade_column.position = Vector2(maxf(4.0, size.x - 62.0), 10.0)
    _shade_column.size = Vector2(52.0, 177.0)
    if _fullscreen_close != null:
        _fullscreen_close.position = Vector2(12.0, 12.0)
        _fullscreen_close.size = Vector2(76.0, 48.0)


func _style_shading_buttons() -> void:
    for mode in SHADING_MODES:
        var button: Button = _shade_buttons.get(mode) as Button
        if not is_instance_valid(button):
            continue
        var active: bool = shade_levels == mode
        var box := StyleBoxFlat.new()
        box.bg_color = Color("#325f72") if active else Color("#17303d")
        box.border_color = Color("#a7e9f6") if active else Color("#5c8190")
        box.set_border_width_all(2 if active else 1)
        box.set_corner_radius_all(3)
        button.add_theme_stylebox_override("normal", box)
        button.add_theme_stylebox_override("hover", box)
        button.add_theme_stylebox_override("pressed", box)
        button.add_theme_color_override("font_color", Color("#e7f6fa"))


func _is_iris_preview() -> bool:
    return enable_nexus_iris_id_contour and current_blueprint == "H02"


func set_fullscreen_state(enabled: bool) -> void:
    fullscreen = enabled
    _last_tap_time = 0
    _touch_starts.clear()
    _ui_mode_touches.clear()
    if is_instance_valid(_fullscreen_close):
        _fullscreen_close.visible = enabled
    _layout_iris_controls()


func _request_close_fullscreen() -> void:
    if fullscreen:
        preview_fullscreen_requested.emit(false)


func set_shading_mode(levels: int) -> void:
    if not SHADING_MODES.has(levels):
        return
    shade_levels = levels
    _style_shading_buttons()
    _apply_iris_shading()


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
    # SubViewportContainer stretches to the available square without
    # allocating additional render targets when a modal resizes.

func show_part(blueprint: String, selections: Dictionary = {}) -> void:
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return
    current_blueprint = blueprint
    if is_instance_valid(_iris_contour):
        _iris_contour.call("set_active", false)
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
    if enable_nexus_iris_id_contour and current_blueprint == "H02" and (
            request == _request_serial):
        if not is_instance_valid(_iris_contour):
            _iris_contour = IrisIDContour.new()
            add_child(_iris_contour)
            # Keep the rotation cue above this non-interactive ink layer.
            move_child(_iris_contour, get_child_count() - 2)
        _iris_contour.call("set_active", true, preview_scene, render_viewport)

func set_preview_active(enabled: bool) -> void:
    active_preview = enabled
    if render_viewport != null:
        render_viewport.render_target_update_mode = (
            SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED)
    if not enabled:
        if is_instance_valid(_iris_contour):
            _iris_contour.call("set_active", false)
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

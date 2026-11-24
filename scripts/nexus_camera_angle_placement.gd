extends Control
## Camera canonical placement for NEXUS focused console views.
## Available ONLY after a console has zoomed into its focus view.
## Developer previews are saved; official defaults are promoted separately.
const PlacementStore = preload("res://scripts/sera_placement_store.gd")

## Raw touch/mouse input is intercepted by the hosting NEXUS before menu input.

const DisplayProfile = preload("res://scripts/sera_display_profile.gd")
const SCENE_ID := "res://scenes/command_nexus.tscn"
const TARGETS := ["SYSTEM", "TRAINING", "DATA ARCHIVE", "DEPLOYMENT"]
const ORBIT_RATE := 0.0045
const ROLL_STEP_DEG := 5.0  # Twist about the camera's optical axis.

var host
# True only after the camera editor controls have been constructed.
var initialized := false
# Same pre-operation diagnostic stages used by the working LABO diagnostics.
# Only the actual failure phase is reported; no guessed "NOT READY" reason.
var initialization_stage := "NEW"
var active := false
var target_id := ""
var look_at_point := Vector3.ZERO
var distance := 6.0
var azimuth := 0.0
var elevation := 0.0
var roll_deg := 0.0
var reference_fov := 68.0
var pointer_id := -999
var pointer_mouse := false
var last_pointer := Vector2.ZERO
var _buttons: Dictionary = {}
var _status: Label
var _help: Label
var _visible_signature := ""


func configure(scene: Node3D) -> void:
    if initialized:
        return
    initialization_stage = "HUD"
    host = scene
    name = "NexusCameraAnglePlacement"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    var target_hud: Control = host.get("hud") as Control
    if target_hud != null:
        theme = target_hud.theme
    initialization_stage = "BUTTONS"
    _make_ui()
    initialization_stage = "SIGNALS"
    if not resized.is_connected(_sync_ui):
        resized.connect(_sync_ui)
    set_process(true)
    initialization_stage = "LAYOUT"
    _sync_ui()
    initialized = (_buttons.size() == 13
        and is_instance_valid(_status) and is_instance_valid(_help))
    initialization_stage = "READY" if initialized else "INCOMPLETE"


func _make_ui() -> void:
    for id in ["open", "exit", "copy", "zoom_in", "zoom_out",
            "look_left", "look_right", "look_up", "look_down",
            "fov_minus", "fov_plus", "roll_left", "roll_right"]:
        if _buttons.has(id):
            continue
        var panel := Panel.new()
        panel.name = "Angle_" + id
        panel.mouse_filter = Control.MOUSE_FILTER_STOP
        var frame := StyleBoxFlat.new()
        frame.bg_color = Color("#193748", 0.96)
        frame.border_color = Color("#7cbdd6")
        frame.set_border_width_all(2)
        frame.set_corner_radius_all(5)
        panel.add_theme_stylebox_override("panel", frame)
        add_child(panel)
        var caption := Label.new()
        caption.text = _button_title(id)
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        caption.add_theme_font_size_override("font_size", 15)
        caption.add_theme_color_override("font_color", Color("#e1f7ff"))
        panel.add_child(caption)
        caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if id != "open":
            panel.gui_input.connect(_on_editor_panel_input.bind(id))
        _buttons[id] = panel
        panel.visible = false

    if not is_instance_valid(_status):
        _status = Label.new()
    _status.name = "CameraPlacementStatus"
    _status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _status.add_theme_font_size_override("font_size", 15)
    _status.add_theme_color_override("font_color", Color("#b9eafd"))
    if _status.get_parent() == null:
        add_child(_status)
    if not is_instance_valid(_help):
        _help = Label.new()
    _help.name = "CameraPlacementHelp"
    _help.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _help.add_theme_font_size_override("font_size", 14)
    _help.add_theme_color_override("font_color", Color("#a9cedd"))
    if _help.get_parent() == null:
        add_child(_help)


func _on_editor_panel_input(event: InputEvent, id: String) -> void:
    if not active or not _buttons.has(id):
        return
    var pressed: bool = (
        (event is InputEventScreenTouch and event.pressed)
        or (event is InputEventMouseButton and event.pressed
            and event.button_index == MOUSE_BUTTON_LEFT))
    var panel: Panel = _buttons[id]
    if pressed and panel.visible:
        _press(Rect2(panel.position, panel.size).get_center(), -999, false)
        get_viewport().set_input_as_handled()


func _button_title(id: String) -> String:
    var captions := {
        "open": "アングル正規配置", "exit": "編集終了",
        "copy": "アングルコピー", "zoom_in": "近づく ＋",
        "zoom_out": "離れる －", "look_left": "注視 ◀",
        "look_right": "注視 ▶", "look_up": "注視 ▲",
        "look_down": "注視 ▼", "fov_minus": "画角 －",
        "fov_plus": "画角 ＋",
        "roll_left": "回転 ↺", "roll_right": "回転 ↻"
    }
    return str(captions.get(id, id))


func _can_open() -> bool:
    return host != null and TARGETS.has(str(host.get("focused_target"))) and (
        not bool(host.get("in_transition")))


func _process(_delta: float) -> void:
    if host == null:
        return
    var s: Vector2 = get_viewport_rect().size
    var snapshot := "%s/%s/%s/%.0fx%.0f" % [
        str(active), str(host.get("focused_target")),
        str(_can_open()), s.x, s.y]
    if snapshot != _visible_signature:
        _sync_ui()


func _sync_ui() -> void:
    if host == null or _buttons.is_empty():
        return
    size = get_viewport_rect().size
    _visible_signature = "%s/%s/%s/%.0fx%.0f" % [
        str(active), str(host.get("focused_target")),
        str(_can_open()), size.x, size.y]
    for id_value in _buttons.keys():
        var id: String = str(id_value)
        var panel: Panel = _buttons[id]
        var show_panel: bool = (
            id != "open" and active)
        # The standalone 'アングル正規配置' entry is always owned by the
        # working NEXUS HUD; the editing buttons remain in this overlay.
        panel.visible = show_panel
        if show_panel:
            var rect: Rect2 = _button_rect(id)
            panel.position = rect.position
            panel.size = rect.size

    _status.visible = active
    _help.visible = active
    if active:
        _status.position = Vector2(14.0, 85.0)
        _status.size = Vector2(maxf(80.0, size.x - 28.0), 44.0)
        _status.text = "%s / 距離 %.2fm / 画角 %.1f° / 回転 %.0f°" % [
            target_id, distance, reference_fov, roll_deg]
        _help.position = Vector2(14.0, size.y - 253.0)
        _help.size = Vector2(maxf(80.0, size.x - 28.0), 36.0)
        _help.text = "ドラッグ: 旋回・俯角 / ボタン: 注視・距離・画角・カメラ回転"


func _button_rect(id: String) -> Rect2:
    var w: float = size.x
    var h: float = size.y
    match id:
        "open":
            if host != null:
                var entry_button: Control = host.get("angle_entry_button") as Control
                if entry_button != null:
                    return Rect2(entry_button.position, entry_button.size)
            return Rect2(Vector2(maxf(16.0, w - 228.0), 112.0),
                Vector2(208.0, 54.0))
        "exit":
            return Rect2(Vector2(15.0, 18.0), Vector2(116.0, 48.0))
        "copy":
            return Rect2(Vector2(maxf(150.0, w - 173.0), 18.0),
                Vector2(158.0, 48.0))
    var cols := ["zoom_in", "zoom_out", "look_left", "look_right",
        "look_up", "look_down", "fov_minus", "fov_plus",
        "roll_left", "roll_right"]
    var index: int = cols.find(id)
    if index < 0:
        return Rect2()
    var column: int = index % 4
    var row: int = floori(float(index) / 4.0)
    var span: float = maxf(76.0, (w - 44.0) / 4.0 - 8.0)
    var at_x: float = 14.0 + float(column) * (span + 9.0)
    # Three rows; reserve the lowest row for optical-axis camera rotation.
    var at_y: float = h - 205.0 + float(row) * 57.0
    return Rect2(Vector2(at_x, at_y), Vector2(span, 51.0))


func route_input(event: InputEvent) -> bool:
    if not active:
        var point: Variant = _press_point(event)
        if point != null and _button_rect("open").has_point(point):
            return open_mode()
        return false
    # Every ordinary pointer/navigation input is blocked during camera edit.
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo and
            event.keycode in [KEY_BACK, KEY_ESCAPE]):
        close_mode()
        return true
    if event is InputEventScreenTouch:
        if event.pressed:
            _press(event.position, event.index, false)
        elif event.index == pointer_id:
            pointer_id = -999
            PlacementStore.flush()
        return true
    if event is InputEventScreenDrag:
        if event.index == pointer_id:
            _drag(event.position)
        return true
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _press(event.position, -100, true)
            else:
                pointer_mouse = false
                pointer_id = -999
                PlacementStore.flush()
        return true
    if event is InputEventMouseMotion:
        if pointer_mouse and pointer_id == -100:
            _drag(event.position)
        return true
    return true


func _press_point(event: InputEvent) -> Variant:
    if event is InputEventScreenTouch and event.pressed:
        return event.position
    if event is InputEventMouseButton and event.pressed and (
            event.button_index == MOUSE_BUTTON_LEFT):
        return event.position
    return null


# Shared by Button.pressed and the viewport's raw input fallback.
func open_mode() -> bool:
    if active:
        return true
    if not initialized or not _can_open():
        return false
    _open_mode()
    return active


func _open_mode() -> void:
    target_id = str(host.get("focused_target"))
    if not TARGETS.has(target_id):
        return
    var focus: Dictionary = host.focus_views[target_id]
    look_at_point = focus["look"]
    reference_fov = float(focus["fov"])
    var camera: Camera3D = host.get("cam") as Camera3D
    var offset: Vector3 = camera.position - look_at_point
    distance = maxf(1.5, offset.length())
    azimuth = atan2(offset.x, offset.z)
    elevation = asin(clampf(offset.y / distance, -0.999, 0.999))
    roll_deg = float(focus.get("roll_deg", 0.0))
    active = true
    pointer_id = -999
    pointer_mouse = false
    _sync_ui()


func _press(at: Vector2, id: int, is_mouse: bool) -> void:
    pointer_id = -999
    pointer_mouse = false
    if _button_rect("exit").has_point(at):
        close_mode()
        return
    if _button_rect("copy").has_point(at):
        _copy_pose()
        return
    var options := ["zoom_in", "zoom_out", "look_left", "look_right",
        "look_up", "look_down", "fov_minus", "fov_plus",
        "roll_left", "roll_right"]
    for option in options:
        if _button_rect(option).has_point(at):
            _adjust(option)
            return
    pointer_id = id
    pointer_mouse = is_mouse
    last_pointer = at


func _drag(at: Vector2) -> void:
    var delta: Vector2 = at - last_pointer
    last_pointer = at
    azimuth = wrapf(azimuth - delta.x * ORBIT_RATE, -PI, PI)
    elevation = clampf(elevation + delta.y * ORBIT_RATE,
        deg_to_rad(-55.0), deg_to_rad(79.0))
    _apply_pose()


func _adjust(option: String) -> void:
    match option:
        "zoom_in":
            distance = maxf(1.50, distance - 0.38)
        "zoom_out":
            distance = minf(37.0, distance + 0.38)
        "look_up":
            look_at_point.y = minf(9.0, look_at_point.y + 0.15)
        "look_down":
            look_at_point.y = maxf(-0.5, look_at_point.y - 0.15)
        "look_left", "look_right":
            var side: float = -1.0 if option == "look_left" else 1.0
            var lateral: Vector3 = Vector3(cos(azimuth), 0.0,
                -sin(azimuth)) * (0.16 * side)
            look_at_point += lateral
        "fov_minus":
            reference_fov = maxf(30.0, reference_fov - 2.0)
        "fov_plus":
            reference_fov = minf(100.0, reference_fov + 2.0)
        "roll_left":
            roll_deg = wrapf(roll_deg - ROLL_STEP_DEG, -180.0, 180.0)
        "roll_right":
            roll_deg = wrapf(roll_deg + ROLL_STEP_DEG, -180.0, 180.0)
    _apply_pose()


func _apply_pose() -> void:
    var planar: float = cos(elevation)
    var offset := Vector3(sin(azimuth) * planar, sin(elevation),
        cos(azimuth) * planar) * distance
    var eye: Vector3 = look_at_point + offset
    var camera: Camera3D = host.get("cam") as Camera3D
    if camera == null:
        return
    # Rotate the camera around its own forward axis without moving the eye
    # or look-at target. The same roll is used when NEXUS revisits this view.
    var camera_basis: Basis = Basis.looking_at(
        look_at_point - eye, Vector3.UP)
    camera_basis = camera_basis * Basis(
        Vector3.FORWARD, deg_to_rad(roll_deg))
    camera.transform = Transform3D(camera_basis, eye)
    camera.fov = DisplayProfile.vertical_fov(
        reference_fov, get_viewport_rect().size)
    var focus: Dictionary = host.focus_views[target_id]
    focus["eye"] = eye
    focus["look"] = look_at_point
    focus["fov"] = reference_fov
    focus["roll_deg"] = roll_deg
    host.focus_views[target_id] = focus
    # Camera editing must never initialize the separate model-placement editor.
    # Doing so on the first drag can block Android input while MultiMesh
    # bindings / saved model poses are being restored.
    if is_instance_valid(host.placement_editor) and (
            host.placement_editor.has_method("record_camera_pose")
            and bool(host.placement_editor.get("initialized"))):
        host.placement_editor.call("record_camera_pose",
            target_id, eye, look_at_point, reference_fov, roll_deg)
    else:
        # Preserve original-model-relative camera saves even when the model
        # editor has not yet initialized. This uses only lightweight data.
        var relative_eye: Vector3 = eye
        var relative_look: Vector3 = look_at_point
        var space_id: String = "global"
        if target_id != "DEPLOYMENT":
            space_id = "original_model_frame"
            var original_spec: Dictionary = host.canonical_placement_specs.get(
                target_id, {})
            if not original_spec.is_empty():
                var source_pose := Transform3D(
                    Basis(Vector3.UP, float(original_spec["yaw"])),
                    original_spec["position"])
                var current_pose: Transform3D = source_pose
                var stored: Dictionary = PlacementStore.read(
                    "nexus/model/" + target_id)
                if stored.has("position") and stored.has("yaw_rad"):
                    current_pose = Transform3D(
                        Basis(Vector3.UP, float(stored["yaw_rad"])),
                        PlacementStore.vec(stored["position"]))
                var to_original: Transform3D = (
                    current_pose * source_pose.affine_inverse()).affine_inverse()
                relative_eye = to_original * eye
                relative_look = to_original * look_at_point
        PlacementStore.stage("nexus/camera/" + target_id, {
            "scene": SCENE_ID, "model_id": target_id,
            "space": space_id,
            "eye": PlacementStore.array3(relative_eye),
            "look": PlacementStore.array3(relative_look),
            "fov": reference_fov, "roll_deg": roll_deg})
    if pointer_id == -999:
        PlacementStore.flush()
    host.call("_update_projected_silhouettes")
    var ink: Control = host.get("outline") as Control
    if ink != null:
        ink.queue_redraw()
    _sync_ui()


func _copy_pose() -> void:
    if target_id.is_empty():
        return
    var focus: Dictionary = host.focus_views[target_id]
    var eye: Vector3 = focus["eye"]
    var look: Vector3 = focus["look"]
    var text_content := "NEXUS_CAMERA_CANONICAL_PLACEMENT\n"
    text_content += "scene=%s\nmode=focused_console\n" % SCENE_ID
    text_content += "model_id=%s\nspace=global\n" % target_id
    text_content += "status=preview_not_committed\n"
    text_content += "eye=(%.4f, %.4f, %.4f)\n" % [
        eye.x, eye.y, eye.z]
    text_content += "look=(%.4f, %.4f, %.4f)\n" % [
        look.x, look.y, look.z]
    text_content += "reference_vertical_fov_deg=%.3f\n" % reference_fov
    text_content += "camera_roll_deg=%.3f\n" % roll_deg
    var camera: Camera3D = host.get("cam") as Camera3D
    text_content += "device_vertical_fov_deg=%.3f\n" % camera.fov
    var viewport_size: Vector2 = get_viewport_rect().size
    text_content += "viewport=(%.0f, %.0f)\n" % [
        viewport_size.x, viewport_size.y]
    DisplayServer.clipboard_set(text_content)
    _help.text = "コピー完了。ChatGPTへ貼り付けると正式なカメラ位置に確定できます。"


func close_mode() -> void:
    if not active:
        return
    PlacementStore.flush()
    active = false
    pointer_id = -999
    pointer_mouse = false
    target_id = ""
    # The updated focus_views values persist in the developer preview store.
    # All NEXUS touch and Back navigation are immediately restored.
    _sync_ui()

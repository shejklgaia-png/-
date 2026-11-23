extends Control
## One on-demand real SeraRig viewer per active preview. Paused when hidden.
## The identical source is used by LABO, WAREHOUSE and NEXUS; never per card.
const EquipmentPreview = preload("res://tools/equipment_intake/godot_preview.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const IrisPolygonLight = preload("res://shaders/sera_iris_polygon_light.gdshader")
const IrisPolygonLightClosed = preload("res://shaders/sera_iris_polygon_light_closed.gdshader")
const IrisFaceNormals = preload("res://scripts/sera_iris_face_normal_preview.gd")
const IrisMaterialControls = preload("res://scripts/sera_iris_material_controls.gd")
const IrisMaterialPresets = preload("res://scripts/sera_iris_material_presets.gd")
const IRIS_MATERIAL_KEYS: Array[String] = ["armor", "dark_mechanism", "lens", "emission"]
const IRIS_FLASH_SECONDS: float = 0.65
const SHADING_MODES = [0, 2, 3, 4, 5, 6, 7, 8]
const double_tap_window_msec: int = 330
signal preview_fullscreen_requested(enabled: bool)
# The live part preview starts at the same angle as the approved 19 PNGs.
const DEFAULT_YAW: float = 156.900744628906
const DEFAULT_PITCH: float = 11.8749389648438
# Reserve breathing room around single-part silhouettes in the compact
# NEXUS viewer. Fullscreen and pinch-to-zoom remain interactive.
const NEXUS_COMPACT_PREVIEW_ZOOM: float = 0.86

var render_viewport: SubViewport
var preview_scene: Node3D
var preview_host: SubViewportContainer
var ready_for_commands: bool = false
var current_blueprint: String = ""
var active_preview: bool = false
## NEXUS keeps the brighter preview backdrop but ALL part previews,
## including IRIS, use the same Bittaran RGB12 visible-ID contour compositor.
var enable_nexus_iris_id_contour: bool = false
var selected_parts: Dictionary = {}
var _request_serial: int = 0
var _pressed_mouse: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var fullscreen: bool = false
var _material_toggle: Button
var _material_panel: Panel
var _material_editor_open: bool = false
var _iris_material_values: Array[Dictionary] = [
    {"steps": 8, "threshold": 0.65}, # Light-grey armor.
    {"steps": 2, "threshold": 0.70}, # Both dark-grey mechanism tones.
    {"steps": 3, "threshold": 0.10}, # Cyan lens, unlit by default.
    {"steps": 0, "threshold": 0.00}  # Cyan when lit: emissive, no shadows.
]
var _lens_lit: bool = false
var _flash_material: int = -1
var _flash_elapsed: float = 0.0
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
    var restored: Dictionary = IrisMaterialPresets.load_last()
    if not restored.is_empty():
        _set_iris_material_payload(restored, false)
    set_process(false)
    resized.connect(_layout_iris_controls)
    # With SubViewportContainer.stretch=true, Godot controls its size.
    # Do not fight it by assigning SubViewport.size after parenting.

func _create_iris_controls() -> void:
    _fullscreen_close = Button.new()
    _fullscreen_close.name = "IrisFullscreenClose"
    _fullscreen_close.text = "縮小"
    _fullscreen_close.focus_mode = Control.FOCUS_NONE
    _fullscreen_close.custom_minimum_size = Vector2(76, 48)
    _fullscreen_close.pressed.connect(_request_close_fullscreen)
    _fullscreen_close.visible = false
    add_child(_fullscreen_close)
    _material_toggle = Button.new()
    _material_toggle.name = "IrisMaterialAdjustmentToggle"
    _material_toggle.text = "材質調整"
    _material_toggle.focus_mode = Control.FOCUS_NONE
    _material_toggle.custom_minimum_size = Vector2(112, 48)
    _material_toggle.add_theme_font_size_override("font_size", 17)
    _material_toggle.pressed.connect(_toggle_material_editor)
    _material_toggle.visible = false
    add_child(_material_toggle)
    _material_panel = IrisMaterialControls.new()
    _material_panel.visible = false
    add_child(_material_panel)
    _material_panel.connect("material_selected", _flash_iris_material)
    _material_panel.connect("value_changed", _adjust_iris_material)
    _material_panel.connect("emission_toggled", _toggle_iris_emission)
    _material_panel.connect("copy_requested", _copy_iris_material_settings)
    _material_panel.connect("preset_save_requested", _save_iris_preset)
    _material_panel.connect("preset_load_requested", _load_iris_preset)
    _material_panel.connect("import_requested", _import_iris_material_settings)
    _material_panel.connect("reset_requested", _reset_iris_material_settings)
    _sync_iris_editor_values()
    _layout_iris_controls()


func _layout_iris_controls() -> void:
    if _fullscreen_close != null:
        _fullscreen_close.position = Vector2(12.0, 12.0)
        _fullscreen_close.size = Vector2(76.0, 48.0)
    if _material_toggle != null:
        _material_toggle.position = Vector2(100.0, 12.0)
        _material_toggle.size = Vector2(112.0, 48.0)
    if _material_panel != null:
        _material_panel.size = Vector2(maxf(1.0, minf(620.0, size.x - 24.0)),
            minf(390.0, maxf(280.0, size.y - 95.0)))
        _material_panel.position = Vector2(12.0,
            maxf(80.0, size.y - _material_panel.size.y - 14.0))


func _is_iris_preview() -> bool:
    return enable_nexus_iris_id_contour and current_blueprint == "H02"


func set_fullscreen_state(enabled: bool) -> void:
    fullscreen = enabled
    _last_tap_time = 0
    _touch_starts.clear()
    _ui_mode_touches.clear()
    if is_instance_valid(_fullscreen_close):
        _fullscreen_close.visible = enabled
    if not enabled:
        _material_editor_open = false
        _clear_iris_flash()
    if is_instance_valid(_material_toggle):
        _material_toggle.visible = enabled and _is_iris_preview()
    if is_instance_valid(_material_panel):
        _material_panel.visible = enabled and _material_editor_open and _is_iris_preview()
    _layout_iris_controls()


func dismiss_iris_material_keyboard() -> bool:
    return fullscreen and is_instance_valid(_material_panel) and bool(
        _material_panel.call("dismiss_keyboard"))

func _request_close_fullscreen() -> void:
    if fullscreen:
        preview_fullscreen_requested.emit(false)


func _toggle_material_editor() -> void:
    if not fullscreen or not _is_iris_preview():
        return
    _material_editor_open = not _material_editor_open
    _material_panel.visible = _material_editor_open
    if _material_editor_open:
        _material_panel.call("show_material_editor")
        _refresh_iris_preset_rows()
    _sync_iris_editor_values()


func _sync_iris_editor_values() -> void:
    if is_instance_valid(_material_panel):
        _material_panel.call("set_values", _iris_material_values, _lens_lit)
        _material_panel.call("set_copied", false)


func _adjust_iris_material(material_id: int, field: String, direction: int) -> void:
    if not fullscreen or not _is_iris_preview() or material_id < 0 or material_id >= 3:
        return
    var values: Dictionary = _iris_material_values[material_id]
    if field == "steps":
        var current: int = SHADING_MODES.find(int(values["steps"]))
        values["steps"] = SHADING_MODES[clampi(current + direction, 0,
            SHADING_MODES.size() - 1)]
    elif field == "threshold":
        values["threshold"] = clampf(roundf(
            (float(values["threshold"]) + float(direction) * 0.05) * 100.0
            ) / 100.0, 0.0, 1.0)
    else:
        return
    _iris_material_values[material_id] = values
    _sync_iris_editor_values()
    _apply_iris_shading()
    _persist_iris_material_settings()


func _toggle_iris_emission() -> void:
    if not fullscreen or not _is_iris_preview():
        return
    _lens_lit = not _lens_lit
    _sync_iris_editor_values()
    _apply_iris_shading()
    _persist_iris_material_settings()


func _current_iris_material_payload() -> Dictionary:
    return IrisMaterialPresets.make_payload(_iris_material_values, _lens_lit)

func _persist_iris_material_settings() -> void:
    if not IrisMaterialPresets.save_last(_current_iris_material_payload()):
        push_warning("NEXUS IRIS: could not persist material settings")

func _set_iris_material_payload(payload: Dictionary, persist: bool = true) -> bool:
    var checked: Dictionary = IrisMaterialPresets.normalize(payload)
    if checked.is_empty():
        return false
    var material_data: Dictionary = checked["materials"]
    for index in range(IRIS_MATERIAL_KEYS.size()):
        _iris_material_values[index] = material_data[IRIS_MATERIAL_KEYS[index]].duplicate()
    _lens_lit = bool(checked["lens_lit"])
    _sync_iris_editor_values()
    _apply_iris_shading()
    if persist:
        _persist_iris_material_settings()
    return true

func _refresh_iris_preset_rows() -> void:
    if is_instance_valid(_material_panel):
        _material_panel.call("set_preset_rows", IrisMaterialPresets.list_presets())

func _save_iris_preset(slot: int, preset_name: String) -> void:
    if not fullscreen or not _is_iris_preview():
        return
    var success: bool = IrisMaterialPresets.save_preset(
        slot, preset_name, _current_iris_material_payload())
    _refresh_iris_preset_rows()
    _material_panel.call("set_feedback",
        "%d番に保存しました" % slot if success else "保存に失敗しました")

func _load_iris_preset(slot: int) -> void:
    if not fullscreen or not _is_iris_preview():
        return
    var saved: Dictionary = IrisMaterialPresets.read_preset(slot)
    if saved.is_empty():
        _material_panel.call("set_feedback", "%d番は未保存です" % slot)
        return
    var success: bool = _set_iris_material_payload(saved["payload"])
    _material_panel.call("set_feedback",
        "%d番を読み込みました" % slot if success else "読込に失敗しました")

func _reset_iris_material_settings() -> void:
    if not fullscreen or not _is_iris_preview():
        return
    if _set_iris_material_payload(IrisMaterialPresets.default_payload()):
        _material_panel.call("set_feedback", "標準設定を適用しました")

func _import_iris_material_settings() -> void:
    if not fullscreen or not _is_iris_preview():
        return
    var payload: Dictionary = IrisMaterialPresets.parse_text(
        DisplayServer.clipboard_get())
    if payload.is_empty():
        _material_panel.call("set_feedback", "コピーした設定が無効です")
        return
    if _set_iris_material_payload(payload):
        _material_panel.call("set_feedback", "貼り付けた設定を復元しました")

func _copy_iris_material_settings() -> void:
    if not fullscreen or not _is_iris_preview():
        return
    DisplayServer.clipboard_set(JSON.stringify(
        _current_iris_material_payload(), "\t"))
    _material_panel.call("set_copied", true)

func _flash_iris_material(material_id: int) -> void:
    if not fullscreen or not _is_iris_preview() or material_id < 0 or material_id >= 4:
        return
    _flash_material = material_id
    _flash_elapsed = 0.0
    for material in _light_materials.values():
        var shader_material: ShaderMaterial = material as ShaderMaterial
        shader_material.set_shader_parameter("flash_material", material_id)
        shader_material.set_shader_parameter("flash_power", 0.0)
    set_process(true)


func _clear_iris_flash() -> void:
    _flash_material = -1
    _flash_elapsed = 0.0
    for material in _light_materials.values():
        var shader_material: ShaderMaterial = material as ShaderMaterial
        if is_instance_valid(shader_material):
            shader_material.set_shader_parameter("flash_material", -1)
            shader_material.set_shader_parameter("flash_power", 0.0)
    set_process(false)


func _process(delta: float) -> void:
    if _flash_material < 0 or not active_preview:
        _clear_iris_flash()
        return
    _flash_elapsed += delta
    var fraction: float = minf(_flash_elapsed / IRIS_FLASH_SECONDS, 1.0)
    # Exactly one blue-white pulse; no periodic blinking.
    var pulse: float = 0.92 * sin(fraction * PI)
    for material in _light_materials.values():
        var shader_material: ShaderMaterial = material as ShaderMaterial
        shader_material.set_shader_parameter("flash_material", _flash_material)
        shader_material.set_shader_parameter("flash_power", pulse)
    if fraction >= 1.0:
        _clear_iris_flash()


func _restore_original_materials() -> void:
    for item in _original_materials.values():
        var source: MeshInstance3D = item.get("mesh") as MeshInstance3D
        if is_instance_valid(source):
            # Only this NEXUS preview used the rebuilt mesh. Restore the exact
            # shared resource so other previews and gameplay are untouched.
            source.mesh = item.get("original_mesh") as Mesh
            source.material_override = item.get("original_material_override") as Material
    _original_materials.clear()
    _light_materials.clear()
    _clear_iris_flash()


func _apply_iris_shading() -> void:
    if not active_preview or not ready_for_commands or not _is_iris_preview() or (
            not is_instance_valid(preview_scene)):
        _restore_original_materials()
        return
    if not is_instance_valid(_white_texture):
        var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
        white.fill(Color.WHITE)
        _white_texture = ImageTexture.create_from_image(white)
    var pieces: Array = preview_scene.call("_mesh_in_slot", "head", "D")
    var authored_faces: Array = IrisFaceNormals.authored_elements()
    if authored_faces.size() != pieces.size():
        push_warning("NEXUS IRIS: authored face count does not match active meshes")
        _restore_original_materials()
        return
    for index in range(pieces.size()):
        var source: MeshInstance3D = pieces[index] as MeshInstance3D
        if not is_instance_valid(source) or source.mesh == null:
            continue
        var key: int = source.get_instance_id()
        if not _original_materials.has(key):
            # The imported rig uses one flat normal PER TRIANGLE. A shader
            # switch to NORMAL alone would leave diagonal seams unchanged.
            # Rebuild only this preview's mesh normals by authored BB face,
            # with the exact same triangles, positions and UV coordinates.
            var authored_element: Dictionary = authored_faces[index]
            var preview_mesh: ArrayMesh = IrisFaceNormals.make_face_uniform_mesh(
                source.mesh, authored_element)
            if preview_mesh == null:
                push_warning("NEXUS IRIS: unsupported face topology at piece %d" % index)
                continue
            _original_materials[key] = {
                "mesh": source,
                "original_mesh": source.mesh,
                "original_material_override": source.material_override
            }
            source.mesh = preview_mesh
        var original: Material = _original_materials[key]["original_material_override"] as Material
        if original == null and source.mesh.get_surface_count() > 0:
            original = source.get_active_material(0)
        var texture: Texture2D = _white_texture
        var tint: Color = Color.WHITE
        if original is StandardMaterial3D:
            var standard: StandardMaterial3D = original as StandardMaterial3D
            if standard.albedo_texture != null:
                texture = standard.albedo_texture
            tint = standard.albedo_color
        elif original is ShaderMaterial:
            # Every EquipmentPreview now has shared material shading. The
            # fullscreen HEAD D editor temporarily overrides that material
            # but must use its ORIGINAL UV texture and tint, not a white fill.
            var shared: ShaderMaterial = original as ShaderMaterial
            var original_texture: Variant = shared.get_shader_parameter("source_texture")
            var original_tint: Variant = shared.get_shader_parameter("source_tint")
            if original_texture is Texture2D:
                texture = original_texture
            if original_tint is Color:
                tint = original_tint
        var light_material: ShaderMaterial = _light_materials.get(key) as ShaderMaterial
        if not is_instance_valid(light_material):
            light_material = ShaderMaterial.new()
            light_material.shader = IrisPolygonLightClosed if bool(source.get_meta(
                "sera_single_sided", false)) else IrisPolygonLight
            light_material.set_shader_parameter("source_texture", texture)
            light_material.set_shader_parameter("source_tint", tint)
            light_material.set_shader_parameter("panel_bias",
                float(index % 3 - 1) * 0.035)
            _light_materials[key] = light_material
        light_material.set_shader_parameter("armor_levels",
            int(_iris_material_values[0]["steps"]))
        light_material.set_shader_parameter("armor_threshold",
            float(_iris_material_values[0]["threshold"]))
        light_material.set_shader_parameter("dark_levels",
            int(_iris_material_values[1]["steps"]))
        light_material.set_shader_parameter("dark_threshold",
            float(_iris_material_values[1]["threshold"]))
        light_material.set_shader_parameter("lens_levels",
            int(_iris_material_values[2]["steps"]))
        light_material.set_shader_parameter("lens_threshold",
            float(_iris_material_values[2]["threshold"]))
        light_material.set_shader_parameter("lens_emissive", _lens_lit)
        light_material.set_shader_parameter("flash_material", _flash_material)
        source.material_override = light_material


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
    preview_scene.set_meta("sera_graphics_outline_category", "part")
    # Opt-in applies ONLY to the NEXUS single-part and full-screen viewer.
    preview_scene.set("nexus_brighter_backdrop", enable_nexus_iris_id_contour)
    render_viewport.add_child(preview_scene)
    # SubViewportContainer stretches to the available square without
    # allocating additional render targets when a modal resizes.

func _set_shared_outline_enabled(enabled: bool) -> void:
    if not is_instance_valid(preview_scene):
        return
    var model: Node3D = preview_scene.get("rig") as Node3D
    if not is_instance_valid(model):
        return
    var edges: Node3D = model.get_node_or_null("ViewEdges") as Node3D
    if edges != null:
        edges.call("set_contour_enabled", enabled)


func show_part(blueprint: String, selections: Dictionary = {}) -> void:
    var spec: Dictionary = Catalog.spec(blueprint)
    if spec.is_empty():
        return
    _restore_original_materials()
    _touch_starts.clear()
    _ui_mode_touches.clear()
    _last_tap_time = 0
    current_blueprint = blueprint
    if is_instance_valid(_material_toggle):
        _material_toggle.visible = fullscreen and _is_iris_preview()
    if is_instance_valid(_material_panel):
        _material_panel.visible = fullscreen and _material_editor_open and _is_iris_preview()
    _set_shared_outline_enabled(GraphicsSettings.get_enabled("part_outline"))
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
            "zoom": NEXUS_COMPACT_PREVIEW_ZOOM, "outlinePx": 3.0},
        "seq": request
    })
    # HEAD D/IRIS no longer uses a six-ID custom Canvas mask. Exactly the
    # same RGB12 IDs, depth resolve, contact owner and 1/2/2 width preset
    # as every other part are displayed by SeraSceneIDOutlines.
    _set_shared_outline_enabled(GraphicsSettings.get_enabled("part_outline"))
    _apply_iris_shading()

func set_preview_active(enabled: bool) -> void:
    active_preview = enabled
    if render_viewport != null:
        render_viewport.render_target_update_mode = (
            SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED)
    if not enabled:
        _restore_original_materials()
        _touch_starts.clear()
        _ui_mode_touches.clear()
        _last_tap_time = 0
        _request_serial += 1
        _pressed_mouse = false
        if is_instance_valid(preview_scene):
            preview_scene.call("_on_preview_touch", 0, false, Vector2.ZERO)

func _material_control_at(point: Vector2) -> Control:
    if not fullscreen or not _is_iris_preview():
        return null
    var global_point: Vector2 = get_global_rect().position + point
    if is_instance_valid(_material_toggle) and _material_toggle.visible and (
            _material_toggle.get_global_rect().has_point(global_point)):
        return _material_toggle
    if is_instance_valid(_material_panel) and _material_panel.visible:
        return _material_panel.call("control_at", global_point) as Control
    return null


func _point_over_material_panel(point: Vector2) -> bool:
    return is_instance_valid(_material_panel) and _material_panel.visible and (
        _material_panel.get_global_rect().has_point(get_global_rect().position + point))


func _hit_fullscreen_close(point: Vector2) -> bool:
    return fullscreen and _fullscreen_close != null and (
        _fullscreen_close.get_global_rect().has_point(
            get_global_rect().position + point))


func _track_preview_tap(point: Vector2, started: Dictionary) -> void:
    var now: int = Time.get_ticks_msec()
    if now - int(started.get("time", 0)) > 300 or (
            bool(started.get("moved", false))) or (
            point.distance_to(started.get("point", point)) > 18.0):
        _last_tap_time = 0
        return
    if _last_tap_time > 0 and now - _last_tap_time <= double_tap_window_msec and (
            point.distance_to(_last_tap_position) <= 30.0):
        _last_tap_time = 0
        preview_fullscreen_requested.emit(not fullscreen)
    else:
        _last_tap_time = now
        _last_tap_position = point


func feed_touch(index: int, pressed: bool, point: Vector2) -> void:
    if not ready_for_commands or not active_preview or not is_instance_valid(preview_scene):
        return
    if pressed:
        var material_control: Control = _material_control_at(point)
        if material_control != null:
            _ui_mode_touches[index] = material_control
            _last_tap_time = 0
            return
        if _point_over_material_panel(point):
            _ui_mode_touches[index] = -3
            _last_tap_time = 0
            return
        if _hit_fullscreen_close(point):
            _ui_mode_touches[index] = -2
            _last_tap_time = 0
            return
        _touch_starts[index] = {
            "point": point, "time": Time.get_ticks_msec(), "moved": false}
        if _touch_starts.size() > 1:
            for key in _touch_starts.keys():
                _touch_starts[key]["moved"] = true
        preview_scene.call("_on_preview_touch", index, true, point)
        return
    if _ui_mode_touches.has(index):
        var captured: Variant = _ui_mode_touches[index]
        _ui_mode_touches.erase(index)
        if captured is Button:
            var captured_button: Button = captured as Button
            if is_instance_valid(captured_button) and captured_button.is_visible_in_tree() and (
                    captured_button.get_global_rect().has_point(
                    get_global_rect().position + point)):
                captured_button.pressed.emit()
        elif captured is LineEdit:
            var text_editor: LineEdit = captured as LineEdit
            if is_instance_valid(text_editor) and text_editor.is_visible_in_tree() and (
                    text_editor.get_global_rect().has_point(
                    get_global_rect().position + point)):
                text_editor.grab_focus()
                if OS.has_feature("mobile"):
                    DisplayServer.virtual_keyboard_show(
                        text_editor.text, text_editor.get_global_rect())
        elif int(captured) == -2:
            if _hit_fullscreen_close(point):
                _request_close_fullscreen()
        return
    var started: Dictionary = _touch_starts.get(index, {})
    _touch_starts.erase(index)
    preview_scene.call("_on_preview_touch", index, false, point)
    if not started.is_empty():
        _track_preview_tap(point, started)


func feed_drag(index: int, point: Vector2) -> void:
    if _ui_mode_touches.has(index):
        return
    if _touch_starts.has(index):
        var state: Dictionary = _touch_starts[index]
        if point.distance_to(state.get("point", point)) > 18.0:
            state["moved"] = true
            _touch_starts[index] = state
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

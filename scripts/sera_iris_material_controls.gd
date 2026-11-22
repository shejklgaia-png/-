extends Panel
## Fullscreen H02 IRIS material controls. The parent preview routes Android
## touch releases to these buttons; no second viewport or mesh is created.
signal material_selected(material_id: int)
signal value_changed(material_id: int, field: String, direction: int)
signal emission_toggled
signal copy_requested
signal preset_save_requested(slot: int, preset_name: String)
signal preset_load_requested(slot: int)
signal reset_requested
signal import_requested

const MATERIAL_NAMES: Array[String] = ["装甲", "暗色機構", "レンズ", "発光"]
var _buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _light_button: Button
var _copy_status: Label
var _editor_root: VBoxContainer
var _preset_root: VBoxContainer
var _preset_names: Array[LineEdit] = []
var _preset_status: Label


func _ready() -> void:
    name = "IrisMaterialAdjustmentPanel"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065, 0.15, 0.20, 0.94)
    style.border_color = Color("#55798a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    add_theme_stylebox_override("panel", style)

    _editor_root = VBoxContainer.new()
    var root: VBoxContainer = _editor_root
    root.name = "IrisMaterialAdjustmentRows"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 10.0
    root.offset_right = -10.0
    root.offset_top = 7.0
    root.offset_bottom = -7.0
    root.add_theme_constant_override("separation", 5)
    add_child(root)

    var heading := Label.new()
    heading.text = "材質                  陰影段階            しきい値"
    heading.add_theme_font_size_override("font_size", 17)
    heading.add_theme_color_override("font_color", Color("#cce6ee"))
    heading.custom_minimum_size.y = 23.0
    root.add_child(heading)
    for material_id in range(MATERIAL_NAMES.size()):
        var row := HBoxContainer.new()
        row.name = "IrisMaterialRow_%d" % material_id
        row.custom_minimum_size.y = 43.0
        row.add_theme_constant_override("separation", 4)
        root.add_child(row)

        var name_button: Button = _new_button(MATERIAL_NAMES[material_id], 94)
        row.add_child(name_button)
        name_button.pressed.connect(_select_material.bind(material_id))

        var minus_steps: Button = _new_button("−", 32)
        row.add_child(minus_steps)
        minus_steps.pressed.connect(_change.bind(material_id, "steps", -1))
        var step_label := Label.new()
        step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        step_label.custom_minimum_size.x = 40.0
        step_label.add_theme_font_size_override("font_size", 16)
        row.add_child(step_label)
        var plus_steps: Button = _new_button("+", 32)
        row.add_child(plus_steps)
        plus_steps.pressed.connect(_change.bind(material_id, "steps", 1))

        var gap := Control.new()
        gap.custom_minimum_size.x = 3.0
        gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(gap)

        var minus_threshold: Button = _new_button("−", 32)
        row.add_child(minus_threshold)
        minus_threshold.pressed.connect(_change.bind(material_id, "threshold", -1))
        var threshold_label := Label.new()
        threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        threshold_label.custom_minimum_size.x = 46.0
        threshold_label.add_theme_font_size_override("font_size", 16)
        row.add_child(threshold_label)
        var plus_threshold: Button = _new_button("+", 32)
        row.add_child(plus_threshold)
        plus_threshold.pressed.connect(_change.bind(material_id, "threshold", 1))
        _rows.append({
            "steps": step_label, "threshold": threshold_label,
            "controls": [minus_steps, plus_steps, minus_threshold, plus_threshold]
        })
    var footer := HBoxContainer.new()
    footer.name = "IrisMaterialActions"
    footer.custom_minimum_size.y = 47.0
    footer.add_theme_constant_override("separation", 9)
    root.add_child(footer)
    _light_button = _new_button("水色 点灯: OFF", 125)
    _light_button.pressed.connect(_on_emission_pressed)
    footer.add_child(_light_button)
    var copy_button: Button = _new_button("全材質をコピー", 137)
    copy_button.pressed.connect(_on_copy_pressed)
    footer.add_child(copy_button)
    _copy_status = Label.new()
    _copy_status.text = ""
    _copy_status.add_theme_font_size_override("font_size", 16)
    _copy_status.add_theme_color_override("font_color", Color("#a9eafa"))
    footer.add_child(_copy_status)

    var extra := HBoxContainer.new()
    extra.name = "IrisMaterialPersistenceActions"
    extra.custom_minimum_size.y = 43.0
    extra.add_theme_constant_override("separation", 6)
    root.add_child(extra)
    var presets_button := _new_button("セーブ／ロード", 124)
    presets_button.pressed.connect(_open_presets)
    extra.add_child(presets_button)
    var import_button := _new_button("貼付け復元", 100)
    import_button.pressed.connect(_on_import_pressed)
    extra.add_child(import_button)
    var reset_button := _new_button("標準に戻す", 100)
    reset_button.pressed.connect(_on_reset_pressed)
    extra.add_child(reset_button)

    _preset_root = VBoxContainer.new()
    _preset_root.name = "IrisMaterialPresetRows"
    _preset_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _preset_root.offset_left = 10.0
    _preset_root.offset_right = -10.0
    _preset_root.offset_top = 7.0
    _preset_root.offset_bottom = -7.0
    _preset_root.add_theme_constant_override("separation", 5)
    _preset_root.visible = false
    add_child(_preset_root)
    var heading_row := HBoxContainer.new()
    heading_row.custom_minimum_size.y = 44.0
    _preset_root.add_child(heading_row)
    var back_button := _new_button("← 材質調整", 142)
    back_button.pressed.connect(_close_presets)
    heading_row.add_child(back_button)
    var title := Label.new()
    title.text = "  材質プリセット（端末共通・5枠）"
    title.add_theme_color_override("font_color", Color("#cce6ee"))
    title.add_theme_font_size_override("font_size", 16)
    heading_row.add_child(title)

    var scrolling := ScrollContainer.new()
    scrolling.name = "IrisMaterialPresetScroll"
    scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _preset_root.add_child(scrolling)
    var slot_rows := VBoxContainer.new()
    slot_rows.name = "IrisPresetSlotRows"
    slot_rows.add_theme_constant_override("separation", 5)
    scrolling.add_child(slot_rows)
    for slot in range(1, 6):
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 43.0
        row.add_theme_constant_override("separation", 5)
        slot_rows.add_child(row)
        var number := Label.new()
        number.text = "%02d" % slot
        number.custom_minimum_size.x = 28.0
        row.add_child(number)
        var editor := LineEdit.new()
        editor.name = "IrisPresetName_%d" % slot
        editor.placeholder_text = "プリセット %d" % slot
        editor.max_length = 24
        editor.custom_minimum_size = Vector2(106.0, 40.0)
        editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(editor)
        _preset_names.append(editor)
        var save_button := _new_button("保存", 68)
        save_button.pressed.connect(_request_save.bind(slot))
        row.add_child(save_button)
        var load_button := _new_button("読込", 68)
        load_button.pressed.connect(_request_load.bind(slot))
        row.add_child(load_button)
    _preset_status = Label.new()
    _preset_status.text = "名前を編集して保存できます"
    _preset_status.add_theme_font_size_override("font_size", 15)
    _preset_status.add_theme_color_override("font_color", Color("#a9eafa"))
    _preset_root.add_child(_preset_status)


func _on_emission_pressed() -> void:
    emission_toggled.emit()


func _on_copy_pressed() -> void:
    copy_requested.emit()

func _on_import_pressed() -> void:
    import_requested.emit()

func _on_reset_pressed() -> void:
    reset_requested.emit()

func _open_presets() -> void:
    _editor_root.visible = false
    _preset_root.visible = true

func _close_presets() -> void:
    _preset_root.visible = false
    _editor_root.visible = true

func show_material_editor() -> void:
    _close_presets()

func _request_save(slot: int) -> void:
    preset_save_requested.emit(slot, _preset_names[slot - 1].text)

func _request_load(slot: int) -> void:
    preset_load_requested.emit(slot)

func set_preset_rows(rows: Array) -> void:
    for i in range(mini(rows.size(), _preset_names.size())):
        var row: Dictionary = rows[i]
        if not _preset_names[i].has_focus():
            _preset_names[i].text = str(row.get("name", "プリセット %d" % (i + 1)))

func set_feedback(message: String) -> void:
    _copy_status.text = message
    _preset_status.text = message


func _new_button(caption: String, width: float) -> Button:
    var button := Button.new()
    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(width, 40)
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", Color("#e7f6fa"))
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#203b49")
    style.border_color = Color("#567d90")
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("pressed", style)
    _buttons.append(button)
    return button


func _select_material(material_id: int) -> void:
    material_selected.emit(material_id)


func _change(material_id: int, field: String, direction: int) -> void:
    value_changed.emit(material_id, field, direction)


func set_values(materials: Array, lens_lit: bool) -> void:
    for i in range(_rows.size()):
        var controls: Array = _rows[i]["controls"]
        var emission: bool = i == 3
        (_rows[i]["steps"] as Label).text = ("OFF" if int(materials[i]["steps"]) == 0
            else "%d段" % int(materials[i]["steps"]))
        (_rows[i]["threshold"] as Label).text = ("—" if emission
            else "%.2f" % float(materials[i]["threshold"]))
        for button in controls:
            (button as Button).disabled = emission
    _light_button.text = "水色 点灯: ON" if lens_lit else "水色 点灯: OFF"


func set_copied(copied: bool) -> void:
    _copy_status.text = "コピー済" if copied else ""


func control_at(global_point: Vector2) -> Control:
    if not visible or not is_visible_in_tree():
        return null
    for editor in _preset_names:
        if editor.is_visible_in_tree() and editor.get_global_rect().has_point(global_point):
            return editor
    for button in _buttons:
        if button.is_visible_in_tree() and not button.disabled and (
                button.get_global_rect().has_point(global_point)):
            return button
    return null

func button_at(global_point: Vector2) -> Button:
    return control_at(global_point) as Button

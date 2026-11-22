extends Panel
## Fullscreen H02 IRIS material controls. The parent preview routes Android
## touch releases to these buttons; no second viewport or mesh is created.
signal material_selected(material_id: int)
signal value_changed(material_id: int, field: String, direction: int)
signal emission_toggled
signal copy_requested

const MATERIAL_NAMES: Array[String] = ["装甲", "暗色機構", "レンズ", "発光"]
var _buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _light_button: Button
var _copy_status: Label


func _ready() -> void:
    name = "IrisMaterialAdjustmentPanel"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065, 0.15, 0.20, 0.94)
    style.border_color = Color("#55798a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    add_theme_stylebox_override("panel", style)

    var root := VBoxContainer.new()
    root.name = "IrisMaterialAdjustmentRows"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 10.0
    root.offset_right = -10.0
    root.offset_top = 7.0
    root.offset_bottom = -7.0
    root.add_theme_constant_override("separation", 5)
    add_child(root)

    var heading := Label.new()
    heading.text = "材質                  陰影段階                 しきい値"
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

        var name_button: Button = _new_button(MATERIAL_NAMES[material_id], 116)
        row.add_child(name_button)
        name_button.pressed.connect(_select_material.bind(material_id))

        var minus_steps: Button = _new_button("−", 36)
        row.add_child(minus_steps)
        minus_steps.pressed.connect(_change.bind(material_id, "steps", -1))
        var step_label := Label.new()
        step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        step_label.custom_minimum_size.x = 51.0
        step_label.add_theme_font_size_override("font_size", 16)
        row.add_child(step_label)
        var plus_steps: Button = _new_button("+", 36)
        row.add_child(plus_steps)
        plus_steps.pressed.connect(_change.bind(material_id, "steps", 1))

        var gap := Control.new()
        gap.custom_minimum_size.x = 12.0
        gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(gap)

        var minus_threshold: Button = _new_button("−", 36)
        row.add_child(minus_threshold)
        minus_threshold.pressed.connect(_change.bind(material_id, "threshold", -1))
        var threshold_label := Label.new()
        threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        threshold_label.custom_minimum_size.x = 59.0
        threshold_label.add_theme_font_size_override("font_size", 16)
        row.add_child(threshold_label)
        var plus_threshold: Button = _new_button("+", 36)
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
    _light_button = _new_button("水色 点灯: OFF", 153)
    _light_button.pressed.connect(func() -> void: emission_toggled.emit())
    footer.add_child(_light_button)
    var copy_button: Button = _new_button("全材質をコピー", 173)
    copy_button.pressed.connect(func() -> void: copy_requested.emit())
    footer.add_child(copy_button)
    _copy_status = Label.new()
    _copy_status.text = ""
    _copy_status.add_theme_font_size_override("font_size", 16)
    _copy_status.add_theme_color_override("font_color", Color("#a9eafa"))
    footer.add_child(_copy_status)


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


func button_at(global_point: Vector2) -> Button:
    if not visible or not is_visible_in_tree():
        return null
    for button in _buttons:
        if button.is_visible_in_tree() and not button.disabled and (
                button.get_global_rect().has_point(global_point)):
            return button
    return null

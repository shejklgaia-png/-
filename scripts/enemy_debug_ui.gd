extends PanelContainer
## v91: Isolated mobile-friendly enemy-attack debug selector.
## All input is consumed by real GUI buttons; main.gd prevents any pointer
## that starts in this panel from becoming a movement / attack gesture.

signal attack_selected(kind: int)
signal fire_requested()
signal auto_fire_changed(enabled: bool)
signal jump_test_requested()

const MODE_TEXTS = ["AIM", "LEAD", "SHOCK", "ARC"]
var _mode_buttons: Array[Button] = []
var _auto_button: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.088, 0.13, 0.93)
    style.border_color = Color(0.19, 0.37, 0.43, 0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.set_content_margin_all(6)
    add_theme_stylebox_override("panel", style)
    var layout := VBoxContainer.new()
    layout.mouse_filter = Control.MOUSE_FILTER_PASS
    layout.add_theme_constant_override("separation", 3)
    add_child(layout)
    var title := Label.new()
    title.text = "COMBAT / DEBUG"
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color("8fb3c1"))
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layout.add_child(title)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_PASS
    row.add_theme_constant_override("separation", 5)
    layout.add_child(row)
    var group := ButtonGroup.new()
    group.allow_unpress = false
    for index in range(MODE_TEXTS.size()):
        var mode_button := Button.new()
        mode_button.name = "Mode%s" % MODE_TEXTS[index]
        mode_button.text = MODE_TEXTS[index]
        mode_button.toggle_mode = true
        mode_button.button_group = group
        mode_button.focus_mode = Control.FOCUS_NONE
        mode_button.custom_minimum_size.y = 39.0
        mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mode_button.add_theme_font_size_override("font_size", 16)
        mode_button.pressed.connect(_on_mode_pressed.bind(index))
        row.add_child(mode_button)
        _mode_buttons.append(mode_button)
    _mode_buttons[0].set_pressed_no_signal(true)
    var fire_button := Button.new()
    fire_button.name = "FireNow"
    fire_button.text = "FIRE"
    fire_button.focus_mode = Control.FOCUS_NONE
    fire_button.custom_minimum_size.y = 39.0
    fire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fire_button.add_theme_font_size_override("font_size", 16)
    fire_button.pressed.connect(_on_fire_pressed)
    row.add_child(fire_button)
    _auto_button = Button.new()
    _auto_button.name = "AutoFire"
    _auto_button.text = "AUTO ON"
    _auto_button.toggle_mode = true
    _auto_button.button_pressed = true
    _auto_button.focus_mode = Control.FOCUS_NONE
    _auto_button.custom_minimum_size.y = 39.0
    _auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _auto_button.add_theme_font_size_override("font_size", 13)
    _auto_button.pressed.connect(_on_auto_pressed)
    row.add_child(_auto_button)

    # v100: Jump can be tested on Android without binding any normal flick.
    var jump_test_button := Button.new()
    jump_test_button.name = "JumpTest"
    jump_test_button.text = "JUMP TEST"
    jump_test_button.focus_mode = Control.FOCUS_NONE
    jump_test_button.custom_minimum_size.y = 39.0
    jump_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    jump_test_button.add_theme_font_size_override("font_size", 12)
    jump_test_button.pressed.connect(_on_jump_test_pressed)
    row.add_child(jump_test_button)

func _on_mode_pressed(index: int) -> void:
    attack_selected.emit(index)

func _on_auto_pressed() -> void:
    _auto_button.text = "AUTO ON" if _auto_button.button_pressed else "AUTO OFF"
    auto_fire_changed.emit(_auto_button.button_pressed)

func _on_fire_pressed() -> void:
    fire_requested.emit()

func _on_jump_test_pressed() -> void:
    jump_test_requested.emit()

# Update the selected visual state without emitting gameplay callbacks.
func apply_initial_defaults(attack_type: int, auto_enabled: bool) -> void:
    if _mode_buttons.size() != MODE_TEXTS.size() or _auto_button == null:
        return
    _mode_buttons[clampi(attack_type, 0, MODE_TEXTS.size() - 1)].set_pressed_no_signal(true)
    _auto_button.set_pressed_no_signal(auto_enabled)
    _auto_button.text = "AUTO ON" if auto_enabled else "AUTO OFF"

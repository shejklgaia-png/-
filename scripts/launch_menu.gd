extends Control
# v118: responsive full-viewport startup selector.
const BACKGROUND := Color("#0a101b")
const ACCENT := Color("#49c9ec")

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = BACKGROUND
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    column.add_theme_constant_override("separation", 24)
    center.add_child(column)

    var title := Label.new()
    title.text = "SERA SYSTEM"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", ACCENT)
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "SELECT DESTINATION"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 20)
    column.add_child(subtitle)

    for option in ["TRAINING ROOM", "SERA COMMAND NEXUS"]:
        var button := Button.new()
        button.text = option
        button.custom_minimum_size = Vector2(0, 92)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 23)
        column.add_child(button)
        button.pressed.connect(_enter.bind(option))

    # Limit width to 85% of viewport; never use absolute screen coordinates.
    var update_width := func() -> void:
        column.custom_minimum_size.x = minf(540.0, size.x * 0.85)
    resized.connect(update_width)
    update_width.call()

func _enter(choice: String) -> void:
    var destination := "res://scenes/main.tscn"
    if choice == "SERA COMMAND NEXUS":
        destination = "res://scenes/command_nexus.tscn"
    var err := get_tree().change_scene_to_file(destination)
    if err != OK:
        push_error("Cannot open scene: %s (error %d)" % [destination, err])

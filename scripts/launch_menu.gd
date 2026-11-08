extends Control
# v117: Startup choice only. Base equipment remains noninteractive.
func _ready() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color("#0a101b")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var layout := VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    layout.custom_minimum_size = Vector2(600, 310)
    layout.position = Vector2(60, 440)
    layout.add_theme_constant_override("separation", 28)
    add_child(layout)
    var heading := Label.new()
    heading.text = "SERA SYSTEM  /  SELECT DESTINATION"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 27)
    layout.add_child(heading)
    for choice in ["TRAINING ROOM", "SERA COMMAND NEXUS"]:
        var button := Button.new()
        button.text = choice
        button.custom_minimum_size = Vector2(600, 95)
        button.add_theme_font_size_override("font_size", 29)
        layout.add_child(button)
        button.pressed.connect(_enter.bind(choice))
func _enter(choice: String) -> void:
    if choice == "TRAINING ROOM":
        get_tree().change_scene_to_file("res://scenes/main.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/command_nexus.tscn")

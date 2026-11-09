extends Control
# v119: scene-defined centered UI with temporary touch-to-mouse emulation.
# Existing training scene keeps its own raw touch input behavior.
const TRAINING_SCENE: String = "res://scenes/main.tscn"
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
const VersionIndicator = preload("res://scripts/version_indicator.gd")

@onready var choices: VBoxContainer = $ScreenMargin/Centered/Options
@onready var training_button: Button = $ScreenMargin/Centered/Options/TrainingButton
@onready var nexus_button: Button = $ScreenMargin/Centered/Options/NexusButton
@onready var error_label: Label = $ScreenMargin/Centered/Options/ErrorMessage

var _previous_mouse_emulation: bool = false
var _changing_scene: bool = false

func _ready() -> void:
    _previous_mouse_emulation = Input.emulate_mouse_from_touch
    # Regular GUI Buttons need mouse emulation on Android. Do not change project.godot:
    # the existing training controls intentionally use raw InputEventScreenTouch.
    Input.emulate_mouse_from_touch = true
    training_button.pressed.connect(_open_scene.bind(TRAINING_SCENE))
    nexus_button.pressed.connect(_open_scene.bind(NEXUS_SCENE))
    resized.connect(_update_layout)
    _update_layout()
    VersionIndicator.attach(self)

func _exit_tree() -> void:
    Input.emulate_mouse_from_touch = _previous_mouse_emulation

func _update_layout() -> void:
    # Anchors and CenterContainer own the position; only set a capped width.
    choices.custom_minimum_size.x = maxf(0.0, minf(500.0, size.x - 72.0))
    var button_font_size: int = 27 if size.x >= 560.0 else 19
    training_button.add_theme_font_size_override("font_size", button_font_size)
    nexus_button.add_theme_font_size_override("font_size", button_font_size)

func _open_scene(scene_path: String) -> void:
    if _changing_scene:
        return
    _changing_scene = true
    var result: Error = get_tree().change_scene_to_file(scene_path)
    if result != OK:
        _changing_scene = false
        error_label.text = "FAILED TO LOAD: %s (ERROR %d)" % [scene_path.get_file(), result]
        error_label.visible = true
        push_error("Startup scene change failed: %s (error %d)" % [scene_path, result])

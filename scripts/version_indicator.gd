extends RefCounted
## Draw the version from project.godot in any HUD without blocking touch input.
static func attach(parent: Node) -> Label:
    var version_label := Label.new()
    version_label.name = "SeraVersionLabel"
    version_label.text = str(ProjectSettings.get_setting(
        "application/config/name", "SERA"))
    version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    version_label.add_theme_font_size_override("font_size", 14)
    version_label.add_theme_color_override("font_color", Color("#a5cad9"))
    version_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    parent.add_child(version_label)
    version_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    # Above the training combat panel (top 26), with viewport-safe right anchor.
    version_label.offset_left = -170.0
    version_label.offset_right = -14.0
    version_label.offset_top = 3.0
    version_label.offset_bottom = 25.0
    return version_label

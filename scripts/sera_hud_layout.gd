extends RefCounted
## Build the compact combat HUD without owning callbacks, touch hit testing
## or gameplay state. Dictionaries are created once at scene setup.

static func build_panel(layer: CanvasLayer) -> Panel:
    # Compact read-only console occupies only the top ~12% of a 1280px portrait
    # viewport. Anchors keep the right-side telemetry aligned on other aspect ratios.
    var panel := Panel.new()
    panel.name = "CompactCombatHUD"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_left = 18.0
    panel.offset_right = -18.0
    panel.offset_top = 26.0
    panel.offset_bottom = 150.0
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.055, 0.088, 0.13, 0.91)
    panel_style.border_color = Color(0.19, 0.37, 0.43, 0.82)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", panel_style)

    var accent_bar := ColorRect.new()
    accent_bar.name = "Accent"
    accent_bar.position = Vector2(13.0, 13.0)
    accent_bar.size = Vector2(3.0, 31.0)
    accent_bar.color = Color("5de4d1")
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(accent_bar)

    var heading := Label.new()
    heading.name = "CombatTitle"
    heading.text = "SERA   /   LOCK"
    heading.position = Vector2(27.0, 10.0)
    heading.add_theme_font_size_override("font_size", 20)
    heading.add_theme_color_override("font_color", Color("dceef2"))
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(heading)
    return panel


static func build_primary_status(panel: Panel, vitals_script: Script,
        hp_bar_width: float) -> Dictionary:
    var state_label := Label.new()
    state_label.name = "ActionState"
    state_label.text = "WAIT  |  Wait_motion"
    state_label.position = Vector2(27.0, 43.0)
    state_label.add_theme_font_size_override("font_size", 14)
    state_label.add_theme_color_override("font_color", Color("8fb3c1"))
    state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(state_label)

    var hp_label := Label.new()
    hp_label.name = "TargetHpLabel"
    # Enemy health remains on the right; the SERA HP/EN meters sit together
    # on the top-left inside this existing header without covering the field.
    hp_label.position = Vector2(414.0, 80.0)
    hp_label.add_theme_font_size_override("font_size", 14)
    hp_label.add_theme_color_override("font_color", Color("d3e9ed"))
    hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(hp_label)

    var bar_background := ColorRect.new()
    bar_background.name = "TargetHpBackground"
    bar_background.position = Vector2(414.0, 105.0)
    bar_background.size = Vector2(hp_bar_width, 7.0)
    bar_background.color = Color("23404a")
    bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(bar_background)
    var hp_fill := ColorRect.new()
    hp_fill.name = "TargetHpFill"
    hp_fill.position = bar_background.position
    hp_fill.size = bar_background.size
    hp_fill.color = Color("5de4d1")
    hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(hp_fill)

    # Two unobtrusive read-only meters in the top-left: HP above EN.
    # They share the existing header rather than extending over the arena.
    var vitals_hud: Control = vitals_script.new()
    vitals_hud.name = "CombatVitals"
    vitals_hud.position = Vector2(27.0, 62.0)
    vitals_hud.size = Vector2(190.0, 61.0)
    vitals_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(vitals_hud)
    return {
        "state": state_label,
        "target_hp_label": hp_label,
        "target_hp_fill": hp_fill,
        "vitals": vitals_hud,
    }


static func build_step_telemetry(panel: Panel) -> Dictionary:
    var step_status_label := Label.new()
    step_status_label.name = "StepStatusLabel"
    panel.add_child(step_status_label)
    step_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    step_status_label.offset_left = -224.0
    step_status_label.offset_right = -18.0
    step_status_label.offset_top = 14.0
    step_status_label.offset_bottom = 50.0
    step_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    step_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    step_status_label.add_theme_font_size_override("font_size", 16)
    step_status_label.add_theme_color_override("font_color", Color("d5faff"))
    step_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var status_style := StyleBoxFlat.new()
    status_style.bg_color = Color("183a44")
    status_style.border_color = Color("3fabb8")
    status_style.set_border_width_all(1)
    status_style.set_corner_radius_all(7)
    step_status_label.add_theme_stylebox_override("normal", status_style)

    var step_detail_label := Label.new()
    step_detail_label.name = "StepModeDetails"
    panel.add_child(step_detail_label)
    step_detail_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    step_detail_label.offset_left = -250.0
    step_detail_label.offset_right = -18.0
    step_detail_label.offset_top = 60.0
    step_detail_label.offset_bottom = 79.0
    step_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    step_detail_label.add_theme_font_size_override("font_size", 14)
    step_detail_label.add_theme_color_override("font_color", Color("a5c5d0"))
    step_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var control_hint := Label.new()
    control_hint.name = "InputHint"
    # The second HP bar occupies this row; action hint remains in the README.
    control_hint.text = ""
    panel.add_child(control_hint)
    control_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    control_hint.offset_left = -250.0
    control_hint.offset_right = -18.0
    control_hint.offset_top = 94.0
    control_hint.offset_bottom = 114.0
    control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    control_hint.add_theme_font_size_override("font_size", 12)
    control_hint.add_theme_color_override("font_color", Color("7195a3"))
    control_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return {
        "status": step_status_label,
        "detail": step_detail_label,
    }

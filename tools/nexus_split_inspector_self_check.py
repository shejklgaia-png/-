#!/usr/bin/env python3
"""CUSTOMIZE separate total / part windows and independent inspect/select hit areas."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
nexus=(root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in (
    'const LaboStats = preload("res://scripts/sera_labo_stats.gd")',
    '"CustomizeTotalStatsPanel"',
    '"CustomizePartStatsPanel"',
    '"CustomizePartStatsScroll"',
    '"CustomizePartStatsRows"',
    "customize_part_stats_list.columns = 3",
    "customize_part_stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED",
    "func _set_customization_camera_projection(enabled: bool) -> void:",
    "Camera3D.PROJECTION_ORTHOGONAL",
    '"CustomizePartStatsName"',
    'func _inspect_customization_part(slot: String) -> void:',
    'func _refresh_customization_part_stats(slot: String) -> void:',
    'LaboStats.complete_profile_text(',
    'func _layout_customization_part_stats() -> void:',
    'customize_part_stats_scroll.position = Vector2(11, 44)',
    'func _customize_part_stats_rect(view: Vector2) -> Rect2:',
    'if Rect2(expand.position, expand.size).has_point(row_point):',
    '_show_customization_part_picker(slot)',
    '_inspect_customization_part(slot)',
    'customize_part_stats_panel.get_global_rect().has_point(event.position)',
    'customize_part_stats_panel.visible = focused_target == "CUSTOMIZE"',
    'var show: bool = focused_target == "CUSTOMIZE"',
    'customize_part_picker.visible = false',
):
    assert token in nexus, token
assert 'customize_total_title.text = ""' in nexus
assert 'customize_part_stats_header.text = ""' in nexus
assert 'customize_equipment_header.text = ""' in nexus
assert 'customize_right_header.visible = false' in nexus
assert 'focus_title.text = "" if target_name == "CUSTOMIZE" else target_name' in nexus
assert 'CustomizePartPreviewTechFrame' in nexus
assert 'StatUI.layout_column_rules(' in nexus
# Every layout rect reference must exist before use; undefined 'preview'
# prevents Godot compiling command_nexus.gd and loading the NEXUS scene.
start=nexus.index("func _customize_part_stats_rect(")
end=nexus.index("\nfunc ", start + 4)
layout=nexus[start:end]
assert "var preview: Rect2 = _customize_square_menu_rect(view)" in layout
assert layout.index("var preview: Rect2") < layout.index("preview.end.y")

assert 'customize_part_accents = StatUI.attach_status_marks(' in nexus
assert 'StatUI.layout_status_marks(customize_part_accents,' in nexus
# Full-width 3x5 part grid stays non-scrolling even with larger, two-line type.
for required in (
    'row.custom_minimum_size = Vector2(100, 44)',
    'customize_part_stats_list.add_theme_constant_override("v_separation", 3)',
    'StatUI.layout_metric_pair(label, value, row_width, 44.0, 19, 24, 16, 20)',
):
    assert required in nexus, required
assert 'StatUI.fit_label(' in nexus
assert 'button.text = _default_part_name(slot, selected_model)' in nexus
assert 'py tools/nexus_split_inspector_self_check.py' in manifest
assert 'gd tools/nexus_split_inspector_runtime_check.gd' in manifest
print("NEXUS_SPLIT_INSPECTOR_STATIC_PASS")

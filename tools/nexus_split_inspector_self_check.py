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
    '"CustomizePartStatsName"',
    'func _inspect_customization_part(slot: String) -> void:',
    'func _refresh_customization_part_stats(slot: String) -> void:',
    'LaboStats.complete_profile_text(blueprint)',
    'func _layout_customization_part_stats() -> void:',
    'func _customize_part_stats_rect(view: Vector2) -> Rect2:',
    'if Rect2(expand.position, expand.size).has_point(row_point):',
    '_show_customization_part_picker(slot)',
    '_inspect_customization_part(slot)',
    'customize_part_stats_scroll.get_global_rect().has_point(',
    'customize_part_stats_panel.visible = focused_target == "CUSTOMIZE"',
    'customize_stats_panel.visible = focused_target == "CUSTOMIZE"',
    'customize_part_picker.visible = false',
):
    assert token in nexus, token
assert '"TOTAL STATUS"' in nexus
assert '"PART STATUS"' in nexus
assert 'button.text = _default_part_name(slot, selected_model)' in nexus
assert 'py tools/nexus_split_inspector_self_check.py' in manifest
assert 'gd tools/nexus_split_inspector_runtime_check.gd' in manifest
print("NEXUS_SPLIT_INSPECTOR_STATIC_PASS")

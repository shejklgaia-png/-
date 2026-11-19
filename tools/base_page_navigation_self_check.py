#!/usr/bin/env python3
"""v509 navigation must replace converter dropdowns and share back semantics."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
facility=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
nexus=(root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "OptionButton.new()" not in facility, "No material selection dropdown"
assert "func _render_family_page(" in facility
assert "func _select_conversion_family(" in facility
assert "func navigate_back(" in facility
assert "func _input(" in facility and "KEY_BACK" in facility and "ui_cancel" in facility
assert "func _on_shade_input(" in facility and "navigate_back()" in facility
assert "func _navigate_back(" in nexus
assert 'func _tap_at(point: Vector2) -> void:' in nexus
assert "KEY_BACK" in nexus and "ui_cancel" in nexus
assert "gd tools/base_page_navigation_runtime_check.gd" in manifest
print("SERA_PAGED_BACK_STATIC_PASS")

#!/usr/bin/env python3
"""v509 navigation must replace converter dropdowns and share back semantics."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
facility=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
nexus=(root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
hub=(root/"scripts/base_exploration.gd").read_text(encoding="utf-8")
# Only material conversion must remain card-based. The warehouse's equipment
# hanger picker is independently allowed to use an OptionButton.
conversion=facility.split("func _render_family_page(",1)[1].split("\nfunc ",1)[0]
assert "OptionButton.new()" not in conversion, "No material conversion dropdown"
assert "func _render_family_page(" in facility
assert "func _select_conversion_family(" in facility
assert "func navigate_back(" in facility
assert "func _input(" in facility and "KEY_BACK" in facility and "ui_cancel" in facility
assert "func _on_shade_input(" in facility and "navigate_back()" in facility
assert "func _navigate_back(" in nexus
assert 'func _tap_at(point: Vector2) -> void:' in nexus
assert "KEY_BACK" in nexus and "ui_cancel" in nexus
assert "gd tools/base_page_navigation_runtime_check.gd" in manifest
assert "quit_on_go_back=false" in project, "Android Back must not quit the app by default"
assert "go_back_requested.connect(" in hub and "go_back_requested.connect(" in nexus
assert "func _on_android_back(" in hub and "func _on_android_back(" in nexus
# BASE/GRID plate must be hidden when a LABO/warehouse modal owns the screen.
assert "facility_modal.visibility_changed.connect(_sync_base_grid_plate_visibility)" in hub
assert "func _sync_base_grid_plate_visibility() -> void:" in hub
assert 'grid_ui.visible = not bool(facility_system.call("is_menu_open"))' in hub
print("SERA_PAGED_BACK_STATIC_PASS")

#!/usr/bin/env python3
"""Android-editor-specific blank cards require runtime checkpoints on screen."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
script=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'diagnostic_button.name = "UIDiagnosticToggle"' in script
assert 'diagnostic_readout.name = "UIDiagnosticReadout"' in script
assert 'func _diag_begin(' in script
assert 'func _diag_step(' in script
assert 'func _diag_update(' in script
assert 'func _diag_toggle(' in script
assert 'Engine.get_version_info()' in script, "compare Godot Android editor version to APK 4.7.2"
assert 'get_child_count()' in script and 'get_global_rect()' in script
assert 'ResourceLoader.exists("res://assets/ui/sera_matte_icon_atlas.webp")' in script
assert 'stage: ' in script and 'slots: ' in script
assert 'diag_created += 1' in script
assert 'diag_icon_count += 1' in script
assert 'row.add_child(card)' in script
assert 'gd tools/android_editor_card_diagnostic_runtime_check.gd' in manifest
print("SERA_ANDROID_EDITOR_CARD_DIAG_STATIC_PASS")

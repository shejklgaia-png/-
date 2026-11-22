#!/usr/bin/env python3
"""Static integration checks for NEXUS IRIS material preset persistence.
Run from the repository root. Runtime/GPU validation still needs Godot.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
presets = (ROOT / "scripts/sera_iris_material_presets.gd").read_text()
controls = (ROOT / "scripts/sera_iris_material_controls.gd").read_text()
viewer = (ROOT / "scripts/sera_part_preview_widget.gd").read_text()
shared_fps = (ROOT / "scripts/sera_frame_rate_settings.gd").read_text()

assert 'user://sera_settings.cfg' in presets
assert 'user://sera_settings.cfg' in shared_fps
assert "const SLOT_COUNT: int = 5" in presets
assert "SERA_IRIS_MATERIAL_SHADING_V1" in presets
for key in ("armor", "dark_mechanism", "lens", "emission"):
    assert f'"{key}"' in presets
for func in ("load_last", "save_last", "read_preset", "save_preset",
             "list_presets", "normalize", "parse_text", "default_payload"):
    assert f"static func {func}(" in presets
for name in ("preset_save_requested", "preset_load_requested",
             "reset_requested", "import_requested"):
    assert f"signal {name}" in controls
    assert f'"{name}"' in viewer
assert "range(1, 6)" in controls
assert "LineEdit.new()" in controls
assert "control_at" in controls and "captured is LineEdit" in viewer
for func in ("_save_iris_preset", "_load_iris_preset",
             "_reset_iris_material_settings", "_import_iris_material_settings",
             "_persist_iris_material_settings"):
    assert f"func {func}(" in viewer
assert "IrisMaterialPresets.load_last()" in viewer
assert "IrisMaterialPresets.save_last(" in viewer
assert "DisplayServer.clipboard_get()" in viewer
assert "DisplayServer.clipboard_set(" in viewer
assert "IrisMaterialPresets.normalize(" in viewer
assert 'enable_nexus_iris_id_contour and current_blueprint == "H02"' in viewer
print("IRIS material preset save/load static integration: OK")

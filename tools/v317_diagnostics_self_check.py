#!/usr/bin/env python3
"""Android diagnostic input isolation, opt-in and stable version label."""
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT/"scripts/main.gd").read_text(encoding="utf-8")
diag = (ROOT/"scripts/dev_diagnostics.gd").read_text(encoding="utf-8")
project = (ROOT/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v317"', project)
for token in (
    'const DEV_DIAGNOSTICS = preload("res://scripts/dev_diagnostics.gd")',
    "var diagnostic_enabled: bool = false",
    'diagnostic_button.name = "DiagnosticToggle"',
    'diagnostic_copy_button.name = "DiagnosticCopy"',
    'diagnostic_copy_button.visible = false',
    "func _sample_diagnostics(delta: float) -> void:",
    "if not diagnostic_enabled or diagnostic_overlay == null:",
    'diagnostic_overlay.call("record_sample", {',
    "func _toggle_diagnostics() -> void:",
    "func _copy_diagnostics() -> void:",
):
    assert token in main, token
for token in (
    "func set_collecting(enabled: bool) -> void:",
    "if not collecting:",
    "func record_sample(data: Dictionary) -> void:",
    "func copy_trace() -> int:",
    "DisplayServer.clipboard_set(export_text())",
    "const MAX_SAMPLES: int = 500",
):
    assert token in diag, token
assert "HTTPClient" not in diag and "FileAccess" not in diag and "user://" not in diag
print("SERA_V317_DIAGNOSTIC_STATIC_PASS")

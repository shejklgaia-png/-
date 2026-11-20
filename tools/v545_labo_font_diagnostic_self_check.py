#!/usr/bin/env python3
"""SERA v545: on-device fonts are diagnosed, not assumed to be installed."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
diag = (root / "scripts/sera_font_diagnostics.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'const SeraFontDiag = preload("res://scripts/sera_font_diagnostics.gd")' in ui
for token in ('UIFontDiagnosticToggle', 'FontDiagnosticOverlay',
              'FontDiagnosticReport', 'FontSample_', 'FontDiagScroll',
              'FontDiagRefresh', 'FontDiagCopy', 'FontDiagClose',
              'func _font_diag_toggle()', 'func _font_diag_refresh()',
              'func _font_diag_copy()', 'func _font_diag_close()',
              'DisplayServer.clipboard_set(font_diag_report.text)',
              'font_diag_button.visible = diagnostic_button.visible',
              'if font_diag_overlay == null:',
              'font_diag_overlay.visible = not font_diag_overlay.visible'):
    assert token in ui, token
for token in ('static func roles() -> Array[Dictionary]:',
              'OS.get_name()', 'OS.get_system_fonts()',
              'OS.get_system_font_path(', 'OS.get_system_font_path_for_text(',
              'TextServerManager.get_primary_interface()',
              'font.get_rids()', 'server.font_get_name(rid)', 'font.has_char(',
              'SERA FONT DIAG v548'):
    assert token in diag, token
assert "SeraFontDiag.report()" not in ui.split("func _process(delta: float) -> void:")[-1]
assert 'embedded:' in diag and 'JAPANESE FONT: PASS' in diag
assert 'available: RAW=' in diag and 'load route: ' in diag
assert '_embedded_face(font: Font) -> FontFile' in diag
assert 'py tools/v545_labo_font_diagnostic_self_check.py' in ci
assert 'gd tools/v545_labo_font_diagnostic_runtime_check.gd' in ci
print("SERA_V545_FONT_DIAGNOSTIC_STATIC_PASS")

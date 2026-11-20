#!/usr/bin/env python3
"""SERA v547: avoid Android editor import-cache dependency for bundled WOFF2."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
skin = (root/"scripts/sera_labo_round_skin.gd").read_text("utf-8")
diag = (root/"scripts/sera_font_diagnostics.gd").read_text("utf-8")
preset = (root/"export_presets.cfg").read_text("utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text("utf-8")
for token in (
    'func _font_from_raw(path: String, required_glyph: int) -> FontFile:',
    "FileAccess.file_exists(path)",
    "FileAccess.get_file_as_bytes(path)",
    "face.data = bytes",
    "face.allow_system_fallback = false",
    "face.has_char(required_glyph)",
    "static func _load_bundled_font(path: String, required_glyph: int) -> FontFile:",
    "var imported: Resource = ResourceLoader.load(path)",
    'method = "RAW_BYTES"',
    'method = "IMPORTED_RESOURCE"',
    "SERA_FONT_LOAD_FAILED:",
    "static func font_load_status(path: String) -> String:",
):
    assert token in skin, token
assert skin.index("font = _font_from_raw(path, required_glyph)") < skin.index(
    "ResourceLoader.load(path)"), "raw bytes must be attempted before importer"
for token in (
    'SERA FONT DIAG v547 / LOAD ROUTE CHECK',
    'available: RAW=',
    'load route: ',
    'FONT BASE: MISSING',
    'JAPANESE FONT: PASS',
):
    assert token in diag, token
assert 'include_filter="assets/fonts/*.woff2"' in preset
assert 'py tools/v547_font_raw_loader_self_check.py' in manifest
assert 'gd tools/v547_font_raw_loader_runtime_check.gd' in manifest
print("SERA_V547_FONT_RAW_LOADER_STATIC_PASS")

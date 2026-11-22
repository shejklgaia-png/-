#!/usr/bin/env python3
"""BASE image diagnosis: distinguish stale code, masked ink, and missing batches."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")
assert 'const BaseFacilityInk = preload("res://scripts/sera_base_facility_outlines.gd")' in hub
assert 'const OUTLINE_TEST_FAST_SHADER = preload("res://shaders/sera_view_edges_fast.gdshader")' in hub
assert 'const OUTLINE_TEST_SAFE_SHADER = preload("res://shaders/sera_view_edges.gdshader")' in hub
assert 'OutlineProbeButton' in hub
assert '輪郭検査' in hub
assert 'OUTLINE-DIAG v1' in hub
assert 'func _cycle_outline_probe() -> void:' in hub
assert 'BaseFacilityInk.material()' in hub
assert 'Color("#ff00ff")' in hub
assert 'Color("#000000")' in hub
assert '"stroke_px", 6.0' in hub
assert 'outline_probe_mode = (outline_probe_mode + 1) % 3' in hub
assert 'mat.shader = OUTLINE_TEST_FAST_SHADER' in hub
assert 'mat.shader = OUTLINE_TEST_SAFE_SHADER' in hub
assert 'py tools/base_outline_probe_self_check.py' in manifest
assert 'gd tools/base_outline_probe_runtime_check.gd' in manifest
assert 'base_outline_probe_runtime_check.gd' in workflow
print("SERA_BASE_OUTLINE_PROBE_STATIC_PASS")

#!/usr/bin/env python3
"""BASE spatial composition: off-center clusters and deliberate negative-space lanes."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root/"scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'static func props_for(' in src
assert 'static func _make_stacked(' in src
assert '_item("cargo_box"' in src
assert 'RandomNumberGenerator' not in src
assert 'py tools/base_prop_density_rhythm_self_check.py' in ci
assert 'gd tools/base_prop_density_rhythm_runtime_check.gd' in ci
print("SERA_BASE_PROP_DENSITY_RHYTHM_STATIC_PASS")

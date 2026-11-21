#!/usr/bin/env python3
"""BASE informal center: prove new compositional checks run in main CI."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
layout=(r/"tools/base_isometric_layout_self_check.py").read_text(encoding="utf-8")
runtime=(r/"tools/base_soft_center_space_runtime_check.gd").read_text(encoding="utf-8")
hub=(r/"scripts/base_exploration.gd").read_text(encoding="utf-8")
floor=(r/"scripts/sera_base_floor_detail.gd").read_text(encoding="utf-8")
manifest=(r/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert '"LABO": (.517, .642)' in layout
assert 'SERA_BASE_SOFT_CENTER_SPACE_PASS' in runtime
assert 'site_count != 8' in runtime and 'scraps != 16' in runtime
assert 'absf(left_heights[i] - right_heights[i]) < 0.007' in runtime
assert 'ScrapPile_' in hub and 'CRATE_WAYPOINTS' in hub
assert 'if posmod(i' in floor, "floor warnings must have irregular breaks"
assert 'py tools/base_soft_center_space_self_check.py' in manifest
assert 'gd tools/base_soft_center_space_runtime_check.gd' in manifest
print("SERA_BASE_SOFT_CENTER_SPACE_STATIC_PASS")

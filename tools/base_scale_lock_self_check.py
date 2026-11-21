#!/usr/bin/env python3
"""Keep the user-approved BASE scale and camera composition unchanged."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
base = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
facility = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
# Independent user-approved constraints: no facility enlargement in this pass.
assert 'const BASE_ORTHO_SIZE: float = 38.0' in base
assert 'const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)' in base
assert 'const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 2.1, -2.2)' in base
assert 'const FACILITY_VISUAL_SCALE = {' in arch
for key in ("LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"):
    expected = "1.45" if key == "LABO" else "1.55"
    assert re.search(r'"' + key + r'":\s*' + expected + r'\b', arch), key
assert 'g.detail_scale = float(FACILITY_VISUAL_SCALE[key])' in arch
assert 'g.detail_scale = 1.0\n    BaseClutter.decorate(g, key)' in arch
assert len(re.findall(r'"size": Vector3\(', facility)) == 7
assert 'py tools/base_scale_lock_self_check.py' in manifest
print("SERA_BASE_SCALE_LOCK_STATIC_PASS")

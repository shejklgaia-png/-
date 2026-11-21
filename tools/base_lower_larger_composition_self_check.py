#!/usr/bin/env python3
"""Approved BASE portrait fill: lower the whole view and scale stations without growing NEXUS."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
# Preserve the formerly approved downward screen framing and model sizes;
# the camera now drops in altitude to show more of the front facades.
assert 'const BASE_ORTHO_SIZE: float = 38.0' in hub
assert 'const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)' in hub
assert 'const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 2.1, -2.2)' in hub
assert 'cam.keep_aspect = Camera3D.KEEP_HEIGHT' in hub
assert 'cam.look_at(BASE_CAMERA_TARGET, Vector3.UP)' in hub
assert 'g.detail_scale = 1.14' in arch, "NEXUS remains at its previously approved scale"
assert 'g.detail_scale = 1.45 if key == "LABO" else 1.55' in arch
assert 'g.detail_scale = 1.0\n    BaseClutter.decorate(g,' in arch, "do not enlarge props twice"
assert 'BASE_CAMERA_POSITION + (' in hub, "GRID to BASE transition must retain base camera position"
assert 'py tools/base_lower_larger_composition_self_check.py' in ci
assert 'gd tools/base_lower_larger_composition_runtime_check.gd' in ci
print("SERA_BASE_LOWER_LARGER_COMPOSITION_STATIC_PASS")

#!/usr/bin/env python3
"""Approved 5-tier BASE portrait composition with exactly 152 3D prop placements."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root/"scripts/base_exploration.gd").read_text(encoding="utf-8")
fac = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
props = (root/"scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
preview = (root/"scripts/sera_base_layout_preview.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'Vector3(-13.44, 0.0, -19.91)' in hub, "NEXUS is the upper anchor"
for key, position in {
    "LABO": "Vector3(7.15, 0.0, 6.95)",
    "SCRAP_COLLECTOR": "Vector3(9.95, 0.0, 22.18)",
    "SMELTER": "Vector3(-12.61, 0.0, -7.70)",
    "RECYCLER": "Vector3(-1.85, 0.0, -14.73)",
    "GENERATOR": "Vector3(7.37, 0.0, -3.57)",
    "STORAGE": "Vector3(-3.43, 0.0, 3.92)",
    "BUILD_TERMINAL": "Vector3(19.49, 0.0, 15.88)",
}.items():
    assert f'"id": "{key}"' in fac and position in fac, key
assert 'const BASE_ORTHO_SIZE: float = 38.0' in hub
assert 'const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)' in hub
assert 'static func _append_satellite_props(' in props
assert 'satellite["satellite"] = true' in props
assert '_satellite_clear(' in props
assert '_append_satellite_props(key, items)' in props
assert 'if not found:' in props and 'push_error("SERA BASE satellite floor packing failed:' in props
assert 'MultiMeshInstance3D.new()' not in props
assert 'Clutter._append_satellite_props(key, output)' in preview
assert '"satellite": bool(source.get("satellite", false))' in preview
assert 'py tools/base_tall_dense_composition_self_check.py' in manifest
assert 'gd tools/base_tall_dense_composition_runtime_check.gd' in manifest
print("SERA_BASE_TALL_DENSE_COMPOSITION_STATIC_PASS")

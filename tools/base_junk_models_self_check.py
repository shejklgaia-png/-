#!/usr/bin/env python3
"""SERA BASE: distinct pitched plate geometry and irregular, batched salvage."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
arch=(root/"scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
props=(root/"scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
junk=(root/"scripts/sera_base_junk_geometry.gd").read_text(encoding="utf-8")
base=(root/"scripts/base_exploration.gd").read_text(encoding="utf-8")
ci=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "func box_tilt(" in arch, "need true X/Z tilted 3D surfaces, not Y-only yaw"
assert 'Basis.from_euler(' in arch
assert "JunkGeometry.panel_stack(" in props
assert '"panel_stack":' in props
assert "static func panel_stack(" in junk
assert "static func scrap_heap(" in junk
assert "const PANEL_SHAPES = 6" in junk
assert "const SCRAP_PROFILES = 5" in junk
for kind in ("notched", "bent", "trapezoid", "ribbed", "short", "long"):
    assert '"'+kind+'"' in junk, "missing distinct shape: "+kind
for kind in ("plate", "tube", "gear", "frame", "axle", "cable", "housing"):
    assert kind in junk, "missing salvage type: "+kind
assert "g.box_tilt(" in junk
assert "g.rod(" in junk and "g.ring(" in junk
assert "SalvageMeshes" in base and "JunkGeometry.scrap_heap(" in base
assert "Architecture.Batch.new(" in base
assert 'pile.name = "ScrapPile_%02d" % i' in base
assert '"StackBase"' not in base and '"RecoveredPanel"' not in base
assert "RandomNumberGenerator" not in junk and "randi(" not in junk
assert "py tools/base_junk_models_self_check.py" in ci
assert "gd tools/base_junk_models_runtime_check.gd" in ci
print("SERA_BASE_JUNK_MODELS_STATIC_PASS: 6 plate silhouettes, 5 scrap profiles")

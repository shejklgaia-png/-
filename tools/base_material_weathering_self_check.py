#!/usr/bin/env python3
"""Base reference metallic surface weathering without per-instance allocations."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
texture = (root / "assets/base/industrial_steel_grunge.svg").read_text(encoding="utf-8")
cloth = (root / "assets/base/aged_canvas_weave.svg").read_text(encoding="utf-8")
base = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
architecture = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for asset in (texture, cloth):
    assert asset.lstrip().startswith("<svg")
    assert "<rect" in asset and "viewBox" in asset
assert 'res://assets/base/industrial_steel_grunge.svg' in base
assert 'res://assets/base/industrial_steel_grunge.svg' in architecture
assert 'res://assets/base/aged_canvas_weave.svg' in architecture
assert "mat.albedo_texture = WEATHERED_STEEL" in base
assert "surface.albedo_texture = WEATHERED_CANVAS" in architecture
assert "surface.albedo_texture = WEATHERED_STEEL" in architecture
assert 'py tools/base_material_weathering_self_check.py' in manifest
assert 'gd tools/base_material_weathering_runtime_check.gd' in manifest
print("SERA_BASE_MATERIAL_WEATHERING_STATIC_PASS")

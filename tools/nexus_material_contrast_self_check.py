#!/usr/bin/env python3
"""NEXUS hangar opaque material contrast contract; preserve existing emissive indices."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / "scripts/command_nexus.gd").read_text(encoding="utf-8")
start = s.index("func _mat(index: int) -> StandardMaterial3D:")
end = s.index("\nfunc _render_batches()", start)
block = s[start:end]
assert "mat.metallic = 0.28 if index in [1, 2, 3] else 0.16" in block
assert "mat.roughness = 0.52 if index in [1, 2, 3] else 0.70" in block
assert "if index in [5, 6, 7]:" in block
assert "mat.emission_energy_multiplier = 1.05 if index == 7 else 1.75" in block
assert "mat.metallic_specular = 0.42 if index in [1, 2, 3] else 0.5" in block
assert "mat.transparency" not in block
print("NEXUS_MATERIAL_CONTRAST_OK")

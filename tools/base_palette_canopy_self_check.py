#!/usr/bin/env python3
"""Retain a distinct but legible steel-yard palette and a real left-side canopy."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def src(p):return (ROOT/p).read_text(encoding="utf-8")
hub=src("scripts/base_exploration.gd")
arch=src("scripts/sera_base_architecture.gd")
ci=src("tools/sera_ci_manifest.txt")
colors=[
"#292d33","#303336","#323432","#303339","#2b3237","#34312e"
]
for color in colors:
    assert 'Color("'+color+'")' in hub,color
    rgb=[int(color[n:n+2],16) for n in (1,3,5)]
    assert rgb[0] <= 56 and rgb[1] <= 56 and rgb[2] <= 58
assert '"cloth": "#68685f"' in arch
assert 'Vector3(-3.21 + p * 0.49, 2.80 - p * 0.09, 2.67)' in arch
assert 'Vector3(-2.88 + side * 0.72, 0.20, 3.42)' in arch
assert 'Vector3(0.62, 0.40, 1.72)' in arch
assert 'g.detail_scale = 1.14' in arch
assert 'const BASE_ORTHO_SIZE: float = 38.0' in hub
assert 'py tools/base_palette_canopy_self_check.py' in ci
assert 'gd tools/base_palette_canopy_runtime_check.gd' in ci
print("SERA_BASE_PALETTE_CANOPY_STATIC_PASS")

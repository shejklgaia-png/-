#!/usr/bin/env python3
"""SERA BASE: independently enforce low-luminance neutral deck against brighter equipment."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
hub = (ROOT / "scripts/base_exploration.gd").read_text(encoding="utf-8")
detail = (ROOT / "scripts/sera_base_floor_detail.gd").read_text(encoding="utf-8")
machines = (ROOT / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
architecture = (ROOT / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

def rgb(color):
    return [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]

def luminance(color):
    r, g, b = [(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055)**2.4) for c in rgb(color)]
    return 0.2126*r + 0.7152*g + 0.0722*b

palette = re.search(r'var tints := \[([^\]]+)\]', hub)
assert palette, "instanced deck palette missing"
colors = re.findall(r'Color\("(#[0-9a-fA-F]{6})"\)', palette.group(1))
assert len(colors) == 6, "preserve six instanced metal plate batches"
assert max(luminance(c) for c in colors) < 0.030, "deck must remain charcoal, not blue-gray"
assert max(max(rgb(c)) - min(rgb(c)) for c in colors) <= 0.07, "floor must be near-neutral"
assert max(luminance(c) for c in colors) - min(luminance(c) for c in colors) < 0.018, "avoid noisy light-dark checkerboard"
assert 'mat.roughness = 0.94' in hub and 'mat.metallic = 0.12' in hub
assert 'mat.albedo_texture = steel_texture' in hub, "keep weathered metal texture"
assert 'Color("#12171b")' in hub, "gap underlay should be almost black"
assert 'Color("#46535c")' in machines, "facility podium should contrast with floor"
assert 'Color("#46535c")' in hub, "NEXUS podium should match darker deck contrast"
assert 'const COLORS = {' in architecture, "protect individual models"
assert luminance("#46535c") > max(luminance(c) for c in colors) * 3, "facility podium must separate from deck"
assert '"caution": "#d7a951"' in detail, "yellow hazard lanes must remain distinct"
assert luminance("#d7a951") > max(luminance(c) for c in colors) * 10
for hue in ("seam", "edge", "bolt", "grate", "grille", "caution", "cable", "pipe", "mark"):
    assert '"'+hue+'"' in detail
assert 'env.ambient_light_energy = 0.38' in hub, "approved night yard should preserve readable charcoal deck"
assert 'sun.light_energy = 0.36' in hub, "approved blue-gray night yard uses subdued directional fill"
assert 'py tools/base_floor_contrast_self_check.py' in manifest
assert 'gd tools/base_floor_contrast_runtime_check.gd' in manifest
print("SERA_BASE_FLOOR_CONTRAST_STATIC_PASS")

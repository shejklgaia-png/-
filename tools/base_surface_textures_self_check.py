#!/usr/bin/env python3
"""BASE industrial texture contract, independent from current material implementation."""
from pathlib import Path
from xml.etree import ElementTree

root = Path(__file__).resolve().parents[1]
def source(path):
    return (root / path).read_text(encoding="utf-8")

for name, elements in {
    "industrial_armor_chipped.svg": ("linearGradient", "path", "rect"),
    "industrial_deck_wear.svg": ("linearGradient", "path", "rect"),
    "industrial_oxidized_metal.svg": ("linearGradient", "path", "rect"),
}.items():
    asset = source("assets/base/" + name)
    tag = ElementTree.fromstring(asset)
    assert tag.tag.endswith("svg"), name
    assert tag.attrib.get("width") == "512" and tag.attrib.get("height") == "512", name
    for element in elements:
        assert "<" + element in asset, (name, element)
    assert "filter=" not in asset and "feTurbulence" not in asset, "no GPU shader/filter noise"
    assert len(asset) < 68000, "small stable raster import, not an oversized raw asset"

canvas = source("assets/base/aged_canvas_weave.svg")
assert '<linearGradient id="canvas-shade"' in canvas
assert 'id="canvas-warp"' in canvas
assert "<path" in canvas and "<rect" in canvas
assert len(canvas) < 68000

arch = source("scripts/sera_base_architecture.gd")
floor = source("scripts/base_exploration.gd")
manifest = source("tools/sera_ci_manifest.txt")
assert 'const WEATHERED_ARMOR_PATH: String = "res://assets/base/industrial_armor_chipped.svg"' in arch
assert 'const WEATHERED_OXIDE_PATH: String = "res://assets/base/industrial_oxidized_metal.svg"' in arch
assert "surface.albedo_texture = armor_texture" in arch
assert "surface.albedo_texture = oxide_texture" in arch
assert 'const WEATHERED_DECK_PATH: String = "res://assets/base/industrial_deck_wear.svg"' in floor
assert "mat.albedo_texture = deck_texture" in floor
for file in ("base_surface_textures_self_check.py", "base_surface_textures_runtime_check.gd"):
    assert ("py " if file.endswith(".py") else "gd ") + "tools/" + file in manifest
print("SERA_BASE_SURFACE_TEXTURE_STATIC_PASS")

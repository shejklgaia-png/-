#!/usr/bin/env python3
"""Preview backdrops must stay perceptually lighter than the active 3D ink."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda name: (ROOT / name).read_text(encoding="utf-8")
palette = read("scripts/sera_icon_background.gd")
viewer = read("tools/equipment_intake/godot_preview.gd")
nexus = read("scripts/command_nexus.gd")
sera = read("scripts/sera_view_edges.gd")
manifest = read("tools/sera_ci_manifest.txt")

def hex_color(source: str, pattern: str) -> tuple[float, float, float]:
    found = re.search(pattern, source)
    assert found, f"Missing colour declaration: {pattern}"
    value = found.group(1).removeprefix("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def luminance(rgb: tuple[float, float, float]) -> float:
    components = [channel / 12.92 if channel <= 0.04045
                  else ((channel + 0.055) / 1.055) ** 2.4
                  for channel in rgb]
    return sum(a * b for a, b in zip(components, (0.2126, 0.7152, 0.0722)))

background = hex_color(palette, r'const SOLID_COLOR := Color\("(#[0-9A-Fa-f]{6})"\)')
grid = hex_color(palette, r'const GRID_COLOR := Color\("(#[0-9A-Fa-f]{6})"\)')
opacity_match = re.search(r'const GRID_OPACITY: float = ([0-9.]+)', palette)
assert opacity_match, "Missing grid opacity"
grid_opacity = float(opacity_match.group(1))
assert 0.0 < grid_opacity < 1.0
grid_composited = tuple(a * (1.0 - grid_opacity) + b * grid_opacity
                        for a, b in zip(background, grid))
sera_ink = hex_color(sera, r'set_shader_parameter\("ink_color", Color\("(#[0-9A-Fa-f]{6})"\)\)')
nexus_ink = hex_color(nexus, r'set_shader_parameter\("edge_tint", Color\("(#[0-9A-Fa-f]{6})"\)\)')
brightest_outline = max(luminance(sera_ink), luminance(nexus_ink))
for name, color in (("solid", background), ("composited grid", grid_composited)):
    assert luminance(color) > brightest_outline + 0.10, (
        f"{name} preview background must clearly exceed the brightest shader ink")
assert 'pixels.fill(SOLID_COLOR)' in palette
assert 'SOLID_COLOR.lerp(GRID_COLOR, GRID_OPACITY)' in palette
assert 'env.background_color = IconBackdrop.SOLID_COLOR' in viewer, (
    "Isolated full-body editor view must use the same preview palette")
assert 'IconBackdrop.texture(512, "grid")' in viewer
assert 'const EquipmentPreview = preload("res://tools/equipment_intake/godot_preview.gd")' in (
    read("scripts/sera_part_preview_widget.gd"))
assert "py tools/preview_backdrop_contrast_self_check.py" in manifest
print("SERA_PREVIEW_BACKDROP_CONTRAST_STATIC_OK")

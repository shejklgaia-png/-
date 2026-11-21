#!/usr/bin/env python3
"""SERA: authored clipped-corner equipment icon frames (not material icons)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bg = (ROOT / "scripts/sera_icon_background.gd").read_text(encoding="utf-8")
icons = (ROOT / "scripts/sera_item_icons.gd").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in [
    'const FRAME_MAIN := Color("#6F93A3")',
    'const FRAME_HIGHLIGHT := Color("#9FD7E6")',
    'const FRAME_SUB_OPACITY: float = 0.36',
    'static func draw_tech_frame(image: Image) -> void:',
    'static func _stroke_frame_segment(',
    'var cut: int =',
    'var thickness: int =',
    'draw_tech_frame(bg)',
]:
    assert token in bg, token
assert bg.index("bg.blend_rect(") < bg.index("draw_tech_frame(bg)") < bg.index(
    "ImageTexture.create_from_image(bg)"), "Frame must overlay composited art"
assert "IconBackground.composite(source)" in icons
assert "_presented_equipment_cache[blueprint_id] = presented" in icons
assert "return _material_frame(int(MATERIAL_INDICES[material_id]))" in icons, (
    "The new frame is for equipment only, not material icons"
)
assert "py tools/equipment_icon_tech_frame_self_check.py" in manifest
assert "gd tools/equipment_icon_tech_frame_runtime_check.gd" in manifest
print("SERA_EQUIPMENT_TECH_FRAME_STATIC_OK")

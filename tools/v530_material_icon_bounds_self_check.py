#!/usr/bin/env python3
"""Regression: every material sprite is independent 1:1 art, and every UI target clips."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
icons = (ROOT/"scripts/sera_item_icons.gd").read_text(encoding="utf-8")
grid = (ROOT/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
facility = (ROOT/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
runtime = (ROOT/"tools/v530_material_icon_bounds_runtime_check.gd").read_text(encoding="utf-8")
manifest = (ROOT/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "static var _material_frame_cache:" in icons
assert "get_region(Rect2i(" in icons, "crop sprite before uploading it to a GPU texture"
assert "ImageTexture.create_from_image(tile)" in icons
assert "icon.atlas = source" in icons, "original equipment atlas must stay supported"
assert "clip_contents = true" in grid
assert "art.clip_contents = true" in grid
assert "stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED" in grid
assert "card.clip_contents = true" in facility, "native material buttons must clip too"
assert "art.clip_contents = true" in facility, "conversion/detail previews must clip"
assert "func _check_image(" in runtime and "func _check_material_grid(" in runtime
assert "py tools/v530_material_icon_bounds_self_check.py" in manifest
assert "gd tools/v530_material_icon_bounds_runtime_check.gd" in manifest
print("SERA_V530_MATERIAL_ICON_BOUNDS_STATIC_PASS")

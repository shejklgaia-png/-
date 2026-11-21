#!/usr/bin/env python3
"""Irregular, gap-free SERA BASE floor plates: tests independent visual contract."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root/"scripts/base_exploration.gd").read_text(encoding="utf-8")
layout = (root/"scripts/sera_base_deck_layout.gd").read_text(encoding="utf-8")
floor = (root/"scripts/sera_base_floor_detail.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
legacy = (root/"tools/base_exploration_runtime_check.gd").read_text(encoding="utf-8")

assert 'const BaseDeckLayout = preload("res://scripts/sera_base_deck_layout.gd")' in hub
assert 'BaseDeckLayout.generate(PLATE_GRID_RADIUS_CELLS, PLATE_GRID_STEP)' in hub
assert 'BaseFloorDetail.decorate(floor, panels)' in hub
assert 'static func generate(' in layout
assert 'PackedByteArray' in layout and '_can_occupy(' in layout
assert 'var half_cell' not in hub, "do not fake random sizes with overlapping meshes"
assert 'Rect2(' in layout
assert 'GAP: float = 0.06' in layout
assert '0.5' in layout, "small subdivided plates are required"
assert '3' in layout, "long slabs must be represented"
assert 'var plate_mesh := BoxMesh.new()' in hub
assert 'plate_mesh.size = Vector3.ONE' in hub, "instance transforms must define individual panel dimensions"
assert 'Basis.IDENTITY.scaled_local(' in hub, "per-panel scale is required"
assert 'len(panels)' not in hub
assert 'for panel in panels:' in floor
assert 'PanelSeams' in floor and 'DeckBolts' in floor
assert '3.0m uniform grid' not in floor
assert 'grid_tiles < 3000' in legacy
assert 'grid_mesh.size != Vector3.ONE' in legacy
assert "py tools/base_uneven_deck_self_check.py" in ci
assert "gd tools/base_uneven_deck_runtime_check.gd" in ci
print("SERA_BASE_UNEVEN_DECK_STATIC_PASS")

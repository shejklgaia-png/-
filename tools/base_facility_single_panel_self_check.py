#!/usr/bin/env python3
"""Every active exterior facility must occupy one reserved floor slab, never multiple tiles."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root/"scripts/base_exploration.gd").read_text(encoding="utf-8")
layout = (root/"scripts/sera_base_deck_layout.gd").read_text(encoding="utf-8")
detail = (root/"scripts/sera_base_floor_detail.gd").read_text(encoding="utf-8")
fac = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "static func facility_sites(" in layout, "source-of-truth facility sites must be supplied to the tiler"
assert "BaseFacilities.FACILITY_SPECS" in hub
assert "NEXUS_BUILDING_ORIGIN" in hub
assert "BaseDeckLayout.facility_sites(" in hub
assert "PLATE_GRID_RADIUS_CELLS, PLATE_GRID_STEP, sites)" in hub
assert 'panel["site"]' in detail, "facility slabs must have a distinct detail treatment"
assert "if site_id.is_empty()" in detail, "no hatch or internal seam over an equipment slab"
assert 'site_id' in layout and '"site": site_id' in layout
assert 'PackedByteArray' in layout and '_can_occupy(' in layout
assert 'var site_occupancy := PackedByteArray()' in layout
assert "if site_occupancy[addr] != 0:" in layout, "overlapping site reservations must be rejected"
assert 'var cell_step: float = step * 0.5' in layout
assert 'Vector2(10.5, 10.5)' in layout, "NEXUS needs an oversized uninterrupted slab"
assert 'Vector2(7.0, 7.0)' in layout, "LABO must have a distinct spacious slab"
assert '"physical": physical' in layout, "equipment clearance must include physical footprint"
assert '"minimum": minimum' in layout, "each facility needs independently sized reserved slab"
assert 'return []' in layout, "reject conflicting reservations rather than overlapping"
assert "var occupied: PackedByteArray = site_occupancy.duplicate()" in layout
assert 'Color("#1e2326")' in hub, "charcoal floor contrast must not regress"
assert 'multi.instance_count = poses.size()' in hub, "preserve batched mobile rendering"
assert 'const FACILITY_SPECS = [' in fac
assert 'py tools/base_facility_single_panel_self_check.py' in ci
assert 'gd tools/base_facility_single_panel_runtime_check.gd' in ci
print("SERA_BASE_FACILITY_SINGLE_PANEL_STATIC_PASS")

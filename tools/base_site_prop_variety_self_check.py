#!/usr/bin/env python3
"""SERA BASE prop contract: eight different workspaces, no floor panel crossings."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
a = (r/"scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
clutter = (r/"scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
layout = (r/"scripts/sera_base_deck_layout.gd").read_text(encoding="utf-8")
hub = (r/"scripts/base_exploration.gd").read_text(encoding="utf-8")
ci = (r/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'const BaseClutter = preload("res://scripts/sera_base_clutter.gd")' in a
assert 'BaseClutter.decorate(g, "NEXUS")' in a
assert 'BaseClutter.decorate(g, key)' in a
assert clutter.count('static func ') >= 6
assert 'static func props_for(' in clutter
assert 'static func bounds_for(' in clutter
assert 'static func decorate(' in clutter
assert 'g.box(' in clutter and 'g.rod(' in clutter and 'g.ring(' in clutter
assert 'g.crate(' in clutter
for key in ("NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
            "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"):
    assert '"'+key+'" :' in clutter or '"'+key+'":' in clutter, key
assert 'RandomNumberGenerator' not in clutter and 'randi(' not in clutter, "static layouts must be stable"
assert 'MultiMeshInstance3D.new()' in a and 'g.flush()' in a, "reuse existing material batches"
assert 'var sites: Array[Dictionary] = BaseDeckLayout.facility_sites(' in hub
assert '"site": site_id' in layout, "props must stay inside the eight reserved single-panel slabs"
assert 'py tools/base_site_prop_variety_self_check.py' in ci
assert 'gd tools/base_site_prop_variety_runtime_check.gd' in ci
print("SERA_BASE_SITE_PROP_VARIETY_STATIC_PASS")

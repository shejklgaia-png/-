#!/usr/bin/env python3
"""BASE container detail must preserve footprint, scale, stacking and batched draw."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root / "scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "static func _make_container_stack(" in src
assert "static func container_plan_for(" in src
assert "var nominal: Vector2 = bounds_for(kind) * k" in src
assert 'g.crate(position, size, index + tier_index)' in src
for feature in ["YardContainerCornerLatch", "YardContainerFrontHandle", "YardContainerTopRidge"]:
    assert feature in src, feature
assert 'for tier_index in range(plan.size()):' in src
assert "MultiMeshInstance3D.new()" not in src
assert "py tools/base_container_detail_self_check.py" in ci
print("SERA_BASE_CONTAINER_DETAIL_STATIC_PASS")

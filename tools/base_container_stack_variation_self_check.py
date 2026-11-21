#!/usr/bin/env python3
"""Stable randomized container stacks: variable quantity, sizes and structural support."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root / "scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "static func stack_count_for(" in src
assert "static func container_plan_for(" in src
assert "static func _make_container_stack(" in src
assert "static func _stable_seed(" in src
assert 'var count: int = stack_count_for(key, kind, index)' in src
assert "var supports:" in src, "every upper item must name its support"
assert '"supports": supports' in src
assert "var size: Vector3" in src
assert "g.crate(" in src, "container mesh must be real, not a drawn icon"
assert "MultiMeshInstance3D.new()" not in src, "reuse existing facility material batches"
assert "randi(" not in src and "randomize()" not in src
assert "py tools/base_container_stack_variation_self_check.py" in ci
assert "gd tools/base_container_stack_variation_runtime_check.gd" in ci
print("SERA_BASE_CONTAINER_STACK_VARIATION_STATIC_PASS")

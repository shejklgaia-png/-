#!/usr/bin/env python3
"""SERA: actual 2-3 tier cargo stacks, deterministic and batched, on each BASE slab."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
clutter = (root / "scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "stack_count: int = 1" in clutter, "props should permit explicit 1-3 tiers"
assert 'stack_count' in clutter and '"stack": stack_count' in clutter
assert "class LiftedBatch:" in clutter, "stack instances must reuse the original material batches"
assert 'static func stack_pitch_for(' in clutter
assert 'static func layer_offset(' in clutter
assert 'static func _make_stacked(' in clutter
assert 'layers: int = clampi(stack_count, 1, 3)' in clutter
assert 'g.host.set_meta("clutter_props", props)' in clutter
assert 'BaseClutter.decorate(g, "NEXUS")' in arch
assert 'BaseClutter.decorate(g, key)' in arch
assert 'g.flush()' in arch and 'MultiMeshInstance3D.new()' in arch
assert 'RandomNumberGenerator' not in clutter and 'randi(' not in clutter
assert 'py tools/base_prop_stacks_self_check.py' in manifest
assert 'gd tools/base_prop_stacks_runtime_check.gd' in manifest
print("SERA_BASE_PROP_STACKS_STATIC_PASS")

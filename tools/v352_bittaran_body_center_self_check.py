#!/usr/bin/env python3
"""v352 Bittaran lock rays follow real BODY mesh X/Z, not boss root."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda path: (root/path).read_text(encoding="utf-8")
boss = read("scripts/bittaran_parts.gd")
assert 'func get_actor_parallel_lock_segments(actor_origin: Vector3,' in boss
assert 'get_body_hit_aabb().get_center() if installed else body_center' in boss
assert 'real_center.x, actor_origin.y, real_center.z' in boss
assert 'return super.get_actor_parallel_lock_segments(' in boss
assert 'var torso_center: Vector3' in boss
assert 'var line: Vector3 = torso_center - origin' in boss
generic = read("scripts/target_parts.gd")
assert 'const PARALLEL_LOCK_HALF_SPACING: float = 0.25' in generic
visual = read("scripts/main.gd")
assert '"get_actor_parallel_lock_segments",' in visual
print("PASS v352 BODY mesh center targeted, horizontal at SERA Y, shared unchanged")

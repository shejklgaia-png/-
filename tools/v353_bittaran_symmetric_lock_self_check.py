#!/usr/bin/env python3
"""v353 Bittaran lock changeover uses the midpoint between front/rear shin pairs."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parts=(root/"scripts/bittaran_parts.gd").read_text(encoding="utf-8")
required=[
'var lock_front_mid_local: Vector3',
'var lock_rear_mid_local: Vector3',
'func _calibrate_front_rear_lock_midpoint() -> void:',
'lock_front_mid_local = boss_model.to_local((fl + fr) * 0.5)',
'lock_rear_mid_local = boss_model.to_local((rl + rr) * 0.5)',
'func _lockable_shin_pair(origin: Vector3) -> Array[String]:',
'if relative.dot(front_axis) >= 0.0:',
'for id in _lockable_shin_pair(origin):',
'var pair: Array[String] = _lockable_shin_pair(origin)',
'get_body_hit_aabb().get_center() if installed else body_center',
'real_center.x, actor_origin.y, real_center.z'
]
for needle in required:
    assert needle in parts, needle
assert 'return super.select_actor_parallel_lines_part(origin, body_center)' in parts, "down logic unchanged"
print("PASS v353 symmetric front/rear shin midpoint, horizontal BODY rays preserved")

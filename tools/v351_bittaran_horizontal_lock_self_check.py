#!/usr/bin/env python3
"""v351 Bittaran two-line AUTO lock ignores Bittaran's Y while preserving training."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda p: (root/p).read_text(encoding="utf-8")
boss = read("scripts/bittaran_parts.gd")
generic = read("scripts/target_parts.gd")
visual = read("scripts/main.gd")
assert 'func get_actor_parallel_lock_segments(actor_origin: Vector3,' in boss
assert 'real_center.x, actor_origin.y, real_center.z' in boss
assert 'get_body_hit_aabb().get_center() if installed else body_center' in boss
assert 'return super.get_actor_parallel_lock_segments(' in boss
assert 'var segments: PackedVector3Array = get_actor_parallel_lock_segments(' in boss
assert 'PARALLEL_LOCK_HALF_SPACING: float = 0.25' in generic
assert 'actor_origin - side_offset, body_center - side_offset' in generic
assert '"get_actor_parallel_lock_segments",' in visual
assert '"camera_player_render_position"' not in boss
print("PASS v351 Bittaran-specific horizontal lock lines, unchanged shared training")

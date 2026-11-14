#!/usr/bin/env python3
"""Inherited v332 regression: lock-target front now overrides animated head."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
main=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
policy=(r/"scripts/flick_direction_policy.gd").read_text()
overlay=(r/"scripts/touch_overlay.gd").read_text()
# Preserve v332 visual-bone access for other rig consumers; v333 combat
# explicitly uses the currently LOCKED part instead of Head/Chest/Waist.
assert 'func get_visible_facing_pivot() -> Node3D:' in rig
assert 'func projected_lock_forward(' in policy
assert 'Vector3(lock_direction.x, 0.0, lock_direction.z)' in policy
assert 'func _projected_sera_facing() -> Vector2:' in main
axis=main.split('func _projected_sera_facing()',1)[1].split(
    'func _combo_normal_attack_ready()',1)[0]
assert '_locked_target_facing_direction()' in axis
assert '_current_lock_aim_world()' in axis
assert 'camera.unproject_position(aim) - _visual_torso_screen_point()' in axis
assert 'get_visible_facing_pivot' not in axis
assert main.count('gesture_screen_forward = _projected_sera_facing()') == 0
assert 'gesture_screen_forward = _touch_to_lock_forward(pos)' in main
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in main
assert 'flick_sector_forward.rotated(' in overlay
assert 'FLICK_SECTOR_FRONT_COLOR' in overlay and 'FLICK_SECTOR_SIDE_COLOR' in overlay
version=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert version and int(version.group(1)) >= 332
print("PASS v332 90deg sector consistency, updated v333 locked-target front")

#!/usr/bin/env python3
"""v332: controller sector and combat sectors use the rendered head, not just collision."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text()
rig=(root/"scripts/sera_rig.gd").read_text()
policy=(root/"scripts/flick_direction_policy.gd").read_text()
overlay=(root/"scripts/touch_overlay.gd").read_text()
assert 'func get_visible_facing_pivot() -> Node3D:' in rig
assert '[RUN_HEAD_BONE_UUID, RUN_CHEST_BONE_UUID, RUN_ROOT_BONE_UUID]' in rig
assert '-pivot.global_transform.basis.z' in rig
assert 'visual_pivot: Node3D = null' in policy
assert 'forward_world = visual_forward' in policy
assert 'func _projected_sera_facing() -> Vector2:' in main
assert 'rig.call("get_visible_facing_pivot") as Node3D' in main
assert 'return FLICK_DIRECTION_POLICY.projected_forward(' in main
assert main.count('gesture_screen_forward = _projected_sera_facing()') == 3
assert 'else _projected_sera_facing())' in main
assert 'gesture_screen_forward if frozen_axis' in main
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in main
assert 'flick_sector_forward.rotated(' in overlay
assert 'FLICK_SECTOR_FRONT_COLOR' in overlay and 'FLICK_SECTOR_SIDE_COLOR' in overlay
version=re.search(r'config/name="SERA v(\d+)"',(root/"project.godot").read_text())
assert version and int(version.group(1)) >= 332
print("PASS v332 rendered SERA facing drives guide and frozen action axis")

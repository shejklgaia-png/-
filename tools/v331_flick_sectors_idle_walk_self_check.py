#!/usr/bin/env python3
"""SERA v331 directional visual follows the same actor-facing policy as input;
idle->run performs a discrete landing entry and a blended exit."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
ui=(r/"scripts/touch_overlay.gd").read_text()
main=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
assert 'FLICK_SECTOR_COUNT: int = 4' in ui
assert 'FLICK_SECTOR_FRONT_COLOR: Color = Color(1.0, 0.22, 0.20' in ui
assert 'FLICK_SECTOR_SIDE_COLOR: Color = Color(1.0, 0.81, 0.19' in ui
assert 'func flick_sector_direction(sector: int) -> Vector2:' in ui
assert 'draw_colored_polygon(points, colors[sector])' in ui
assert 'FLICK_SECTOR_FOLLOW_RATE: float = 24.0' in ui
assert 'func set_flick_sector_forward(' in ui
assert 'flick_sector_forward.rotated(float(posmod(sector, FLICK_SECTOR_COUNT))' in ui
assert 'gesture_screen_forward if frozen_axis' in main
assert 'FLICK_DIRECTION_POLICY.projected_forward(camera, player)' in main
assert 'touch_ui.call("set_flick_sector_forward", gesture_screen_forward, 0.0, true)' in main
assert 'touch_ui.call("set_flick_sector_forward", facing, delta, frozen_axis)' in main
assert 'WAIT_RUN_LANDING_SECONDS: float = 0.20' in rig
assert 'WAIT_RUN_EXIT_BLEND_SECONDS: float = 0.11' in rig
assert 'if current_clip == WAIT_CLIP and wanted == RUN_CLIP' in rig
assert '_switch_clip(JUMP_CLIP, 0.0)' in rig
assert 'clip_time = JUMP_AIR_CLIP_END' in rig
assert 'wait_to_run_landing_elapsed + maxf(delta, 0.0)' in rig
assert 'clip_time = lerpf(JUMP_AIR_CLIP_END, JUMP_LANDING_CLIP_END,' in rig
assert '_switch_clip(RUN_CLIP, WAIT_RUN_EXIT_BLEND_SECONDS)' in rig
assert '(landing_pose_active or wait_to_run_landing_active)' in rig
version=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert version and int(version.group(1))>=331
print("PASS v331 actor-relative colored sectors and WAIT->landing->RUN transitions")

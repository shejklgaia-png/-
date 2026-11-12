#!/usr/bin/env python3
"""v257 legacy reticle requirement reverted in v258; reticle UI stays intact."""
from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd");hud=read("scripts/touch_overlay.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=258
assert (R/"README_v257_ja.md").exists()
assert 'func _flick_front_from_controller_origin(' not in m
assert "toward_lock_marker" not in p
assert "touch_ui.get(\"target_marker_position\")" not in m
assert "touch_ui.get(\"target_marker_visible\")" not in m
assert "var target_marker_position: Vector2 = Vector2.ZERO" in hud
assert "var target_marker_visible: bool = false" in hud
# v291 extends projection with an explicit offscreen-edge marker.
assert "func set_target_marker_projection(screen_position: Vector2," in hud
assert "is_offscreen: bool = false)" in hud
assert 'touch_ui.call("set_target_marker_projection", safe_screen, true, is_offscreen)' in m
begin=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=m.split("func _classify_step_flick(",1)[1].split("func _start_omni_step(",1)[0]
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in begin
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in release
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in step
assert "const SECTOR_COUNT: int = 4" in p
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in m
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
print("PASS v257/v258: lock marker remains visual; flick front no longer reads marker/controller")

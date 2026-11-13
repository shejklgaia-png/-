#!/usr/bin/env python3
"""v257 legacy reticle requirement reverted in v258; reticle UI stays intact."""
from pathlib import Path

# v317: lock projections reside in the canonical delegated module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")

# v317 relocated pure math: validate the actual new code and main.gd facade.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
SERA_MOVEMENT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_movement_math.gd").read_text(encoding="utf-8")
import re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd");hud=read("scripts/touch_overlay.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=258
assert (R/"docs/history/release_notes/README_v257_ja.md").exists()
assert 'func _flick_front_from_controller_origin(' not in m
assert "toward_lock_marker" not in p
assert "touch_ui.get(\"target_marker_position\")" not in m
assert "touch_ui.get(\"target_marker_visible\")" not in m
assert "var target_marker_position: Vector2 = Vector2.ZERO" in hud
assert "var target_marker_visible: bool = false" in hud
# v291 extends projection with an explicit offscreen-edge marker.
assert "func set_target_marker_projection(screen_position: Vector2," in hud
assert "is_offscreen: bool = false)" in hud
assert 'LOCK_MANAGEMENT.reticle_projection(' in m
assert 'marker["position"], true, marker["offscreen"]' in m
assert '"offscreen": is_offscreen' in LOCK_MODULE
begin=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=m.split("func _classify_step_flick(",1)[1].split("func _start_omni_step(",1)[0]
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in begin
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in release
assert "INPUT_GESTURES.step_flick(" in step
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in SERA_INPUT
assert "const SECTOR_COUNT: int = 4" in p
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in m
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
print("PASS v257/v258: lock marker remains visual; flick front no longer reads marker/controller")

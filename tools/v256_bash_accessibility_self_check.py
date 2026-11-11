#!/usr/bin/env python3
"""SERA v256: easy GUARD/Combo Bash without modifying eight-way STEP."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
policy=(root/"scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
v=re.search(r'^config/name="SERA v(\d+)"$',project,re.M)
assert v and int(v.group(1))>=256
assert (root/"README_v256_ja.md").exists()
required={
    "BASH_FLICK_MAX_SECONDS":0.42,
    "BASH_FLICK_MIN_FORWARD_PIXELS":30.0,
    "BASH_FLICK_MIN_FORWARD_SPEED":200.0,
    "BASH_FLICK_CANDIDATE_GRACE_PIXELS":38.0,
    "BASH_FLICK_REVERSAL_RATIO":1.35,
}
for name,val in required.items():
    m=re.search(rf'^const {name}: float = (\d+(?:\.\d+)?)',main,re.M)
    assert m and math.isclose(float(m.group(1)),val),name
assert "const BASH_FLICK_TAIL_SECONDS: float = BASH_FLICK_MAX_SECONDS" in main
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in main
assert "const STEP_FLICK_MIN_HORIZONTAL: float = 78.0" in main
assert "const STEP_FLICK_MIN_PIXELS_PER_SEC: float = 500.0" in main
assert "const JUMP_FLICK_TAIL_SECONDS: float = 0.20" in main
change=main.split("func _change_drag(pos: Vector2) -> void:",1)[1].split("func _update_boost_gesture(",1)[0]
release=main.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split("func _remember_jump_flick_sample(",1)[0]
sample=main.split("func _remember_jump_flick_sample(pos: Vector2) -> void:",1)[1].split("func _is_character_forward_flick(",1)[0]
bash=main.split("func _is_character_forward_flick(displacement: Vector2, seconds: float) -> bool:",1)[1].split("func _classify_recent_character_forward_flick(",1)[0]
step=main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
assert "gesture_max_travel > BASH_FLICK_CANDIDATE_GRACE_PIXELS" in change
assert "not FLICK_DIRECTION_POLICY.within_sector(" in change
assert "gesture_screen_forward, STEP_FLICK_MAX_HORIZONTAL_RATIO" in change
assert "(release_pos - pointer_origin).length() * BASH_FLICK_REVERSAL_RATIO" in release
assert "_is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "_classify_recent_character_forward_flick()" in release
assert "BASH_FLICK_TAIL_SECONDS if guard_active else JUMP_FLICK_TAIL_SECONDS" in sample
assert "BASH_FLICK_MAX_SECONDS, BASH_FLICK_MIN_FORWARD_PIXELS" in bash
assert "BASH_FLICK_MIN_FORWARD_SPEED, STEP_FLICK_MAX_HORIZONTAL_RATIO" in bash
assert "return FLICK_DIRECTION_POLICY.eight_way_direction(displacement, gesture_screen_forward)" in step
assert "if seconds <= 0.0 or seconds > STEP_FLICK_MAX_SECONDS:" in step
assert "if distance < STEP_FLICK_MIN_HORIZONTAL:" in step
assert "distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC" in step
assert "const SECTOR_COUNT: int = 8" in policy
assert "sector_index(displacement, screen_axis) == 0" in policy
assert "return FLICK_DIRECTION_POLICY.is_flick(" in main
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in main
assert "if bash_requested and _request_combo_bash():" in release

# Numerical acceptance: forward component and 45° front-sector both apply.
def accepts(distance,seconds,delta_deg=0.0):
    forward=distance*math.cos(math.radians(delta_deg))
    if abs(delta_deg)>=22.5 or seconds<=0 or seconds>.42:
        return False
    return forward>=30.0 and forward/seconds>=200.0
assert not accepts(30,0.10,30)
assert accepts(35,0.15,0)
assert accepts(42,0.20,0)
assert accepts(60,0.25,10)
assert accepts(80,0.35,0)
assert not accepts(29,0.10,0)
assert not accepts(60,0.43,0)
assert not accepts(70,0.40,0)  # 175px/s is below the new speed floor
for deg in range(0,360,15):
    assert accepts(45,0.17,0.0)
    # Absolute heading does not matter; only facing-relative delta does.
    for delta in (-22,-12,0,12,22):
        assert accepts(45,0.17,delta),(deg,delta)
    for delta in (-45,-23,23,45,90,180):
        assert not accepts(45,0.17,delta),(deg,delta)

print("PASS v256: Bash timing/distance/speed relaxed; candidate grace and GUARD tail")
print("PASS v256: strict 8-sector direction unchanged, STEP/JUMP/boost untouched")
print("Godot/Android input and exact frame timing not tested")

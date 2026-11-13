#!/usr/bin/env python3
"""v255 regression updated to v258 single character-facing 4-way axis."""
from pathlib import Path

# v317 relocated pure math: validate the actual new code and main.gd facade.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
SERA_MOVEMENT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_movement_math.gd").read_text(encoding="utf-8")
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=258
assert (R/"README_v255_ja.md").exists()
begin=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
drag=m.split("func _change_drag(",1)[1].split("func _update_boost_gesture(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=m.split("func _classify_step_flick(",1)[1].split("func _start_omni_step(",1)[0]
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in begin
assert "guard_flick_axis_captured = false" in begin
assert "if not guard_flick_axis_captured and pos.distance_to(pointer_origin) >= TAP_MAX_TRAVEL:" in drag
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in drag
assert "guard_flick_axis_captured = true" in drag
assert "if not guard_flick_axis_captured:" in release
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in release
assert "INPUT_GESTURES.step_flick(" in step
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in SERA_INPUT
assert "FLICK_DIRECTION_POLICY.within_sector(" in drag
# v284 Bash candidate uses fixed screen-UP 90-degree sector.
assert "displacement, Vector2.UP, STEP_FLICK_MAX_HORIZONTAL_RATIO" in drag
assert "_classify_recent_character_forward_flick()" in release
assert "_is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
assert "const SECTOR_COUNT: int = 4" in p
assert "static func sector_index(" in p
assert "sector_index(displacement, screen_axis) == 0" in p
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
assert "_screen_drag_to_ground(direction_input)" in m
def sector(v,axis):
    theta=math.atan2(v[0]*(-axis[1])+v[1]*axis[0],v[0]*axis[0]+v[1]*axis[1])
    return math.floor((theta+math.pi/4)/(math.pi/2))%4
for deg in range(0,360,5):
    a=math.radians(deg);axis=(math.sin(a),-math.cos(a))
    assert sector(axis,axis)==0
    assert sector((-axis[0],-axis[1]),axis)==2
    for i in range(4):
        t=a+i*math.pi/2
        assert sector((math.sin(t),-math.cos(t)),axis)==i
    for delta in (-44,-20,0,20,44):
        t=a+math.radians(delta)
        assert sector((math.sin(t),-math.cos(t)),axis)==0
    for delta in (-91,-46,46,91):
        t=a+math.radians(delta)
        assert sector((math.sin(t),-math.cos(t)),axis)!=0
print("PASS v255/v258: STEP and Bash use the same projected character axis, four quadrants")

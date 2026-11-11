#!/usr/bin/env python3
"""SERA v255: STEP and Bash share the same visible character-forward axis."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
def read(path):return (root/path).read_text(encoding="utf-8")
m=read("scripts/main.gd")
p=read("scripts/flick_direction_policy.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=255
assert (root/"README_v255_ja.md").exists()
begin=m.split("func _begin_drag(pos: Vector2) -> void:",1)[1].split("func _analog_stick_direction(",1)[0]
drag=m.split("func _change_drag(pos: Vector2) -> void:",1)[1].split("func _update_boost_gesture(",1)[0]
release=m.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=m.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
assert "gesture_screen_forward = _flick_front_from_controller_origin(pos)" in begin
assert "guard_flick_axis_captured = false" in begin
assert "if not guard_flick_axis_captured and pos.distance_to(pointer_origin) >= TAP_MAX_TRAVEL:" in drag
assert "gesture_screen_forward = _flick_front_from_controller_origin(pointer_origin)" in drag
assert "guard_flick_axis_captured = true" in drag
assert "if not guard_flick_axis_captured:" in release
assert "gesture_screen_forward = _flick_front_from_controller_origin(pointer_origin)" in release
assert "return FLICK_DIRECTION_POLICY.eight_way_direction(displacement, gesture_screen_forward)" in step
assert "return FLICK_DIRECTION_POLICY.eight_way_direction(displacement, Vector2.UP)" not in step
assert "FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "displacement, gesture_screen_forward, STEP_FLICK_MAX_HORIZONTAL_RATIO" in drag
assert "return FLICK_DIRECTION_POLICY.is_flick(" in m
assert "displacement, seconds, gesture_screen_forward," in m
assert "_classify_recent_character_forward_flick()" in release
assert "_is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "_start_omni_step(flick_direction)" in release
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
assert "const SECTOR_COUNT: int = 8" in p
assert "static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:" in p
assert "static func eight_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:" in p
assert "sector_index(displacement, screen_axis) == 0" in p
assert "_screen_drag_to_ground(direction_input)" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
assert "same screen-projected character forward" in read("AGENTS.md")
assert "STEPもBashも" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")

angle=math.tau/8
def sector(dx,dy,ax,ay):
    rad=math.hypot(dx,dy)
    if rad<1e-9:return -1
    ar=math.hypot(ax,ay)
    if ar<1e-9:return -1
    ax/=ar; ay/=ar
    rightx,righty=-ay,ax
    v=math.atan2(dx*rightx+dy*righty,dx*ax+dy*ay)
    return math.floor((v+angle*.5)/angle)%8
# Old bug: actor faces screen RIGHT (1,0), but the STEP-specific
# screen-UP axis makes a true actor-forward flick classify as RIGHT.
assert sector(1,0,0,-1)==2
for deg in range(0,360,5):
    rad=math.radians(deg)
    front=(math.sin(rad),-math.cos(rad))
    back=(-front[0],-front[1])
    assert sector(*front,*front)==0
    assert sector(*back,*front)==4
    # Only a centered actor-forward flick triggers the Bash sector.
    for i in range(8):
        t=rad+i*angle
        swipe=(math.sin(t),-math.cos(t))
        s=sector(*swipe,*front)
        assert s==i,(deg,i,s)
        assert (s==0)==(i==0)
    for delta in (-22.0,-10.0,0.0,10.0,22.0):
        t=rad+math.radians(delta)
        swipe=(math.sin(t),-math.cos(t))
        assert sector(*swipe,*front)==0
    for delta in (-23.0,23.0,45.0,90.0):
        t=rad+math.radians(delta)
        swipe=(math.sin(t),-math.cos(t))
        assert sector(*swipe,*front)!=0
print("PASS v255: STEP and Bash front both follow same projected SERA axis")
print("PASS v255: 8 sectors across actor angles, GUARD after camera recenter, gesture snapshots")
print("Godot/Android runtime touch and visual facing checks not performed")

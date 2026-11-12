#!/usr/bin/env python3
"""v253 regression, updated for v258 SERA-facing 4-way Bash."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=258
assert (R/"README_v253_ja.md").is_file()
begin=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
drag=m.split("func _change_drag(",1)[1].split("func _update_boost_gesture(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
classify=m.split("func _is_character_forward_flick(",1)[1].split("func _is_upward_jump_flick(",1)[0]
assert 'gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)' in begin
assert "var gesture_screen_forward: Vector2 = Vector2.UP" in m
assert "not FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "displacement, Vector2.UP, STEP_FLICK_MAX_HORIZONTAL_RATIO" in drag
assert "var guard_bash_requested: bool = _classify_recent_character_forward_flick()" in release
assert "and _is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "if bash_requested and _request_combo_bash():" in release
assert "return FLICK_DIRECTION_POLICY.is_flick(" in classify
assert "BASH_FLICK_MAX_SECONDS, BASH_FLICK_MIN_FORWARD_PIXELS" in classify
assert "BASH_FLICK_MIN_FORWARD_SPEED, STEP_FLICK_MAX_HORIZONTAL_RATIO" in classify
assert "return _is_character_forward_flick(" in classify
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
for term in ("static func projected_forward(", "-actor.global_transform.basis.z",
            "camera.unproject_position(to_world) - camera.unproject_position(from_world)",
            "static func within_sector(", "static func is_flick(",
            "sector_index(displacement, screen_axis) == 0"):
    assert term in p,term
# The previous 0.42 lateral ratio may NOT restrict the 90-degree sector.
front=(0.,-1.)
def sector(v,axis):
    dot=v[0]*axis[0]+v[1]*axis[1]
    right=(-axis[1],axis[0])
    theta=math.atan2(v[0]*right[0]+v[1]*right[1],dot)
    return math.floor((theta+math.pi/4)/(math.pi/2))%4
for angle in (-44,-30,-1,0,1,30,44):
    d=(math.sin(math.radians(angle)),-math.cos(math.radians(angle)))
    assert sector(d,front)==0
for angle in (-100,-46,46,100,180):
    d=(math.sin(math.radians(angle)),-math.cos(math.radians(angle)))
    assert sector(d,front)!=0
print("PASS v253/v258: Guard and combo Bash share character-forward 90-degree sector")
print("Android/Godot runtime not tested")

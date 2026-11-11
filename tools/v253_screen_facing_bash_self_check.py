#!/usr/bin/env python3
"""v253: projected character-facing Bash on guard and combo, reusable flick rules."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text(encoding="utf-8")
m=read("scripts/main.gd")
p=read("scripts/flick_direction_policy.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=253
assert (ROOT/"README_v253_ja.md").is_file()
assert "Mandatory future flick control convention" in read("AGENTS.md")
assert "今後の全方向フリック" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
assert 'preload("res://scripts/flick_direction_policy.gd")' in m
assert "var gesture_screen_forward: Vector2 = Vector2.UP" in m
start=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
drag=m.split("func _change_drag(",1)[1].split("func _update_boost_gesture(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
classifier=m.split("func _is_character_forward_flick(",1)[1].split("func _is_upward_jump_flick(",1)[0]
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in start
assert start.index("gesture_screen_forward =") < start.index("bash_flick_candidate =")
assert "not FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "displacement, gesture_screen_forward, STEP_FLICK_MAX_HORIZONTAL_RATIO" in drag
assert "displacement.y >= 0.0" not in drag
assert "var guard_bash_requested: bool = _classify_recent_character_forward_flick()" in release
assert "and _is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert 'if guard_bash_requested:' in release and '_start_bash()' in release
assert 'if bash_requested and _request_combo_bash():' in release
assert "func _classify_recent_character_forward_flick() -> bool:" in m
assert "return FLICK_DIRECTION_POLICY.is_flick(" in classifier
assert "STEP_FLICK_MAX_SECONDS, JUMP_FLICK_MIN_VERTICAL" in classifier
assert "STEP_FLICK_MIN_PIXELS_PER_SEC, STEP_FLICK_MAX_HORIZONTAL_RATIO" in classifier
assert "return _is_character_forward_flick(" in classifier
assert 'and _is_upward_jump_flick(release_pos - pointer_origin, press_duration)' in release
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
assert "step_linear_fallback = true" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
for s in ("static func projected_forward(camera: Camera3D, actor: Node3D) -> Vector2:",
          "-actor.global_transform.basis.z", "forward_world.y = 0.0",
          "camera.unproject_position(to_world) - camera.unproject_position(from_world)",
          "static func within_sector(", "displacement.dot(axis)",
          "absf(displacement.cross(axis))",
          "static func is_flick(", "forward_amount / seconds >= min_forward_speed"):
    assert s in p,s

def sector(move,axis,ratio=.42):
    norm=math.hypot(*axis)
    if norm<1e-7:return False
    x,y=axis[0]/norm,axis[1]/norm
    f=move[0]*x+move[1]*y
    side=abs(move[0]*y-move[1]*x)
    return f>0 and side<=f*ratio

def accept(move,axis,seconds=.10):
    if seconds<=0 or seconds>.24 or not sector(move,axis):return False
    norm=math.hypot(*axis)
    f=(move[0]*axis[0]+move[1]*axis[1])/norm
    return f>=50 and f/seconds>=500

axes=[(1,0),(-1,0),(0,1),(0,-1)]
axes +=[(math.cos(a),math.sin(a)) for a in (math.pi/4,math.pi/3,2*math.pi/3,5*math.pi/4,7*math.pi/4)]
for x,y in axes:
    assert accept((90*x,90*y),(x,y))
    assert not accept((-90*x,-90*y),(x,y))
    assert not accept((-90*y,90*x),(x,y))
    assert not accept((49*x,49*y),(x,y))
    assert not accept((90*x,90*y),(x,y),seconds=.25)
    assert not accept((55*x,55*y),(x,y),seconds=.20)
    assert accept((90*x-37*y,90*y+37*x),(x,y))
    assert not accept((90*x-39*y,90*y+39*x),(x,y))
assert accept((0,90),(0,1)) and not accept((0,-90),(0,1))
assert accept((90,0),(1,0)) and not accept((0,-90),(1,0))
print("PASS v253: screen-facing Bash from Guard and combo, unified candidate/release")
print("PASS v253: 360-degree angles/timing/speed; future flick rule codified")
print("Godot parser and Android touch/camera acceptance not tested")

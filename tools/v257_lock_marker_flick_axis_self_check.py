#!/usr/bin/env python3
"""SERA v257: flick forward follows the displayed lock reticle from touch origin."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text(encoding="utf-8")
main=read("scripts/main.gd")
policy=read("scripts/flick_direction_policy.gd")
hud=read("scripts/touch_overlay.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=257
assert (ROOT/"README_v257_ja.md").is_file()
assert "controller origin → lock marker" in read("AGENTS.md")
assert "コントローラ発生位置からロックマーカー" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
helper=main.split("func _flick_front_from_controller_origin(controller_origin: Vector2) -> Vector2:",1)[1].split("func _begin_drag(",1)[0]
assert 'touch_ui.get("target_marker_visible")' in helper
assert 'touch_ui.get("target_marker_position")' in helper
assert 'var fallback: Vector2 = FLICK_DIRECTION_POLICY.projected_forward(camera, player)' in helper
assert 'FLICK_DIRECTION_POLICY.toward_lock_marker(' in helper
assert "controller_origin, marker_position, fallback)" in helper
assert "var target_marker_position: Vector2 = Vector2.ZERO" in hud
assert "var target_marker_visible: bool = false" in hud
assert "func set_target_marker_projection(screen_position: Vector2, is_visible: bool) -> void:" in hud
assert 'touch_ui.call("set_target_marker_projection", screen_position, on_screen)' in main
start=main.split("func _begin_drag(pos: Vector2) -> void:",1)[1].split("func _analog_stick_direction(",1)[0]
drag=main.split("func _change_drag(pos: Vector2) -> void:",1)[1].split("func _update_boost_gesture(",1)[0]
release=main.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
assert 'gesture_screen_forward = _flick_front_from_controller_origin(pos)' in start
assert "guard_flick_axis_captured = false" in start
assert 'gesture_screen_forward = _flick_front_from_controller_origin(pointer_origin)' in drag
assert 'guard_flick_axis_captured = true' in drag
assert 'if not guard_flick_axis_captured:' in release
assert 'gesture_screen_forward = _flick_front_from_controller_origin(pointer_origin)' in release
assert "return FLICK_DIRECTION_POLICY.eight_way_direction(displacement, gesture_screen_forward)" in step
assert "FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "displacement, gesture_screen_forward, STEP_FLICK_MAX_HORIZONTAL_RATIO" in drag
assert "FLICK_DIRECTION_POLICY.is_flick(" in main
assert "displacement, seconds, gesture_screen_forward," in main
assert "_is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "_classify_recent_character_forward_flick()" in release
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in main
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in main
assert "const SECTOR_COUNT: int = 8" in policy
assert "static func toward_lock_marker(controller_origin: Vector2," in policy
assert "var toward: Vector2 = marker_screen_position - controller_origin" in policy
assert "return toward.normalized()" in policy
assert "return fallback.normalized()" in policy
assert "static func sector_index(" in policy
assert "sector_index(displacement, screen_axis) == 0" in policy
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in main

def marker_axis(origin,marker,fallback=(0.,-1.)):
    dx,dy=marker[0]-origin[0],marker[1]-origin[1]
    l=math.hypot(dx,dy)
    if l>.01:return dx/l,dy/l
    fl=math.hypot(*fallback)
    return (fallback[0]/fl,fallback[1]/fl) if fl>1e-6 else (0.,-1.)

def sector(d,axis):
    if math.hypot(*d)<1e-6:return -1
    right=(-axis[1],axis[0])
    a=math.atan2(d[0]*right[0]+d[1]*right[1],d[0]*axis[0]+d[1]*axis[1])
    return math.floor((a+math.tau/16)/(math.tau/8))%8

# Same visible marker can be above, left, right or below a controller
# depending on touch-start coordinates. Direction is not camera-dependent.
cases=[
    ((600,1050),(360,440)),
    ((200,440),(620,440)),
    ((620,440),(180,440)),
    ((360,330),(360,900)),
    ((360,900),(360,330)),
    ((90,900),(620,330)),
    ((610,850),(140,260)),
]
for origin,marker in cases:
    front=marker_axis(origin,marker)
    assert sector(front,front)==0
    assert sector((-front[0],-front[1]),front)==4
    for i in range(8):
        t=math.tau/8*i
        d=(front[0]*math.cos(t)-front[1]*math.sin(t),
           front[0]*math.sin(t)+front[1]*math.cos(t))
        assert sector(d,front)==i,(origin,marker,i,sector(d,front))
    # Position-dependent forward, and absolute screen-UP need not match.
    dx,dy=marker[0]-origin[0],marker[1]-origin[1]
    assert math.isclose(front[0],dx/math.hypot(dx,dy),abs_tol=1e-10)
    assert math.isclose(front[1],dy/math.hypot(dx,dy),abs_tol=1e-10)
assert marker_axis((200,440),(620,440))==(1.,0.)
assert marker_axis((620,440),(180,440))==(-1.,0.)
assert marker_axis((110,220),(110,220),fallback=(0,1))==(0.,1.)
assert marker_axis((110,220),(110,220),fallback=(0,0))==(0.,-1.)
print("PASS v257: controller touch origin -> exact visible lock reticle, eight 45-degree sectors")
print("PASS v257: GUARD reticle resample, STEP and Bash unified, safe hidden/overlap fallback")
print("Godot editor and Android touch/reticle positioning not exercised")

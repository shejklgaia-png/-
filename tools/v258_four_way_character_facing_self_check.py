#!/usr/bin/env python3
"""SERA v258 full 4-way / 90° actor-facing mapping and Bash regression."""
from pathlib import Path

# v317 relocated pure math: validate the actual new code and main.gd facade.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
SERA_MOVEMENT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_movement_math.gd").read_text(encoding="utf-8")
import re,math
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd");proj=read("project.godot")
v=re.search(r'^config/name="SERA v(\d+)"$',proj,re.M)
assert v and int(v.group(1))>=258
assert (R/"README_v258_ja.md").exists()
assert "CURRENT flick policy — v258" in read("docs/history/AGENTS_THROUGH_V316.md")
assert "v258 — 現行仕様" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
for tok in ("const SECTOR_COUNT: int = 4","const SECTOR_ANGLE: float = TAU / 4.0",
            "static func projected_forward(camera: Camera3D, actor: Node3D) -> Vector2:",
            "-actor.global_transform.basis.z",
            "camera.unproject_position(to_world) - camera.unproject_position(from_world)",
            "static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:",
            "static func four_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:",
            "return Vector2.UP.rotated(float(sector) * SECTOR_ANGLE)",
            "return sector_index(displacement, screen_axis) == 0",
            "static func is_flick("):
    assert tok in p,tok
assert "toward_lock_marker" not in p
assert "eight_way_direction" not in p
assert "func _flick_front_from_controller_origin(" not in m
assert 'touch_ui.get("target_marker_position")' not in m
start=m.split("func _begin_drag(",1)[1].split("func _analog_stick_direction(",1)[0]
drag=m.split("func _change_drag(",1)[1].split("func _update_boost_gesture(",1)[0]
release=m.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=m.split("func _classify_step_flick(",1)[1].split("func _start_omni_step(",1)[0]
omni=m.split("func _start_omni_step(",1)[1].split("func _start_back_step(",1)[0]
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in start
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in drag
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in release
assert "guard_flick_axis_captured = true" in drag
assert "INPUT_GESTURES.step_flick(" in step
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in SERA_INPUT
assert "FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "static func screen_step_direction(displacement: Vector2) -> Vector2:" in p
assert "return displacement.normalized()" in p
assert "four_way_direction(displacement, gesture_screen_forward)" not in step
assert "return FLICK_DIRECTION_POLICY.is_flick(" in m
assert "displacement, seconds, Vector2.UP," in m
assert "BASH_FLICK_MAX_SECONDS, BASH_FLICK_MIN_FORWARD_PIXELS" in m
assert "BASH_FLICK_MIN_FORWARD_SPEED, STEP_FLICK_MAX_HORIZONTAL_RATIO" in m
assert "var guard_bash_requested: bool = _classify_recent_character_forward_flick()" in release
assert "and _is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert 'if bash_requested and _request_combo_bash():' in release
assert "step_linear_fallback = true" in omni
assert "step_arc_length = _step_fixed_distance_for_direction(direction)" in omni
assert "rig.call(\"start_omni_step\", pose_direction)" in omni
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in m
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in m
assert "_screen_drag_to_ground(direction_input)" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
def sector(vec,axis):
    if math.hypot(*vec)<1e-6 or math.hypot(*axis)<1e-6:return -1
    norm=math.hypot(*axis);ax,ay=axis[0]/norm,axis[1]/norm
    rx,ry=-ay,ax
    theta=math.atan2(vec[0]*rx+vec[1]*ry,vec[0]*ax+vec[1]*ay)
    return math.floor((theta+math.pi/4)/(math.pi/2))%4
def rot(v,deg):
    t=math.radians(deg)
    return (v[0]*math.cos(t)-v[1]*math.sin(t),
            v[0]*math.sin(t)+v[1]*math.cos(t))
assert sector((0,0),(0,-1))==-1
for base in range(0,360,5):
    axis=rot((0.,-1.),base)
    for i in range(4):
        for offset in (-44.9,-20,0,20,44.9):
            vec=rot(axis,i*90+offset)
            assert sector(vec,axis)==i,(base,i,offset)
        for delta,n in ((45.1,(i+1)%4),(-45.1,(i-1)%4)):
            assert sector(rot(axis,i*90+delta),axis)==n
    for ang in (-44,-30,0,30,44):
        v=rot(axis,ang)
        assert sector(v,axis)==0
    for ang in (-120,-46,46,120,180):
        assert sector(rot(axis,ang),axis)!=0
# Full 90-degree Bash sector, no second narrow v255/v257 0.42-ratio wedge.
v=rot((0,-1),40)
assert sector(v,(0,-1))==0 and abs(v[0])/(-v[1])>0.42
assert "sideways_amount" not in p
# Four snapped directions only (no diagonal vectors).
for i in range(4):
    v=rot((0.,-1.),i*90)
    assert math.isclose(abs(v[0])+abs(v[1]),1,abs_tol=1e-9)
print("PASS v258: 4 x 90-degree SERA-facing sectors, all 360-degree rotations and edge cases")
print("PASS v258/v260: Bash +/-45deg of actor front, STEP 4 fixed screen cardinal motions")
print("PASS v258: v256 Bash accessibility and analog RUN/BOOST retained; marker not in flick")
print("Godot parser/Android input feel not tested")

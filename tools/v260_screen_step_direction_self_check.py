#!/usr/bin/env python3
"""SERA v260: STEP gestures stay screen-cardinal regardless of actor/camera yaw."""
from pathlib import Path
import math
import re

R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
main=read("scripts/main.gd")
policy=read("scripts/flick_direction_policy.gd")
project=read("project.godot")
v=re.search(r'^config/name="SERA v(\d+)"$',project,re.M)
assert v and int(v.group(1)) >= 260
assert (R/"README_v260_ja.md").is_file()
assert "v260 STEP screen-cardinal direction fixes" in read("AGENTS.md")
assert "v260 — STEPフリック" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
assert "const SECTOR_COUNT: int = 4" in policy
assert "const SECTOR_ANGLE: float = TAU / 4.0" in policy
assert "static func screen_step_direction(displacement: Vector2) -> Vector2:" in policy
assert "return displacement.normalized()" in policy
assert "static func four_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:" in policy

start=main.split("func _begin_drag(pos: Vector2) -> void:",1)[1].split("func _analog_stick_direction(",1)[0]
guard=main.split("func _change_drag(pos: Vector2) -> void:",1)[1].split("func _update_boost_gesture(",1)[0]
release=main.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split("func _remember_jump_flick_sample(",1)[0]
step=main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _classify_combo_kick_flick(",1)[0]
motion=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
bash=main.split("func _is_character_forward_flick(",1)[1].split("func _is_upward_jump_flick(",1)[0]
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in step
assert "gesture_screen_forward" not in step  # no camera-dependent step reclassification
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in start
# v284 Bash, like STEP and kick inputs, uses screen-space classification.
assert "displacement, Vector2.UP, STEP_FLICK_MAX_HORIZONTAL_RATIO" in guard
assert "return FLICK_DIRECTION_POLICY.is_flick(" in bash
assert "displacement, seconds, gesture_screen_forward," in bash
assert "var guard_bash_requested: bool = _classify_recent_character_forward_flick()" in release
assert "and _is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "if bash_requested and _request_combo_bash():" in release
assert "if _start_omni_step(flick_direction):" in release
assert "var direction: Vector2 = flick.normalized()" in motion
assert "STEP_FORWARD_DISTANCE, BACK_STEP_DISTANCE, back_mix" in motion
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in motion
assert "rig.call(\"start_omni_step\", pose_direction)" in motion
assert "const STEP_FLICK_MIN_HORIZONTAL: float = 78.0" in main
assert "const STEP_FLICK_MAX_SECONDS: float = 0.24" in main
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in main
assert "not _combo_followup_input_window_open()" in main
assert "_cancel_combo_followup_windows_for_movement()" in motion

# Mirror Godot's sector formula in screen pixels (Y increases down).
def classify(flick,axis):
    dx,dy=flick
    ax,ay=axis
    if math.hypot(dx,dy)<1e-6:return -1
    if math.hypot(ax,ay)<1e-6:return -1
    norm=math.hypot(ax,ay);ax/=norm;ay/=norm
    right=(-ay,ax)
    ang=math.atan2(dx*right[0]+dy*right[1],dx*ax+dy*ay)
    return math.floor((ang+math.pi/4)/(math.pi/2))%4
def screen_step(flick):
    d=math.hypot(*flick)
    return (flick[0]/d,flick[1]/d) if d>1e-6 else (0.,0.)
dirs={"front":((0.,-120.),0),
      "right":((120.,0.),1),
      "back":((0.,120.),2),
      "left":((-120.,0.),3)}
for label,(v,n) in dirs.items():
    assert screen_step(v)==(v[0]/120.,v[1]/120.),label
assert screen_step((0.,0.))==(0.,0.)
# Preserve the exact diagonal ratio, including former 45deg boundaries.
for i in range(4):
    for offset in (-44.9,-25.,0.,25.,44.9):
        a=math.radians(i*90+offset)
        v=(math.sin(a),-math.cos(a))
        assert all(math.isclose(x,y,abs_tol=1e-9) for x,y in zip(screen_step(v),v))
# Compare with the old actor-facing sectors at oblique camera orientations.
# Old mapping turns horizontal into BACK or DOWN into SIDE for 90°+ yaw.
for actor_heading in range(0,360,5):
    a=math.radians(actor_heading)
    actor_axis=(math.sin(a),-math.cos(a))
    for label,(direction,expected) in dirs.items():
        assert screen_step(direction)==(direction[0]/120.,direction[1]/120.),(actor_heading,label)
    # Bash remains actor-forward (no unintended screen-UP Bash).
    assert classify(actor_axis,actor_axis)==0
    opposite=(-actor_axis[0],-actor_axis[1])
    assert classify(opposite,actor_axis)==2
# A character facing screen-left made left swipe 'forward' and down 'left'
# in v259; fixed STEP must interpret gesture itself, not SERA heading.
assert classify((-100.,0.),(-1.,0.))==0
assert screen_step((-100.,0.))==(-1.,0.)
assert classify((0.,100.),(-1.,0.))==3
assert screen_step((0.,100.))==(0.,1.)

print("PASS v260/v262: UP/DOWN and lateral anchors, full-angle diagonals retained")
print("PASS v260: Bash remains actor-facing; STEP distance/energy/lock cancellation unchanged")
print("Static and numeric regression only; Godot/Android touch not executed")

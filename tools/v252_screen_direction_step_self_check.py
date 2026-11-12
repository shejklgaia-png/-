#!/usr/bin/env python3
"""SERA v252: screen-space step x, SERA-forward step y and 360-degree continuity."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
cfg=(root/"project.godot").read_text(encoding="utf-8")
version=re.search(r'^config/name="SERA v(\d+)"$',cfg,re.M)
assert version and int(version.group(1))>=252
assert (root/"README_v252_ja.md").exists()
step=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step()",1)[0]
move=main.split("func _screen_drag_to_ground(screen_drag: Vector2) -> Vector3:",1)[1].split(
    "func _update_boost_speed(",1)[0]
advance=main.split("func _advance_side_step(delta: float)",1)[1].split(
    "func _move_player_swept(",1)[0]
for required in (
    "var direction: Vector2 = flick.normalized()",
    "var camera_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT).normalized()",
    "var facing_forward: Vector3 = -player.global_transform.basis.z",
    "facing_forward.y = 0.0",
    "facing_forward = facing_forward.normalized()",
    "var world_step: Vector3 = (camera_right * direction.x * side_length",
    "- facing_forward * step_radial_delta)",
    "step_radial_delta = direction.y * radial_distance",
    "STEP_FORWARD_DISTANCE, BACK_STEP_DISTANCE, back_mix",
    "step_linear_fallback = true",
    "step_linear_offset = Vector2(world_step.x, world_step.z)",
    "world_step = world_step.normalized() * step_arc_length",
    "world_step = _screen_drag_to_ground(direction)",
    'rig.call("start_omni_step", direction)',
    "step_close_camera = (absf(direction.x) > 0.001",
):
    assert required in step,required
assert "step_signed_angle *=" not in step
assert "orbit_tangent" not in step
assert "step_linear_fallback = radius <" not in step
assert "var progress: float = step_elapsed / step_duration_current" in advance
assert "var new_offset: Vector2 = step_start_offset + step_linear_offset * progress" in advance
assert "_move_player_swept(requested, true)" in advance
# RUN, BOOST and airborne steering all use the existing camera basis helper.
for tok in ('camera.global_transform.basis.x',
            '-camera.global_transform.basis.z',
            'screen_right * screen_drag.x - screen_forward * screen_drag.y'):
    assert tok in move,tok
assert main.count("_screen_drag_to_ground(direction_input)")>=4
assert '_classify_step_flick(' in main
assert 'if bash_requested and _request_combo_bash():' in main
assert '_classify_recent_upward_flick()' in main
assert 'if _start_omni_step(flick_direction):' in main
assert 'camera.unproject_position(current_aim).x' in main
assert 'target_parts.call("install_movement_colliders", target_collider)' in main

# Numeric mirrors: 3m on character forward, 4m backward, screen-horizontal
# cardinal left/right, fixed snapshot for a camera-relative heading.
def step_vector(x,y,facing=(0.0,1.0),screen_right=(1.0,0.0),radius=6.0):
    norm=math.hypot(x,y)
    x,y=x/norm,y/norm
    side=min(max(2.0,radius*math.radians(35)),4.0)
    t=max(0.,min(1.,(y+.25)/.50))
    t=t*t*(3.-2.*t)
    radial=y*(3.0+t)
    distance=max(2.0,min(4.0,math.hypot(abs(x)*side,radial)))
    vx=screen_right[0]*x*side - facing[0]*radial
    vz=screen_right[1]*x*side - facing[1]*radial
    mag=math.hypot(vx,vz)
    if mag<1e-6:
        # Program falls back to camera-derived screen direction in this
        # degenerate direction, not an invalid zero velocity.
        vx,vz=x,-y
        mag=math.hypot(vx,vz)
    return vx/mag*distance,vz/mag*distance,distance

for facing in ((0.0,1.0),(0.0,-1.0),(.6,.8),(-.6,.8)):
    right=step_vector(1,0,facing)
    left=step_vector(-1,0,facing)
    front=step_vector(0,-1,facing)
    back=step_vector(0,1,facing)
    assert right[0]>0 and abs(right[1])<1e-10
    assert left[0]<0 and abs(left[1])<1e-10
    assert all(math.isclose(a,b,abs_tol=1e-10) for a,b in zip(front[:2],(3*facing[0],3*facing[1])))
    assert all(math.isclose(a,b,abs_tol=1e-10) for a,b in zip(back[:2],(-4*facing[0],-4*facing[1])))
    for deg in range(0,360,5):
        d=math.radians(deg)
        vx,vz,length=step_vector(math.cos(d),math.sin(d),facing)
        assert math.isfinite(vx) and math.isfinite(vz)
        assert 2.0-1e-10<=length<=4.0+1e-10
        assert math.isclose(math.hypot(vx,vz),length,abs_tol=1e-10)
print("PASS v252: left/right flick camera x; up/down flick current SERA facing/back")
print("PASS v252: diagonal 360 degrees, step distance, linear swept collision")
print("PASS v252: RUN/BOOST/guard/Bash/lock UI and target part physics retained")
print("Godot engine and Android touch/camera motion not tested")

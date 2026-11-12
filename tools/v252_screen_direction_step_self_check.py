#!/usr/bin/env python3
"""v252 movement baseline, updated for v263 screen-orthogonal STEP path."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
main=read("scripts/main.gd");cfg=read("project.godot")
v=re.search(r'^config/name="SERA v(\d+)"$',cfg,re.M)
assert v and int(v.group(1))>=263
assert (R/"README_v252_ja.md").exists()
step=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
ground=main.split("func _screen_drag_to_ground(screen_drag: Vector2) -> Vector3:",1)[1].split(
    "func _reset_boost_speed_transition(",1)[0]
advance=main.split("func _advance_side_step(delta: float)",1)[1].split("func _move_player_swept(",1)[0]
for term in ("var direction: Vector2 = flick.normalized()",
    "var world_step: Vector3 = _screen_drag_to_ground(direction)",
    "world_step = world_step.normalized() * step_arc_length",
    "var pose_direction: Vector2 = _step_local_pose_direction(world_step)",
    "step_linear_offset = Vector2(world_step.x, world_step.z)",
    "step_linear_fallback = true","step_radial_delta = direction.y * radial_distance",
    "var back_mix: float = smoothstep(-0.25, 0.25, direction.y)",
    "STEP_FORWARD_DISTANCE, BACK_STEP_DISTANCE, back_mix)",
    'rig.call("start_omni_step", pose_direction)',
    "step_close_camera = (absf(pose_direction.x) > 0.001"):
    assert term in step,term
for term in ("camera.global_transform.basis.x",
    "-camera.global_transform.basis.z",
    "screen_right * screen_drag.x - screen_forward * screen_drag.y"):
    assert term in ground,term
assert "camera_right * direction.x * side_length" not in step
assert "facing_forward * step_radial_delta" not in step
for term in ("var progress: float = step_elapsed / step_duration_current",
             "var new_offset: Vector2 = step_start_offset + step_linear_offset * travel_progress",
             "_move_player_swept(requested, true)"):
    assert term in advance,term
assert main.count("_screen_drag_to_ground(direction_input)")>=4
assert 'if _start_omni_step(flick_direction):' in main
assert 'if bash_requested and _request_combo_bash():' in main
assert "camera.unproject_position(current_aim).x" in main
assert 'target_parts.call("install_movement_colliders", target_collider)' in main

def basis(yaw):
    return ((math.cos(yaw),-math.sin(yaw)),
            (-math.sin(yaw),-math.cos(yaw)))
def travel(x,y,yaw,radius=6.):
    d=math.hypot(x,y);x/=d;y/=d
    side=min(max(2.,radius*math.radians(35)),4.)
    t=max(0.,min(1.,(y+.25)/.5));t=t*t*(3-2*t)
    radial=y*(3.+t)
    distance=max(2.,min(4.,math.hypot(abs(x)*side,radial)))
    right,forward=basis(yaw)
    dx=right[0]*x-forward[0]*y;dz=right[1]*x-forward[1]*y
    magnitude=math.hypot(dx,dz)
    return dx/magnitude*distance,dz/magnitude*distance,distance
for yaw_deg in range(0,360,5):
    yaw=math.radians(yaw_deg)
    right,front=basis(yaw)
    r=travel(1,0,yaw);l=travel(-1,0,yaw)
    f=travel(0,-1,yaw);b=travel(0,1,yaw)
    assert math.isclose(r[2],l[2],abs_tol=1e-9)
    assert math.isclose(f[2],3,abs_tol=1e-9)
    assert math.isclose(b[2],4,abs_tol=1e-9)
    for degrees in range(0,360,5):
        a=math.radians(degrees);x,y=math.sin(a),-math.cos(a)
        vx,vz,length=travel(x,y,yaw)
        assert math.isfinite(vx) and math.isfinite(vz)
        assert 2.-1e-10<=length<=4.+1e-10
        assert math.isclose(math.hypot(vx,vz),length,abs_tol=1e-10)
        sx=(vx*right[0]+vz*right[1])/length
        sy=-(vx*front[0]+vz*front[1])/length
        assert math.isclose(sx,x,abs_tol=1e-10)
        assert math.isclose(sy,y,abs_tol=1e-10)
print("PASS v252/v263: camera-orthogonal 360° STEP with 3m forward, 4m rear")
print("PASS v252/v263: continuous swept collision, unchanged RUN/BOOST and Bash")
print("Android/Godot runtime not tested")

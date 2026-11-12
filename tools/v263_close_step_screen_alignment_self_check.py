#!/usr/bin/env python3
"""SERA v263: STEP world travel follows a stable screen basis near the target."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");rig=read("scripts/sera_rig.gd");cfg=read("project.godot")
v=re.search(r'^config/name="SERA v(\d+)"$',cfg,re.M)
assert v and int(v.group(1))>=263
assert (R/"README_v263_ja.md").exists()
step=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
local=m.split("func _step_local_pose_direction(world_direction: Vector3) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
assert "var direction: Vector2 = flick.normalized()" in step
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in step
assert "camera_right * direction.x" not in step
assert "- facing_forward * step_radial_delta" not in step
assert "world_step = world_step.normalized() * step_arc_length" in step
assert "var pose_direction: Vector2 = _step_local_pose_direction(world_step)" in step
assert 'rig.call("start_omni_step", pose_direction)' in step
assert "step_flick_direction = direction" in step
assert "var back_mix: float = smoothstep(-0.25, 0.25, direction.y)" in step
assert "step_linear_offset = Vector2(world_step.x, world_step.z)" in step
assert "or (absf(pose_direction.x) > 0.001" in step
assert "STEP_CLOSE_CAMERA_SURFACE_DISTANCE" in step
assert "world_unit.dot(right), -world_unit.dot(facing)" in local
assert "var right: Vector3 = facing.cross(Vector3.UP)" in local

physics=m.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(delta: float) -> void:",1)[0]
assert 'rig.call("update_omni_step_direction",' in physics
assert "_step_local_pose_direction(committed_world_step), delta)" in physics
assert "if stepping_this_frame and rig != null and step_linear_fallback:" in physics
assert "step_world_rear.dot(" in physics
assert "player.global_transform.basis.z), 0.0, 1.0)" in physics
assert "leftward_weight = clampf(-step_flick_this_frame.x, 0.0, 1.0)" in physics

camera=m.split("func _process(delta: float) -> void:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
assert "if step_active or close_step_camera_this_frame:" in camera
assert camera.index("if step_active or close_step_camera_this_frame:") < camera.index(
    "elif protect_close_step and separation > 0.08:")
assert "_close_step_target_relative_yaw(bearing, easing, delta)" in camera
assert "_visible_combat_camera_yaw(bearing, delta)" in camera
assert "camera_yaw = lerp_angle(camera_yaw, bearing, easing * CAMERA_MOVING_YAW_SCALE)" in camera
assert "camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)" in camera
assert "_fit_full_frame()" in camera
rig_update=rig.split("func update_omni_step_direction(direction: Vector2, delta: float) -> void:",1)[1].split(
    "func start_side_step(",1)[0]
assert "if not step_playback or not directional_step_active" in rig_update
assert "directional_step_vector.slerp(" in rig_update
assert "direction.normalized(), blend).normalized()" in rig_update
assert "maxf(delta, 0.0) / 0.08" in rig_update
assert "directional_step_vector = direction.normalized()" in rig
assert "alpha = alpha * alpha * (3.0 - 2.0 * alpha)" in rig
assert 'const STEP_FORWARD_DISTANCE: float = 3.0' in m
assert 'const BACK_STEP_DISTANCE: float = 4.0' in m
assert 'step_speed_current = lerpf(radial_speed, lateral_speed, absf(direction.x))' in m
assert '_move_player_swept(requested, true)' in m
assert 'return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)' in m
assert 'not _combo_followup_input_window_open()' in m
assert "left_sector_world = left_sector_world.slerp(" in m

# Numeric mirrors: the two camera XZ axes must remain orthogonal and
# produce the exact screen vector for all camera and actor heading combos.
def camera_basis(yaw):
    # CAMERA yaw as _place_camera(): view right, view forward XZ.
    return ((math.cos(yaw),-math.sin(yaw)),
            (-math.sin(yaw),-math.cos(yaw)))
def step_world(screen,yaw):
    right,forward=camera_basis(yaw)
    x,y=screen
    w=(right[0]*x-forward[0]*y,right[1]*x-forward[1]*y)
    d=math.hypot(*w)
    return w[0]/d,w[1]/d
def angle(v):
    return math.atan2(v[1],v[0])
def actor_local(w,actor_yaw):
    right=(math.cos(actor_yaw),-math.sin(actor_yaw))
    forward=(-math.sin(actor_yaw),-math.cos(actor_yaw))
    return (w[0]*right[0]+w[1]*right[1],
           -(w[0]*forward[0]+w[1]*forward[1]))
for cy in range(0,360,15):
    yaw=math.radians(cy)
    right,forward=camera_basis(yaw)
    assert abs(sum(a*b for a,b in zip(right,forward)))<1e-12
    for heading in range(0,360,15):
        actor=math.radians(heading)
        for deg in range(0,360,5):
            rad=math.radians(deg)
            screen=(math.sin(rad),-math.cos(rad))
            world=step_world(screen,yaw)
            # Project world motion back into the original camera screen:
            sx=sum(a*b for a,b in zip(world,right))
            sy=-sum(a*b for a,b in zip(world,forward))
            assert abs(sx-screen[0])<1e-10 and abs(sy-screen[1])<1e-10,(cy,heading,deg)
            local=actor_local(world,actor)
            assert abs(math.hypot(*local)-1.)<1e-9
# The old mixed basis collapses for actor-right heading and UP+RIGHT.
cy=0
world=step_world((math.sqrt(.5),-math.sqrt(.5)),math.radians(cy))
assert math.isclose(math.hypot(*world),1.,abs_tol=1e-12)
assert abs(world[0])>.5 and abs(world[1])>.5
# 90deg actor turn over a step: animation rebases without changing world path.
before=step_world((0.,-1.),.0)
a=actor_local(before,.0);b=actor_local(before,math.pi/2)
assert a!=b and before==step_world((0.,-1.),0.)
# Camera yaw held during step, so basis stays fixed; dolly/framing may adjust.
print("PASS v263: orthogonal camera STEP projection for all 360deg flick/camera/actor angles")
print("PASS v263: pose follows actual world travel, 0.08s smooth local updates, fixed STEP yaw")
print("Static/numeric only; real Godot/Android collision and visual controls not exercised")

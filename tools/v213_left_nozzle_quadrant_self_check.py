#!/usr/bin/env python3
"""SERA v213: LEFT BOOST/STEP nozzle stays between screen-down and screen-right."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

project = read("project.godot")
main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
equipment = read("scripts/sera_equipment.gd")
fx = read("scripts/back_thruster_fx.gd")

version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 213

# Direction is an explicit screen-sector vector, NOT inferred by the nozzle
# from the current 3D nozzle yaw/pitch or a vertical-axis magic number.
steer = read("scripts/sera_nozzle_steering.gd")
assert "var leftward_weight: float = NOZZLE_STEERING.leftward_weight(" in main
assert "boost_exhaust or boost_pose_exhaust, direction_input)" in main
assert "weight = clampf(-step_flick.x, 0.0, 1.0)" in steer
assert "step_side == -1 and step_flick.is_zero_approx()" in steer
assert "weight = clampf(-direction_input.normalized().x, 0.0, 1.0)" in steer
assert "var left_sector_world: Vector3 = NOZZLE_STEERING.left_sector_direction(" in main
assert "var left_sector_world: Vector3 = Vector3.DOWN.slerp(" in steer
assert "screen_right, left_weight * 0.50).normalized()" in steer
assert "_screen_drag_to_ground(Vector2.RIGHT).normalized()" in main
presentation=read("scripts/sera_thruster_presentation.gd")
assert "thruster_presentation.update(rig, exhaust_on," in main
assert "direction_of_exhaust.normalized(), delta, backstroke_weight," in presentation
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in presentation
assert 'var backstroke_weight: float = NOZZLE_STEERING.backstroke_weight(' in main
assert 'weight = clampf(intended_boost.normalized().dot(actor_rear), 0.0, 1.0)' in steer

# All layers forward the same world-space vector to the authored physical nozzle.
for file in (rig, equipment, fx):
    assert "left_sector_world: Vector3 = Vector3.ZERO" in file
assert "active, exhaust_world, delta, backstroke_weight," in rig
assert "left_sector_world, acceleration_burst, melee_sustain)" in rig
assert "exhaust_world, delta, backstroke_weight, left_sector_world," in equipment
assert "acceleration_burst, melee_sustain)" in equipment
assert "Quaternion(Vector3.BACK, local_sector_direction)" in fx
assert "nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)" in fx
assert "rest_basis.inverse() * left_sector_world.normalized()" in fx
assert "nozzle.quaternion = nozzle.quaternion.slerp(" in fx
assert "returning_from_screen_sector" in fx
assert "if nozzle.quaternion.angle_to(normal_quaternion) < deg_to_rad(0.5):" in fx
assert "var normal_quaternion: Quaternion = (nozzle_rest_rotation" in fx
assert "Quaternion(Vector3.UP, steering_yaw)" in fx
assert "Quaternion(Vector3.RIGHT, steering_pitch)" in fx
assert "steering_pitch = PITCH_DOWN_LIMIT_RADIANS" in fx
assert 'const TURN_TIME: float = 0.075' in fx

# Sector limits in camera coordinates, with arbitrary camera yaw. The intended
# exhaust vector must ALWAYS be down/right (never left/up/out of the screen).
# A full LEFT intent targets mid-sector (45 degrees), while the allowed fan
# itself spans down (0 degrees) through right (90 degrees).
def aim(camera_yaw, left_weight):
    right=(math.cos(camera_yaw),0,math.sin(camera_yaw))
    theta=math.pi/2 * (left_weight*0.5)
    return (math.sin(theta)*right[0], -math.cos(theta),
            math.sin(theta)*right[2])

for yaw in [0,math.pi/6,math.pi/2,math.pi,3*math.pi/2]:
    right=(math.cos(yaw),0,math.sin(yaw))
    for weight in [0.0,0.01,0.25,0.5,0.75,1.0]:
        jet=aim(yaw,weight)
        screen_right=jet[0]*right[0]+jet[2]*right[2]
        down=-jet[1]
        assert screen_right >= -1e-12
        assert down >= -1e-12
        assert math.isclose(screen_right**2+down**2,1,abs_tol=1e-10)
        angle=math.atan2(screen_right,down)
        assert -1e-12 <= angle <= math.pi/2+1e-12
        assert math.isclose(angle,math.pi/4*weight,abs_tol=1e-10)
    assert math.isclose(aim(yaw,1.0)[1],-math.sqrt(.5),abs_tol=1e-10)

# The quaternion from authored +Z to the REST-local target maps to exactly
# the corresponding WORLD vector, without a rig-relative 80-degree yaw clamp.
# Demonstrate on rotated 'chest/rest' axes: inverse yaw, align with +Z, then
# transform back to world, preserving the screen-down/right quadrant.
def quat_from_to_z(v):
    # Unit-vector Quaternion(0,0,1 -> v). Its xyz rotates +Z into v.
    dot=v[2]
    if dot < -0.999999:
        return (0,1,0,0)
    x,y,z=-v[1],v[0],0
    w=1+dot
    n=math.sqrt(x*x+y*y+z*z+w*w)
    return (x/n,y/n,z/n,w/n)
def rotate_q_z(q):
    x,y,z,w=q
    # Rotated local +Z, using quaternion vector transform.
    return (2*(x*z+y*w), 2*(y*z-x*w),1-2*(x*x+y*y))
for yaw in [-2.8,-1.0,0,0.9,2.7]:
    c,s=math.cos(yaw),math.sin(yaw)
    jet=aim(0.5,1.0)
    local=(c*jet[0]-s*jet[2],jet[1],s*jet[0]+c*jet[2])
    q=quat_from_to_z(local)
    restored=rotate_q_z(q)
    actual=(c*restored[0]+s*restored[2],restored[1],
            -s*restored[0]+c*restored[2])
    for a,b in zip(actual,jet):
        assert math.isclose(a,b,abs_tol=1e-9), (yaw,actual,jet)

# Do not regress 50/50 heavy SLIDE or non-left signed nozzle angle limits.
assert 'const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig
assert 'if heavy_slide_run_enabled and slide_blend_weight > 0.00001:' in rig
assert 'const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0' in fx
assert 'const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0' in fx
assert 'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0' in fx
print("PASS v213: left jet is screen-down(0°)..right(90°), 45° at pure left")
print("PASS: no chest-relative steering error; smooth physical-nozzle pivot")
print("Godot/Xperia Android renderer not tested")

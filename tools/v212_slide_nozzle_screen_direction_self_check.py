#!/usr/bin/env python3
"""SERA v212: heavy SLIDE max 50%, downward idle nozzle, screen-right-down left movement."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
def read(name):
    return (root / name).read_text(encoding="utf-8")

rig = read("scripts/sera_rig.gd")
fx = read("scripts/back_thruster_fx.gd")
main = read("scripts/main.gd")
equip = read("scripts/sera_equipment.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 212

# A heavyweight idle RUN (=SLIDE) is a 50/50 blend of authored Wait_motion
# with the directional 4-way BOOST pose. This applies to all bone channels.
assert "const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50" in rig
assert 'var sliding: bool = moving and heavy_slide_run_enabled and not boost_input_active' in rig
assert 'locomotion_mode = "slide"' in rig
assert "var use_boost_pose: bool = boosting or sliding" in rig
assert "wanted = BOOST_CLIP if use_boost_pose else RUN_CLIP" in rig
branch = rig.split("elif current_clip == BOOST_CLIP:",1)[1].split("        else:",1)[0]
assert 'if locomotion_mode == "slide":' in branch
assert '_sample_step_clip_pose(WAIT_CLIP, str(uid), 0.0)' in branch
assert 'q = (idle_pose["rotation"] as Quaternion).slerp(' in branch
assert 'q, SLIDE_BOOST_POSE_MAX_WEIGHT).normalized()' in branch
assert 'translation = (idle_pose["position"] as Vector3).lerp(' in branch
assert 'scale_value = (idle_pose["scale"] as Vector3).lerp(' in branch
assert branch.index('if locomotion_mode == "slide":') > branch.index('q = boost_pose["rotation"]')
assert 'heavy_slide_run_enabled' in rig and '_blended_boost_pose(str(uid))' in branch
# All non-slide modes, including actual BOOST, remain 100% authored pose.
for wait, boost in ((0, 1), (-0.7, 0.9), (5.3, -1.2)):
    assert math.isclose(wait*(1-0.5)+boost*0.5, (wait+boost)/2)
assert 'rig.call("set_heavy_slide_run_enabled", str(part_stats.get("run_motion", "run")) == "slide")' in main
assert '"back": locomotion_mode == "boost"' in rig

# Both physical nozzles initialize pointing down even before first tick and
# return to that down90° direction with FX off.
assert "steering_pitch = PITCH_DOWN_LIMIT_RADIANS" in fx
assert 'nozzle.quaternion = (nozzle_rest_rotation' in fx
assert 'var pitch: float = PITCH_DOWN_LIMIT_RADIANS' in fx
assert "if enabled and world_exhaust_direction.length_squared() > 0.000001:" in fx
assert 'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0' in fx
assert 'const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0' in fx
assert 'const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0' in fx
assert 'var ease: float = 1.0 - exp(-maxf(delta, 0.0) / TURN_TIME)' in fx
assert 'visible = enabled' in fx
assert 'pivot.add_child(fx)' in equip

# The left-only target is defined by CAMERA screen right + vertical DOWN,
# not a character-relative side that flips while orbiting the target.
assert 'var leftward_weight: float = 0.0' in main
assert 'leftward_weight = clampf(-step_flick_this_frame.x, 0.0, 1.0)' in main
assert 'step_side_this_frame == -1 and step_flick_this_frame.is_zero_approx()' in main
assert 'elif boost_exhaust and direction_input.length_squared() > 0.000001:' in main
assert 'leftward_weight = clampf(-direction_input.normalized().x, 0.0, 1.0)' in main
assert 'if exhaust_on and leftward_weight > 0.0:' in main
assert '_screen_drag_to_ground(Vector2.RIGHT).normalized()' in main
assert 'left_sector_world = Vector3.DOWN.slerp(' in main
assert 'screen_right, leftward_weight * 0.50).normalized()' in main
assert 'direction_of_exhaust.normalized(), delta, backstroke_weight,' in main
assert 'left_sector_world)' in main
assert 'Quaternion(Vector3.BACK, local_sector_direction)' in fx

# In screen axes, a full leftward control produces right+down at equal weight.
# Ordinary camera turning cannot alter the screen-space meaning.
right=(1.0,0.0,0.0)
down=(0.0,-1.0,0.0)
target=tuple((r+d)/math.sqrt(2) for r,d in zip(right,down))
assert target[0]>0 and target[1]<0 and abs(target[2])<1e-9
assert math.isclose(math.hypot(target[0],target[1]),1.0)
# 25% left diagonal blends continuously toward the right-down target.
initial=(0.0,0.0,1.0)
for w in (0.0,0.25,0.5,0.75,1.0):
    v=tuple(initial[k]*(1-w)+target[k]*w for k in range(3))
    norm=math.sqrt(sum(x*x for x in v))
    assert norm>0.1
    v=tuple(x/norm for x in v)
    if w>0:
        assert v[0]>0 and v[1]<0
    if w==1:
        assert math.isclose(v[0], 2**-0.5)
        assert math.isclose(v[1], -2**-0.5)

print("PASS v212: 50% max heavy SLIDE pose, default downward nozzle")
print("PASS: screen-left BOOST/STEP produces screen-right/down exhaust vector")
print("Android Godot runtime visual result not verified")

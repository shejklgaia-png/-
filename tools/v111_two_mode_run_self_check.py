#!/usr/bin/env python3
"""v111: front-biased two-mode RUN and progressive target-facing body twist."""
from pathlib import Path
import json, math

ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
model = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
names = {g["name"]: g["uuid"] for g in model["groups"]}
for bone, token in [
    ("Waist", "RUN_ROOT_BONE_UUID"), ("Torso", "RUN_TORSO_BONE_UUID"),
    ("Chest", "RUN_CHEST_BONE_UUID"), ("Neck", "RUN_NECK_BONE_UUID"),
    ("Head", "RUN_HEAD_BONE_UUID")
]:
    assert f'const {token}: String = "{names[bone]}"' in rig
assert "const RUN_MODE_BASE_CENTER_DEGREES: float = 100.0" in rig
assert "const RUN_PREFERRED_SIDE_EXTRA_DEGREES: float = 20.0" in rig
assert "const RUN_MODE_HYSTERESIS_DEGREES: float = 5.0" in rig
assert "func _run_forward_sector_center(direction: Vector2)" in rig
assert "func set_run_left_handed(enabled: bool)" in rig
assert "const RUN_MODE_BLEND_SECONDS: float = 0.085" in rig
assert "const RUN_UPPER_TRACKING_SECONDS: float = 0.05" in rig
assert "var run_upper_yaw_offsets: PackedFloat32Array" in rig
assert "run_upper_yaw_offsets = _run_joint_yaw_targets()" in rig
assert "run_upper_yaw_offsets[i] = lerpf(" in rig
assert "var gaze := Quaternion(Vector3.UP, run_upper_yaw_offsets[part_index])" in rig
assert "const RUN_ROOT_TURN_SPEED_DEGREES: float = 1440.0" in rig
assert "const RUN_UPPER_YAW_PARTS = [0.20, 0.30, 0.25, 0.25]" in rig
assert "const RUN_UPPER_YAW_LIMITS_DEGREES = [25.0, 30.0, 25.0, 35.0]" in rig
assert "source_name: String = RUN_CLIP if i == 0 else RUN_BACK_CLIP" in rig
assert "sample_rotation = run_yaw_correction * sample_rotation" in rig
assert "var facing := Quaternion(Vector3.UP, run_facing_yaw)" in rig
assert "blended_translation = facing * blended_translation" in rig
assert "var bank_axis: Vector3 = facing * Vector3.BACK" in rig
assert "run_turn_lean_degrees = lerpf(run_turn_lean_degrees, desired_lean, alpha)" in rig
assert "run_direction_smoothed = run_update[\"heading\"]" in rig
assert "_update_run_retreat_mode(heading)" in rig
assert "_run_yaw_for_direction(heading, run_retreat_blend)" in rig
assert "run_retreat_blend = lerpf(run_retreat_blend, 1.0 if run_retreat_mode else 0.0, retreat_alpha)" in rig
assert "run_facing_yaw + clampf(yaw_error, -yaw_step, yaw_step)" in rig
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
assert len(model["animations"]) == 20

def wrap(a):
    return (a + math.pi) % (2*math.pi) - math.pi

def mode_after(mode, degrees, center=100):
    if mode and degrees < center - 5:
        return False
    if not mode and degrees > center + 5:
        return True
    return mode

# v111's original 95/105 thresholds survive on the unfavored side.
assert mode_after(False, 100) is False
assert mode_after(False, 106) is True
assert mode_after(True, 100) is True
assert mode_after(True, 94) is False
assert mode_after(True, 96) is True

def yaw(theta, retreat):
    x,y=math.sin(math.radians(theta)), math.cos(math.radians(theta))
    return math.degrees(wrap(-math.atan2(x,y) - (math.pi if retreat else 0)))

for angle,retreat,expected in [(0,False,0),(90,False,-90),(-90,False,90),
                                (180,True,0),(135,True,45),(-135,True,-45)]:
    assert abs(yaw(angle,retreat)-expected)<1e-6,(angle,retreat)
pieces=(.2,.3,.25,.25)
assert abs(sum(pieces)-1)<1e-9
limits=(25,30,25,35)
assert sum(limits)==115
step_limit=math.radians(1440)/60
assert step_limit>0 and step_limit < math.pi

print("v111 two-mode front bias, backpedal facing, torso->head tracking & bank PASS")

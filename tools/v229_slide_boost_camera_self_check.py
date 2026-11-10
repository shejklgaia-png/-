#!/usr/bin/env python3
"""v229: SLIDE/BOOST pose and foot IK fade; screen-edge camera correction."""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT/path).read_text(encoding="utf-8")
rig=read("scripts/sera_rig.gd")
eq=read("scripts/sera_equipment.gd")
main=read("scripts/main.gd")
assert 'config/name="SERA v229"' in read("project.godot")
assert 'SLIDE_BOOST_TRANSITION_SECONDS: float = 0.18' in rig
assert 'var slide_blend_weight: float = 0.0' in rig
assert 'slide_blend_start = slide_blend_weight' in rig
assert 'slide_blend_elapsed = 0.0' in rig
assert 'var smooth: float = t * t * (3.0 - 2.0 * t)' in rig
assert 'slide_blend_weight = lerpf(slide_blend_start, slide_blend_target, smooth)' in rig
assert '_set_slide_blend_target(1.0 if sliding else 0.0, not was_boost_clip)' in rig
assert '_advance_slide_blend(delta)' in rig
assert '1.0, SLIDE_BOOST_POSE_MAX_WEIGHT, slide_blend_weight' in rig
assert 'equipment_handler.call("apply_slide_leg_ik", slide_blend_weight)' in rig
assert 'func apply_slide_leg_ik(weight: float = 1.0)' in eq
assert 'var influence: float = clampf(weight, 0.0, 1.0)' in eq
assert eq.index('var baseline_rig_y: float = rig.position.y') < eq.index('var sole_up: Vector3 = foot.global_basis * Vector3.UP')
assert 'rig.position.y = lerpf(baseline_rig_y, rig.position.y, influence)' in eq
assert 'bone.quaternion = (start[joint] as Quaternion).slerp(' in eq
for begin in [0.0,0.1,0.4,1.0]:
    for target in [0.0,1.0]:
        values=[begin+(target-begin)*(t*t*(3-2*t)) for t in [0.0,0.2,0.5,0.8,1.0]]
        assert math.isclose(values[0],begin) and math.isclose(values[-1],target)
        assert all(0.0<=x<=1.0 for x in values)
        assert all((values[i+1]-values[i])*(target-begin)>=-1e-12 for i in range(4))
assert 'CAMERA_EDGE_GUARD_RATIO: float = 0.008' in main
assert 'CAMERA_EDGE_MAX_CORRECTION_DEGREES_PER_SECOND: float = 240.0' in main
assert 'CAMERA_FIT_RADIUS_RESERVE: float = 0.12' in main
assert main.count('_enforce_screen_edge(bearing, delta)') == 2
edge=main.split('func _enforce_screen_edge(',1)[1].split('func _fit_full_frame()',1)[0]
assert edge.count('_horizontal_safe(CAMERA_EDGE_GUARD_RATIO)') == 3
assert 'var delta_yaw: float = wrapf(safe_yaw - old_yaw, -PI, PI)' in edge
assert 'camera_yaw = old_yaw + clampf(delta_yaw, -max_step, max_step)' in edge
assert 'camera_radius = upper_radius + CAMERA_FIT_RADIUS_RESERVE' in main
assert 'func _horizontal_safe(extra_margin_ratio: float = 0.0)' in main
assert 'SCREEN_MARGIN_X + extra_margin_ratio' in main
assert 'SCREEN_MARGIN_X - extra_margin_ratio' in main
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in main
print("PASS v229: smooth SLIDE/BOOST transitions and camera edge safety")

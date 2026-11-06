#!/usr/bin/env python3
"""v108: four-direction RUN weight blending / root correction / legacy invariants."""
from pathlib import Path
import json
import math

root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
model = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
clips = {a["name"]: a for a in model["animations"]}
names = ("run_front_original", "run_back", "run_right", "run_Left")
assert len(clips) == 17
assert all(clips[n]["length"] == 1 and clips[n]["loop"] == "loop" for n in names)
assert "RUN_DIRECTION_BLEND_SECONDS: float = 0.12" in rig
assert "var run_blend_weights: PackedFloat32Array" in rig
assert "var run_blend_targets: PackedFloat32Array" in rig
assert "_set_run_blend_targets(local_direction)" in rig
assert "wanted = BOOST_CLIP if boosting else RUN_CLIP" in rig
assert "direction_alpha: float = 1.0 - exp(" in rig
assert "run_blend_weights[i] = lerpf(run_blend_weights[i], run_blend_targets[i], direction_alpha)" in rig
assert "var pose: Dictionary = _blended_run_pose(str(uid), t)" in rig
assert "blended_rotation = blended_rotation.slerp(sample_rotation, fraction).normalized()" in rig
assert "blended_translation = blended_translation.lerp(sample_translation, fraction)" in rig
assert "blended_scale = blended_scale.lerp(sample_scale, fraction)" in rig
assert "sample_rotation = run_yaw_correction * sample_rotation" in rig
assert "sample_translation = run_yaw_correction * sample_translation" in rig
assert 'state_label.text = "RUN  x1.0  |  %s" % str(rig.call("get_run_dominant_clip"))' in main
assert "RUN_ANIMATION_SPEED if current_clip in RUN_CLIPS" in rig
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main

def target_weights(x, y):
    total = abs(x) + abs(y)
    if not total:
        return (1.0, 0.0, 0.0, 0.0)
    return max(y, 0)/total, max(-y, 0)/total, max(x, 0)/total, max(-x, 0)/total

cases = [
    ((0, 1), (1, 0, 0, 0)),
    ((0, -1), (0, 1, 0, 0)),
    ((1, 0), (0, 0, 1, 0)),
    ((-1, 0), (0, 0, 0, 1)),
    ((1, 1), (.5, 0, .5, 0)),
    ((-1, 1), (.5, 0, 0, .5)),
    ((1, -1), (0, .5, .5, 0)),
    ((-1, -1), (0, .5, 0, .5)),
]
for (x,y), expected in cases:
    result=target_weights(x,y)
    assert all(abs(a-b)<1e-7 for a,b in zip(result, expected)), (x,y,result)
    assert abs(sum(result)-1)<1e-7

# Frame-rate-invariant weight smoothing, without an intermediate zero state.
def smooth(initial, target, total_time, fps):
    weights=list(initial)
    steps=round(fps*total_time)
    alpha=1-math.exp(-1/fps/0.12)
    for _ in range(steps):
        weights=[(1-alpha)*a+alpha*b for a,b in zip(weights,target)]
    return weights
a=smooth(target_weights(0,1),target_weights(0,-1),.3,30)
b=smooth(target_weights(0,1),target_weights(0,-1),.3,60)
assert max(abs(x-y) for x,y in zip(a,b)) < 1e-6
assert abs(sum(a)-1.0) < 1e-6
assert 0 < a[0] < 1 and 0 < a[1] < 1

print("v108: 4-direction weights, normalized blending and smooth reversal: PASS")

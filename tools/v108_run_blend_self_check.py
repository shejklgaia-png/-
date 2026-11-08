#!/usr/bin/env python3
"""v108/v111: retained same-phase RUN gait, with new two-mode targeting."""
from pathlib import Path
import json
import math
root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
source = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
names = ("run_front_original", "run_back", "run_right", "run_Left")
clips = {a["name"]: a for a in source["animations"]}
assert len(source["animations"]) == 20
assert all(clips[n]["length"] == 1 and clips[n]["loop"] == "loop" for n in names)
assert "const RUN_DIRECTION_BLEND_SECONDS: float = 0.055" in rig
assert "const RUN_ANIMATION_SPEED: float = 1.875" in rig
assert "func _blended_run_pose(uid: String, t: float, stabilize_head: bool = true)" in rig
assert "source_name: String = RUN_CLIP if i == 0 else RUN_BACK_CLIP" in rig
assert "var fraction: float = weight / (total_weight + weight)" in rig
assert "blended_rotation = blended_rotation.slerp(sample_rotation, fraction).normalized()" in rig
assert "blended_translation = blended_translation.lerp(sample_translation, fraction)" in rig
assert "sample_rotation = run_yaw_correction * sample_rotation" in rig
assert "sample_translation = run_yaw_correction * sample_translation" in rig
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
print("v108/v111 retained synced animation phase, source, combat & movement: PASS")

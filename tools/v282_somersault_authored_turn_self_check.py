#!/usr/bin/env python3
"""SERA v282: never double the authored Kick_b flip, keep raw >360deg turn."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
source = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 282
back = main.split("func _advance_back_somersault(delta: float) -> void:", 1)[1].split(
    "func _cancel_back_somersault(", 1)[0]
assert "if not back_somersault_has_authored_clip and back_somersault_launched:" in back
assert back.index("if not back_somersault_has_authored_clip and back_somersault_launched:") < back.index("rig.rotation.x = angle")
assert "rig.call(\"set_back_somersault_progress\", progress)" in back
assert "var previous_offset: Vector3 = _back_somersault_arc_offset(previous)" in back
assert "var next_offset: Vector3 = _back_somersault_arc_offset(progress)" in back
apply = rig.split("func _apply_animation(_delta: float) -> void:", 1)[1].split(
    "func _blockbench_rotation(", 1)[0]
assert "if current_clip == BACK_SOMERSAULT_CLIP and uid == RUN_ROOT_BONE_UUID" in apply
assert "q = _blockbench_rotation(_value_at(rotation_values, t))" in apply
assert "q = _rotation_at(rotation_values, t)" in apply  # other clips unchanged
waist_id = "67435cb7-b6af-23e4-10f1-3cd13d8429fa"
kick = next(clip for clip in source["animations"] if clip["name"] == "Kick_b")
root_angles = sorted(
    [(float(frame["time"]), float(frame["data_points"][0]["x"])) for frame
     in kick["animators"][waist_id]["keyframes"]
     if frame["channel"] == "rotation"]
)
assert root_angles[0][1] < 0.0 and root_angles[-1][1] > 360.0
assert any(a <= 130.0 and b >= 330.0 for (_, a), (_, b) in zip(root_angles, root_angles[1:]))
assert "BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT" in back  # fallback only
print("V282_AUTHORED_SOMERSAULT_TURN_STATIC_PASS")

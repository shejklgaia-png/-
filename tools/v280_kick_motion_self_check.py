#!/usr/bin/env python3
"""SERA v280: second-windup lateral travel and full-body authored backflip."""
import json
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
source = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
project = (ROOT / "project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 280
clips = {a["name"]: a for a in source["animations"]}
for name, timing, variable in (
    ("Kick_r", 0.33333, "SIDE_KICK_SECOND_WINDUP_R"),
    ("Kick_l", 0.41667, "SIDE_KICK_SECOND_WINDUP_L"),
):
    assert f"const {variable}: float = {timing}" in main
    assert any(abs(float(key["time"]) - timing) < 0.0001
               for track in clips[name]["animators"].values()
               for key in track.get("keyframes", []))
    assert abs(float(clips[name]["length"]) - 1.0) < 0.00001
advance = main.split("func _advance_side_step(delta: float) -> void:", 1)[1].split(
    "func _move_player_swept(", 1)[0]
assert "if side_kick_active:" in advance
assert "(progress - second_windup) * SIDE_KICK_MOTION_TIME_MULTIPLIER" in advance
assert "step_linear_offset * travel_progress" in advance
assert "step_signed_angle * travel_progress" in advance
assert "if not side_kick_travel_anchor_set:" in advance
assert "if progress >= second_windup:" in advance
assert "_configure_side_kick_orbit()" in advance
assert "step_target_center = Vector2(target.position.x, target.position.z)" in advance
assert "step_radial_delta * (" in advance
assert "side_kick_travel_anchor_set = true" in advance
assert "if previous_progress < impact_progress and progress >= impact_progress:" in advance
back = main.split("func _advance_back_somersault(delta: float) -> void:", 1)[1].split(
    "func _cancel_back_somersault(", 1)[0]
assert "var angle: float = TAU * progress" in back
assert "rig.rotation.x = angle" in back
assert "BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT * (1.0 - cos(angle))" in back
assert "if not back_somersault_has_authored_clip and back_somersault_launched:" in back
assert "func _back_somersault_arc_offset(progress: float) -> Vector3:" in main
assert "if current_clip == BACK_SOMERSAULT_CLIP and uid == RUN_ROOT_BONE_UUID" in rig
assert "q = _blockbench_rotation(_value_at(rotation_values, t))" in rig
assert "if back_somersault_has_authored_clip and not bool(" in back
assert 'rig.call("set_back_somersault_progress", pose_progress)' in back
assert 'const BACK_SOMERSAULT_CLIP: String = "Kick_b"' in rig
print("V280_KICK_MOTION_STATIC_PASS")

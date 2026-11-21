#!/usr/bin/env python3
"""Authored Bittaran FL/FR/RL/RR collapse clips are canonical and source-accurate."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = json.loads((root / "models/bosses/Bittaran.bbmodel").read_text(encoding="utf-8"))
assert len(model["groups"]) == 14, "Keep the canonical 14-joint hierarchy"
groups = {g["uuid"]: g["name"] for g in model["groups"]}
motions = {a["name"]: a for a in model["animations"]}
expected = {
    "前脚ダウン_L": (2.75, 78),
    "前脚ダウン_R": (2.75, 78),
    "後足ダウン_L": (2.0, 62),
    "後足ダウン_R": (2.0, 62),
}
for name, (length, count) in expected.items():
    assert name in motions, f"missing authored collapse: {name}"
    motion = motions[name]
    assert abs(float(motion["length"]) - length) < 0.0001, name
    tracks = motion["animators"]
    assert set(tracks).issubset(groups), f"unmapped source bone in {name}"
    assert len(tracks) == 13, f"13 articulated body/limb tracks expected in {name}"
    keys = sum(len(v.get("keyframes", [])) for v in tracks.values())
    assert keys == count, f"unexpected mirrored author keys {name}: {keys}"
    assert groups[next(iter(tracks))] == "Body", name

# Model sources and Android fallback must remain equivalent.
embed = (root / "assets/bittaran_data.gd").read_text(encoding="utf-8")
assert "前脚ダウン_L" in embed and "後足ダウン_R" in embed, "stale Android embed"
rig = (root / "scripts/bittaran_rig.gd").read_text(encoding="utf-8")
ik = (root / "scripts/bittaran_foot_ik.gd").read_text(encoding="utf-8")
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
assert "func apply_authored_down_pose(" in rig
assert "func authored_down_motion_time(" in ik
assert "apply_authored_down_pose" in battle
assert "advance_source_ground_ik" in battle
print("PASS bittaran_authored_down_self_check")

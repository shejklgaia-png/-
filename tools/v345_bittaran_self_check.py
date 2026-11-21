#!/usr/bin/env python3
"""Bittaran model contract: imported user geometry, front attack clips, gait."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")
def doc(path):
    return json.loads(read(path))

source = doc("models/storage/ビットタラン.bbmodel")
boss = doc("models/bosses/Bittaran.bbmodel")
assert boss["name"] == "ビットタラン"
assert len(boss["groups"]) == 14 and len(boss["elements"]) == len(source["elements"]) == 18
assert boss["elements"] == source["elements"], "User mesh data must be unchanged"
assert boss["textures"] == source["textures"]
names = [g["name"] for g in boss["groups"]]
assert len(set(names)) == 14
assert set(["Head", "Body", "FrontLeg_R", "FrontLowerLeg_R",
            "FrontFoot_R", "FrontLeg_L", "FrontLowerLeg_L",
            "FrontFoot_L", "RearLeg_L", "RearLowerLeg_L",
            "RearFoot_L", "RearLeg_R", "RearLowerLeg_R",
            "RearFoot_R"]) == set(names)
# Seven original front clips, three authored locomotion clips, plus
# four independently authored rear clips added after the v345 snapshot.
assert [a["name"] for a in boss["animations"]] == [
    "Wait", "なぎ払い", "弾き", "踏みつけ_L", "なぎ払い_R",
    "弾き_R", "踏みつけ_R", "Idle", "Turn", "Approach",
    "後足踏みつけ_L", "後足踏みつけ_R",
    "後足なぎ払い_L", "後足なぎ払い_R",
    "前脚ダウン_L", "前脚ダウン_R", "後足ダウン_L", "後足ダウン_R"]
original_clips = {a["name"]: a for a in source["animations"]}
for clip in boss["animations"][:7]:
    # The two new authored full-length sweeps supersede 17:21 source.
    # Their every key and mirrored right counterpart are verified by
    # tools/bittaran_uploaded_full_sweep_runtime_check.gd.
    if clip["name"] in ("なぎ払い", "なぎ払い_R"):
        assert abs(clip["length"] - 2.625) < 1e-6
        assert sum(len(t.get("keyframes", [])) for t in
                   clip["animators"].values()) == 73
        continue
    original = original_clips[clip["name"]]
    assert clip["uuid"] == original["uuid"]
    assert clip["length"] == original["length"]
    for bone, animator in original["animators"].items():
        if bone not in {g["uuid"] for g in boss["groups"]}:
            continue
        imported = clip["animators"][bone].get("keyframes", [])
        expected = animator.get("keyframes", [])
        normalized = lambda keys: [
            {k: v for k, v in item.items() if k != "uuid"}
            for item in keys]
        # Existing authored rotation keys remain byte-equivalent; the
        # intentional ground-correction BODY position key is appended
        # only to Wait and the two STOMP clips.
        assert normalized(imported[:len(expected)]) == normalized(expected), (
            clip["name"], bone)
        extra = imported[len(expected):]
        if extra:
            assert bone == next(g["uuid"] for g in boss["groups"]
                                if g["name"] == "Body"), (clip["name"], bone)
            assert clip["name"] in ("Wait", "踏みつけ_L", "踏みつけ_R")
            assert len(extra) == 1 and extra[0]["channel"] == "position"
            assert extra[0]["time"] == 0
            assert extra[0]["data_points"] == [{
                "x": "0", "y": "6.9" if clip["name"] == "Wait" else "5.4",
                "z": "0"}]
# Blockbench source already reuses nine Wait-key UUIDs in the kick clip.
# Keep imported IDs byte-identical to the user's source. Check no within-
# clip collision, and permit cross-clip copies only for the known
# originally authored Wait/Kick/RearSweep key provenance.
ids_by_clip = {}
for clip in boss["animations"]:
    ids = [key["uuid"] for track in clip["animators"].values()
           for key in track.get("keyframes", [])]
    assert len(ids) == len(set(ids)), ("Within-clip UUID collision", clip["name"])
    ids_by_clip[clip["name"]] = set(ids)
seen_ids = {}
for clip_name, ids in ids_by_clip.items():
    for uuid in ids:
        seen_ids.setdefault(uuid, set()).add(clip_name)
for uuid, owners in seen_ids.items():
    if len(owners) > 1:
        assert "Wait" in owners and owners.issubset({
            "Wait", "弾き", "後足なぎ払い_L"}), (uuid, owners)
clips_by_name = {a["name"]: a for a in boss["animations"]}
for name, duration in (("Idle", 2.4), ("Turn", 1.8), ("Approach", 2.8)):
    clip = clips_by_name[name]
    assert clip["loop"] == "loop"
    assert abs(clip["length"] - duration) < 1e-6
    assert len(clip["animators"]) == 9  # Head is controlled live.
for name, duration in (("後足踏みつけ_L", 1.0), ("後足踏みつけ_R", 1.0),
                       ("後足なぎ払い_L", 1.54167), ("後足なぎ払い_R", 1.54167)):
    clip = clips_by_name[name]
    assert clip["loop"] == "once", name
    assert abs(clip["length"] - duration) < 1e-6, name
    assert len(clip["animators"]) == 13, name
assert all(any(g["name"] == name for g in boss["groups"])
           for name in ("FrontFoot_R", "FrontFoot_L", "RearFoot_R", "RearFoot_L"))

embedded = read("assets/bittaran_data.gd")
match = re.search(r'^const MODEL_JSON: String = (".*")$', embedded, re.MULTILINE)
assert match and json.loads(match.group(1)) == read("models/bosses/Bittaran.bbmodel")
manifest = doc("models/manifest.json")
assert manifest["bosses"]["bittaran"] == "models/bosses/Bittaran.bbmodel"
rig = read("scripts/bittaran_rig.gd")
ai = read("scripts/bittaran_ai.gd")
nexus = read("scripts/command_nexus.gd")
battle = read("scripts/bittaran_battle.gd")
scene = read("scenes/bittaran_battle.tscn")
assert 'const VISION_TOTAL_DEGREES: float = 100.0' in ai
assert 'const VISION_HALF_DEGREES: float = 50.0' in ai
assert 'const APPROACH_SPEED_MPS: float = 1.872' in ai
assert 'const ACCELERATION_MPS2: float = 1.56' in ai
assert 'const STATIONARY_TURN_DEG_PER_SEC: float = 68.0' in ai
assert 'const MOVING_TURN_DEG_PER_SEC: float = 44.0' in ai
# v478 doubles the old gait velocity and all three root-yaw rates.
assert 'const TRACK_AT_REST_DEG_PER_SEC: float = 36.0' in ai
# v451: Bittaran must stop INSIDE its longest authored SWEEP range
# rather than idling at the retired 7.8m beyond the new 7.10m reach.
stop = float(re.search(r'const STOP_DISTANCE_METERS: float = ([0-9.]+)', ai).group(1))
sweep_radius = float(re.search(
    r'const SWEEP_RANGE_METERS: float = ([0-9.]+)',
    read("scripts/bittaran_attacks.gd")).group(1))
assert 4.5 < stop < sweep_radius
assert 'func _tap_deployment_boss(' in nexus
assert 'func _start_boss_scene(' in nexus
assert 'res://scenes/bittaran_battle.tscn' in nexus
assert 'res://scripts/bittaran_battle.gd' in scene
assert 'extends "res://scripts/main.gd"' in battle
assert 'super._build_target()' in battle
assert 'target_mesh.visible = false' in battle
assert 'func _tick_target_respawn(' in battle
assert 'animations.has("Approach")' in rig
print("PASS v424 Bittaran user geometry, six authored front attacks, gait and embed")

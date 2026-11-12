#!/usr/bin/env python3
"""SERA v272: verify independent kick-only Godot data and UUID/name remapping."""
from pathlib import Path
import json
import re
import uuid

root = Path(__file__).resolve().parents[1]
project = (root/"project.godot").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
game = (root/"scripts/main.gd").read_text(encoding="utf-8")
source = json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
pack_script = (root/"assets/sera_kick_clips.gd").read_text(encoding="utf-8")
assert 'config/name="SERA v272"' in project

# Decode the exact independent .gd resource as Godot will (join literal
# String chunks, JSON.parse_string); detect any truncation of large keys.
text = pack_script.split("const CHUNKS = [", 1)[1].split("\n]\n", 1)[0]
chunks = []
for line in text.splitlines():
    line = line.strip()
    if line:
        assert line.endswith(","), "unterminated resource chunk"
        chunks.append(json.loads(line[:-1]))
assert 20 < len(chunks) < 150
pack = json.loads("".join(chunks))
assert pack["format"] == "SERA_KICK_PACK_v1"
assert "static func get_data() -> Dictionary:" in pack_script
assert 'JSON.parse_string("".join(PackedStringArray(CHUNKS)))' in pack_script
assert len(pack["groups"]) == 22
source_groups = {g["uuid"]: g["name"] for g in source["groups"]}
assert {g["uuid"]:g["name"] for g in pack["groups"]} == source_groups

base = {a["name"]:a for a in source["animations"]}
packed = {a["name"]:a for a in pack["animations"]}
assert sorted(packed) == ["Kick_l","Kick_r"]
for name, keys in [("Kick_l",109),("Kick_r",72)]:
    assert packed[name] == base[name], "original Blockbench keys must be unmodified"
    assert float(packed[name]["length"]) == 1.0
    assert len(packed[name]["animators"]) == 22
    keyed = {uid for uid,a in packed[name]["animators"].items()
             if any(k.get("data_points") for k in a.get("keyframes", []))}
    assert len(keyed) >= 16
    assert sum(len(a.get("keyframes",[])) for a in packed[name]["animators"].values()) == keys
    print(f"PASS {name}: canonical 22 joints, {keys} untouched keys")
print("PASS: independent short Godot script exactly matches source, no other clips")

# Simulate the exact device scenario: both full asset files can be stale or
# lack kicks, yet the new resource alone has correct authored information.
stale_runtime={name: value for name,value in base.items()
               if name not in ("Kick_l","Kick_r")}
assert "Kick_l" not in stale_runtime and "Kick_r" not in stale_runtime
for name in ("Kick_l","Kick_r"):
    stale_runtime[name] = packed[name]
assert all(stale_runtime[name] == base[name] for name in base)
print("PASS: two clips can be recovered with neither full-model fallback")

# Simulate unrelated runtime model UUIDs but EXACT same unique bone names.
# The v272 implementation maps by existing UUID first, name only if unique.
renamed = {g["name"]:str(uuid.uuid5(uuid.NAMESPACE_URL, g["name"]))
           for g in pack["groups"]}
name_from_old = {g["uuid"]:g["name"] for g in pack["groups"]}
def recover_bones(runtime):
    ids=set(runtime.values())
    names={}
    for name, uid in runtime.items():
        names[name] = uid
    for clip in pack["animations"]:
        matches={}
        for uid,anim in clip["animators"].items():
            dst=uid if uid in ids else names.get(name_from_old.get(uid,""),"")
            if dst in ids:
                matches[dst]=anim
        keyed=[u for u,a in matches.items() if a.get("keyframes")]
        yield clip["name"],len(keyed),sum(len(a.get("keyframes",[]))
                                         for a in matches.values())
for name,keyed,keyframes in recover_bones(renamed):
    assert keyed >= 16,(name,keyed)
    assert keyframes == (109 if name=="Kick_l" else 72)
print("PASS: 22 renamed bone UUIDs are reconciled by unique existing name")

# A custom incompatible skeleton must NOT receive arbitrary kick tracks.
limited={k:v for k,v in list(renamed.items())[:4]}
assert all(keyed < 8 for _,keyed,_ in recover_bones(limited))
print("PASS: <8 authored joints safely rejects invalid rig remapping")

def func(a,b):
    return rig.split("func "+a,1)[1].split("func "+b,1)[0]
init = func("_ready() -> void:", "set_equipment_motion_scales")
recover = func("_restore_dedicated_side_kicks() -> void:", "_restore_embedded_side_kicks")
check = func("has_side_kick(side: int) -> bool:", "start_side_kick")
assert 'const KICK_PACK = preload("res://assets/sera_kick_clips.gd")' in rig
assert init.index("_build_animations(data)") < init.index("_restore_dedicated_side_kicks()")
assert init.index("_restore_dedicated_side_kicks()") < init.index("_restore_embedded_side_kicks()")
assert 'var pack: Dictionary = KICK_PACK.get_data()' in recover
assert 'destination_uid = str(runtime_names.get(bone_name, ""))' in recover
assert 'if runtime_names.has(bone_name):' in recover
assert 'runtime_names[bone_name] = ""' in recover
assert 'if animated_bones < 8:' in recover
assert 'if clip_name not in ["Kick_l", "Kick_r"] or _usable_side_kick_clip(clip_name):' in recover
assert 'remapped_clip["animators"] = compatible' in recover
assert '_build_animations({"animations": [remapped_clip]})' in recover
assert "_restore_dedicated_side_kicks()" in check
assert "_restore_embedded_side_kicks()" in check
assert 'return side_name + " " + dedicated_side_kick_status' in rig
assert '"CLIP MISSING " + str(rig.call("get_side_kick_diagnostic", side))' in game
assert 'if not bool(rig.call("start_side_kick", step_kick_side_request, step_duration_current)):' in game
print("PASS: startup and on-demand recovery, no other animations edited, status shown")
print("v272 regression PASS (data/static simulated; not Android Godot runtime)")

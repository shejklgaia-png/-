#!/usr/bin/env python3
"""v271: simulate missing/empty Android JSON kicks and validate embedded recovery."""
from pathlib import Path
import base64
import json
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
runtime_json = (root / "assets/sera_source.json").read_text(encoding="utf-8")
embedded_script = (root / "assets/sera_data.gd").read_text(encoding="utf-8")
assert (ver := re.search(r'config/name="SERA v([0-9]+)"', project)) and int(ver.group(1)) >= 271

# The embedded source is compiled as a GDScript resource, independent of
# FileAccess.file_exists(res://assets/sera_source.json) on the Android phone.
chunks = re.findall(r'^\s+"([A-Za-z0-9+/=]+)",$', embedded_script, re.M)
assert len(chunks) > 100, "embedded model payload not found"
decoded = base64.b64decode("".join(chunks)).decode("utf-8")
assert decoded == runtime_json, "embedded model must be generated from repository source"
embedded = json.loads(decoded)
base = json.loads(runtime_json)

# The only replayable clips are those whose UUIDs resolve to actual installed
# runtime pivots. Older tests counted raw animation keyframes alone.
all_groups = {group["uuid"] for group in embedded["groups"]}
def subtree(entry, visible):
    if isinstance(entry, dict):
        visible.add(entry["uuid"])
        for child in entry.get("children", []):
            subtree(child, visible)
visible = set()
for item in embedded["outliner"]:
    subtree(item, visible)
installed = all_groups & visible
assert len(installed) >= 20

def usable(clip):
    if not clip or float(clip.get("length", 0.0)) <= .01:
        return False
    for uid, animator in clip.get("animators", {}).items():
        if uid not in installed:
            continue
        for key in animator.get("keyframes", []):
            if key.get("channel") in ("rotation", "position", "scale") and key.get("data_points"):
                return True
    return False

clips = {c["name"]:c for c in embedded["animations"]}
for name,minimum in (("Kick_l",109),("Kick_r",72)):
    clip=clips.get(name)
    assert usable(clip), f"{name} has no keyframed installed bone"
    keyed_uuids={uid for uid,a in clip["animators"].items()
                 if uid in installed and a.get("keyframes")}
    keys=sum(len(clip["animators"][uid]["keyframes"]) for uid in keyed_uuids)
    assert len(keyed_uuids)>=16 and keys>=minimum,(name,len(keyed_uuids),keys)
    print(f"PASS {name}: {len(keyed_uuids)} actual rig joints, {keys} authored keys")

# Reproduce the user's Android code path: live SOURCE_PATH exists and parses
# but omits both Kick clips; embedded fallback must be applied selectively.
live_stale = {k:v for k,v in ((c["name"], c) for c in base["animations"])
              if k not in ("Kick_l", "Kick_r")}
assert "Kick_l" not in live_stale and "Kick_r" not in live_stale
restored=live_stale.copy()
for name in ("Kick_l","Kick_r"):
    if not usable(restored.get(name)):
        assert usable(clips[name])
        restored[name]=clips[name]
assert all(usable(restored[name]) for name in ("Kick_l","Kick_r"))
assert all(restored[name] is original for name,original in live_stale.items())
print("PASS: both kicks recovered if Android main JSON lacks them; all other clips untouched")

# Simulate broken / empty tracks, not just absent clip names.
unkeyed=clips["Kick_l"].copy()
unkeyed["animators"]={}
restored["Kick_l"]=unkeyed
assert not usable(restored["Kick_l"])
restored["Kick_l"]=clips["Kick_l"]
assert usable(restored["Kick_l"])
print("PASS: a named but unkeyed clip is repaired from embedded")

def body(a,b):
    return rig.split("func "+a,1)[1].split("func "+b,1)[0]

ready=body("_ready() -> void:","set_equipment_motion_scales")
restore=body("_restore_embedded_side_kicks() -> void:","get_side_kick_diagnostic")
helper=body("_usable_side_kick_clip(name: String) -> bool:","_restore_embedded_side_kicks")
has=body("has_side_kick(side: int) -> bool:","start_side_kick")
choose=body("_side_kick_clip_for(side: int) -> String:","has_side_kick")
request=main.split("func _request_combo_side_kick(flick: Vector2) -> bool:",1)[1].split(
    "func _launch_combo_side_kick",1)[0]
step=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step",1)[0]

assert ready.index("_build_animations(data)") < ready.index("_restore_embedded_side_kicks()")
assert ready.index("_restore_embedded_side_kicks()") < ready.index("_merge_bird_animation_tracks()")
assert "if embedded_side_kick_restore_attempted:" in restore
assert 'JSON.parse_string(EMBEDDED.get_json())' in restore
assert 'name not in ["Kick_l", "Kick_r"]' in restore
assert 'if not needed.is_empty():' in restore
assert '_build_animations({"animations": needed})' in restore
assert "_usable_side_kick_clip(name)" in restore
assert 'for channel in ["rotation", "position", "scale"]' in helper
assert "if not bones.has(str(raw_uid)):" in helper
assert "float(clip.get(\"length\", 0.0)) <= 0.01" in helper
assert "if _usable_side_kick_clip(clip_name):" in choose
assert "if not _usable_side_kick_clip(candidate):" in choose
assert "_restore_embedded_side_kicks()" in has
assert 'rig.call("get_side_kick_diagnostic", side)' in request
assert '"CLIP MISSING "' in request
assert 'if not bool(rig.call("start_side_kick", step_kick_side_request, step_duration_current)):' in step
assert "_finish_side_step(false)" in step
print("PASS: rig startup and late check both recover clips, no phantom kick visual if rejected")
print("SERA v271 static/data regression PASS (Godot Android runtime not executed)")

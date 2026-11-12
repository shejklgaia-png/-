#!/usr/bin/env python3
"""v273: direct Kick_l/Kick_r lookup, no conditional typed arrays."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
project = (root/"project.godot").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
game = (root/"scripts/main.gd").read_text(encoding="utf-8")
source = json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
assert 'config/name="SERA v273"' in project

def part(begin, end):
    return rig.split("func "+begin,1)[1].split("func "+end,1)[0]

lookup = part("_side_kick_clip_for(side: int) -> String:", "has_side_kick")
available = part("has_side_kick(side: int) -> bool:", "start_side_kick")
start = part("start_side_kick(side: int, movement_duration: float) -> bool:","start_side_step")
ready = part("_ready() -> void:", "set_equipment_motion_scales")
assert 'var canonical: String = "Kick_r" if side == 1 else "Kick_l"' in lookup
assert "if _usable_side_kick_clip(canonical):" in lookup
assert "return canonical" in lookup
assert "var preferred: Array[String]" not in lookup
assert "Array[String] = [" not in lookup
assert "var alternate_names: Array = []" in lookup
assert "if side == 1:" in lookup and "else:" in lookup
assert "if not _usable_side_kick_clip(candidate):" in lookup
assert "if _side_kick_clip_for(side).is_empty():" in available
assert "_restore_dedicated_side_kicks()" in available
assert "_restore_embedded_side_kicks()" in available

# Exact issue: old code captures an empty clip name BEFORE has_side_kick()
# repairs data. Godot then starts movement with animations[""].
assert start.index("if not has_side_kick(side):") < start.index(
    "var chosen: String = _side_kick_clip_for(side)")
assert "if chosen.is_empty():" in start
assert 'side_kick_clip_name = chosen' in start
assert 'var canonical: String = "Kick_r" if side == 1 else "Kick_l"' in part(
    "get_side_kick_diagnostic(side: int) -> String:","_side_kick_clip_for")
assert "LOOKUP FAIL" in rig
assert "func _build_animations" in rig
assert "_build_animations(data)" in ready
assert 'rig.call("has_side_kick", side)' in game
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in game

clips={a["name"]:a for a in source["animations"]}
for name,count in [("Kick_l",109),("Kick_r",72)]:
    clip=clips[name]
    assert clip["length"] == 1.0
    assert len(clip["animators"]) == 22
    assert sum(len(x.get("keyframes", [])) for x in clip["animators"].values()) == count
print("PASS: existing authored clips are unchanged and found by canonical name")
print("PASS: conditional typed array removed, lookup occurs AFTER recovery")
print("v273 static check PASS (runtime checked independently by .gd test)")

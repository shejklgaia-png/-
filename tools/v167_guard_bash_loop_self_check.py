#!/usr/bin/env python3
"""v167 source/asset contract for shield reaction and looped Bash combo.

This is a static check, NOT a Godot or Android simulation.
"""
import base64
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
source_bytes = (root / "assets/sera_source.json").read_bytes()
source = json.loads(source_bytes)
combined = json.loads((root / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
embedded = (root / "assets/sera_data.gd").read_text(encoding="utf-8")
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$', embedded, re.MULTILINE)
checks = 0

def check(name: str, ok: bool) -> None:
    global checks
    assert ok, name
    checks += 1

check("version", 'config/name="SERA v167"' in project)
check("Godot source embedded byte exact", bool(parts) and base64.b64decode("".join(parts)) == source_bytes)
clips = {a["name"]: a for a in source["animations"]}
authored = {a["name"]: a for a in combined["animations"]}
check("original clips and additions unique", len(clips) == len(source["animations"]) == 22)
check("all three old strikes and original guard", all(n in clips for n in ("melee1", "Melee2", "Melee3", "Guard")))
bones = {g["uuid"] for g in source["groups"]}
for name, duration, looping in (("Guard_REACTION", 0.20833, "loop"), ("Bash", 0.5, "once")):
    check(name + " matches authored model", clips[name] == authored[name])
    check(name + " length", clips[name]["length"] == duration)
    check(name + " loop flag", clips[name]["loop"] == looping)
    check(name + " bone compatibility", set(clips[name]["animators"]) == bones and len(bones) == 22)
check("unchanged A skeleton and mesh count", len(source["elements"]) == 25 and len(source["groups"]) == 22)
check("guard and Bash clips are required by rig", all(s in rig for s in (
    'const GUARD_REACTION_CLIP: String = "Guard_REACTION"',
    'const BASH_CLIP: String = "Bash"',
    "animations.has(GUARD_REACTION_CLIP)", "animations.has(BASH_CLIP)")))
check("guard reaction plays once per blocked hit and returns", all(s in rig for s in (
    "func trigger_guard_reaction()", "func guard_reaction_playing()",
    '_switch_clip(GUARD_REACTION_CLIP, 0.045)',
    'clip_time >= float(animations[GUARD_REACTION_CLIP]["length"])',
    "_switch_clip(GUARD_CLIP, 0.075)")))
check("guard hit calls reaction and returns before normal damage", 'rig.call("trigger_guard_reaction")' in main
      and "if guard_active:\n        # Guarded bullets" in main)
check("release-only forward Bash", all(s in main for s in (
    "var bash_requested: bool = (bash_flick_candidate",
    "and _is_upward_jump_flick(release_pos - pointer_origin, press_duration)",
    "if bash_requested and _request_combo_bash():")))
check("guard forward flick on release", all(s in main for s in (
    "var guard_bash_requested: bool = _classify_recent_upward_flick()",
    "if guard_bash_requested:", "_start_bash()")))
check("Melee3 Bash buffered until old cancel frame", all(s in main for s in (
    'STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]',
    "if (bash_queued and strike_index == STRIKE_CLIPS.size() - 1",
    'float(rig.call("get_clip_time")) >= float(STRIKE_CANCEL_TIMES[strike_index])',
    "bash_followup_window_remaining = BASH_LINK_SECONDS")))
check("Bash after tap buffer, repeat strike 1", all(s in main for s in (
    "if combat_state == CombatState.BASH:",
    "bash_combo_queued = true", "if bash_combo_queued:",
    "_start_strike(0)", "bash_loop_window_remaining = BASH_LINK_SECONDS")))
check("Bash one-hit rate and target damage", all(s in main for s in (
    "const BASH_CONTACT_TIME: float = 0.25", "const BASH_DAMAGE: int = 12",
    "if combat_state != CombatState.BASH or bash_did_hit",
    "target_hp = maxi(0, target_hp - BASH_DAMAGE)",
    "bash_did_hit = true")))
check("moving away or damage cancels attack", all(s in main for s in (
    "if combat_state != CombatState.IDLE and not bash_flick_candidate:",
    "if running and gesture_max_travel > TAP_MAX_TRAVEL and not bash_flick_candidate:",
    "func _cancel_attack()", "bash_followup_window_remaining = 0.0")))
check("regular combat preserved", 'const STRIKE_DAMAGE = [12, 12, 26]' in main
      and 'const JUMP_TOUCH_INPUT_ENABLED: bool = false' in main)
check("existing hub navigation preserved", 'func _request_return_to_nexus() -> void:' in main
      and (root / "scenes/command_nexus.tscn").exists())
check("readme present", (root / "README_v167_ja.md").exists())
print(f"PASS: v167 guard reaction + Bash loop, assets + source links ({checks} static checks)")
print("Godot runtime and Android actual touch gameplay: NOT TESTED")

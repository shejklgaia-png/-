#!/usr/bin/env python3
"""SERA v277 foot-extension hit timing, two side hits and common tracking."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
game = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
source = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
clips = {c["name"]: c for c in source["animations"]}
groups = {g["uuid"]: g["name"] for g in source["groups"]}
assert 'config/name="SERA v277"' in (ROOT / "project.godot").read_text()
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in game
assert "const BACK_SOMERSAULT_HIT_PROGRESS: float = 0.20833 / 0.79167" in game
assert "side_kick_hit_mask |= bit" in game
assert "back_somersault_hit_checked = true" in game
assert "previous_progress < impact_progress and progress >= impact_progress" in game
assert "previous < BACK_SOMERSAULT_HIT_PROGRESS" in game
assert "_advance_homing_toward_target(chase_dt, BASH_REACH)" in game
assert "_advance_homing_toward_target(kick_dt, BASH_REACH)" in game
assert "CombatState.BACK_KICK_TRACK" in game
assert "normal_melee_exhaust or normal_kick_exhaust" in game
assert "direction_of_exhaust = -back_somersault_direction" in game
assert "backstroke_weight = 1.0" in game and "new_somersault_burst" in game
assert "BACK_SOMERSAULT_DISTANCE: float = 4.0" in game
assert "BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in game
for name in ("Kick_l", "Kick_r"):
    a = clips[name]
    assert float(a["length"]) == 1.0
    for key in (0.25, 0.58333):
        assert any(
            k.get("channel") == "rotation" and abs(float(k.get("time", -1))-key) < 0.00002
            for uid,anim in a["animators"].items()
            if groups.get(uid, "").startswith("LowerLeg")
            for k in anim.get("keyframes", [])
        ), (name,key)
a = clips["Kick_b"]
assert abs(float(a["length"])-0.79167) < 0.00002
assert any(abs(float(k.get("time",-1))-0.20833)<0.00002
    for uid,anim in a["animators"].items() if groups.get(uid)=="LowerLeg_R"
    for k in anim.get("keyframes", []))
print("V277_KICK_STATIC_PASS: 2+2+1 authored foot keys, Bash homing and shared thrusters")

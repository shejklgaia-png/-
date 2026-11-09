#!/usr/bin/env python3
"""SERA v182 static contract: moving-target homing and Blockbench windup keys."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")
stats = read("scripts/sera_part_stats.gd")
main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
godot = read("project.godot")
if 'config/name="SERA v182"' not in godot:
    print("SKIP: v182 historical release-hop test, superseded by v183 no-skip contract")
    raise SystemExit(0)
assert read("README_v182_ja.md").startswith("# SERA v182")
booster = stats.split('    "booster": {', 1)[1].split('\n    },', 1)[0]
for kind, speed, duration in (("A", 11.5, 0.4), ("B", 9.5, 0.6)):
    part = booster.split('"' + kind + '": ', 1)[1].split('}', 1)[0]
    assert '"melee_boost_speed": ' + str(speed) in part, kind
    assert '"melee_boost_duration": ' + str(duration) in part, kind
assert "const MELEE_BOOST_DEFAULT_DURATION: float = 0.4" in main
assert "const BASH_TRACK_SECONDS: float = 0.20" in main
assert "const FOLLOWUP_TRACK_SECONDS: float = 0.20" in main
assert "const BASH_WINDUP_KEY: float = 0.20833" in main
assert "const FOLLOWUP_WINDUP_KEYS = [0.0, 0.08333, 0.20833]" in main
# Verify keyframes are actually present in the user's authored Blockbench model.
model = json.loads(read("assets/sera_source.json"))
for clip, key in (("Bash", 0.20833), ("Melee2", 0.08333), ("Melee3", 0.20833)):
    anim = next(x for x in model["animations"] if x["name"] == clip)
    times = [float(frame.get("time", -1))
        for bone in anim.get("animators", {}).values()
        for frame in bone.get("keyframes", [])]
    assert any(abs(t - key) < 1e-5 for t in times), (clip, key)
# State transitions for strike-2/3 homing and shield bash, including early launch.
for s in (
    "BASH_TRACK, STRIKE_TRACK",
    "func _launch_followup_strike() -> void:",
    'rig.call("start_attack_windup", "Bash", BASH_WINDUP_KEY)',
    'rig.call("start_attack_windup", str(STRIKE_CLIPS[strike_index])',
    'rig.call("release_attack_windup")',
    "followup_track_elapsed += follow_dt",
    "bash_track_elapsed += track_dt",
    "_advance_homing_toward_target(track_dt, BASH_REACH)",
    "_advance_homing_toward_target(follow_dt, MELEE_SURFACE_REACH)",
    "_advance_homing_toward_target(delta, BASH_REACH)",
    "_advance_homing_toward_target(delta, MELEE_SURFACE_REACH)",
    "elif bash_track_elapsed >= BASH_TRACK_SECONDS - 0.00001:",
    "elif followup_track_elapsed >= FOLLOWUP_TRACK_SECONDS - 0.00001:",
    "if not strike_did_hit:",
    "if not bash_did_hit:",
    "func _check_bash_contact() -> void:",
):
    assert s in main, s
for s in (
    "func start_attack_windup(clip_name: String, windup_end: float) -> void:",
    "func release_attack_windup() -> void:",
    "var cycle: float = attack_windup_end * 2.0",
    "clip_time = phase if phase <= attack_windup_end else cycle - phase",
    "clip_time = attack_windup_end",
    "blend_duration = 0.025",
    "attack_windup_active = false",
):
    assert s in rig, s
# The original hit windows and guard/combo paths were not removed.
for s in ("STRIKE_ACTIVE_FROM_TIMES", "STRIKE_ACTIVE_TO_TIMES",
          "STRIKE_CANCEL_TIMES", "_request_combo_bash()",
          "bash_combo_queued", "_register_bash_hit()", "_register_strike_hit(",
          'if rig.call("clip_finished", "Bash"):'):
    assert s in main, s
print("PASS: SERA v182 booster durations, windup assets, homing through attack (static only)")

#!/usr/bin/env python3
"""v181: static contracts for booster-dependent melee boost and 0.6s Bash homing."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
def read(p):
    return (ROOT / p).read_text(encoding="utf-8")
main = read("scripts/main.gd")
stats = read("scripts/sera_part_stats.gd")
rig = read("scripts/sera_rig.gd")
project = read("project.godot")
if 'config/name="SERA v181"' not in project:
    print("SKIP: v181 historical fixed Bash delay / longer booster duration check")
    raise SystemExit(0)
assert read("README_v181_ja.md").startswith("# SERA v181")
booster = stats.split('    "booster": {', 1)[1].split('\n    },', 1)[0]
for kind, speed, duration in (("A", 11.5, 1.0), ("B", 9.5, 1.2)):
    part = booster.split('"' + kind + '": ', 1)[1].split('}', 1)[0]
    assert '"melee_boost_speed": '+str(speed) in part, (kind, "speed")
    assert '"melee_boost_duration": '+str(duration) in part, (kind, "duration")
assert '"approach_speed"' not in stats
assert "const BASH_TRACK_SECONDS: float = 0.60" in main
assert "BASH_TRACK" in main.split("enum CombatState", 1)[1].split('}', 1)[0]
for symbol in (
    "func _advance_homing_toward_target(delta: float, reach: float) -> bool:",
    'float(part_stats.get("melee_boost_speed", MELEE_BOOST_DEFAULT_SPEED))',
    'float(part_stats.get("melee_boost_duration", MELEE_BOOST_DEFAULT_DURATION))',
    "func _launch_bash_after_tracking() -> void:",
    "combat_state = CombatState.BASH_TRACK",
    'rig.call("start_melee_approach")',
    'rig.call("start_bash")',
    "bash_track_elapsed += track_dt",
    "bash_track_elapsed >= BASH_TRACK_SECONDS - 0.00001",
    "_advance_homing_toward_target(track_dt, BASH_REACH)",
    "_advance_homing_toward_target(boost_dt, MELEE_SURFACE_REACH)",
    "melee_boost_elapsed >= maximum_duration - 0.00001",
    "if _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH:",
    "if _distance_to_cube_surface(player.position) <= BASH_REACH:",
    "if combat_state == CombatState.BASH or combat_state == CombatState.BASH_TRACK:",
    "if combat_state == CombatState.BASH_TRACK:",
):
    assert symbol in main, symbol
assert 'float(part_stats.get("energy_cost_mult", 1.0))' in main
assert "func hold_melee_approach_last_pose()" in rig
assert "func start_bash()" in rig
assert "func _check_bash_contact() -> void:" in main
assert "MELEE BOOST  %.1fm/s  %.2f/%.1fs" in main
assert "BASH HOMING  %.2fs / %.2fs" in main
print("PASS: v181 timed melee boost A/B, fixed Bash homing and combo compatibility (static)")

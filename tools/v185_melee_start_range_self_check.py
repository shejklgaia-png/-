#!/usr/bin/env python3
"""v185: melee 2.0m start, preserving Bash reach / hit assist / timers."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
stats = (root / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v185"' in project
assert (root / "README_v185_ja.md").exists()
assert "const MELEE_SURFACE_REACH: float = 2.0" in main
assert "const MELEE_HIT_ASSIST_BASE_REACH: float = 0.75" in main
assert "const BASH_REACH: float = 0.95" in main
assert 'MELEE_HIT_ASSIST_BASE_REACH + 0.08 * float(part_stats.get("tracking", 1.0))' in main
assert "const BLADE_THICKNESS: float = 0.14" in main
for fragment in (
    "_advance_homing_toward_target(boost_dt, MELEE_SURFACE_REACH)",
    "_advance_homing_toward_target(follow_dt, MELEE_SURFACE_REACH)",
    "_advance_homing_toward_target(delta, MELEE_SURFACE_REACH)",
    "_distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH",
):
    assert fragment in main, fragment
assert '"melee_boost_duration": 0.4' in stats
assert '"melee_boost_duration": 0.6' in stats
assert "const BASH_TRACK_SECONDS: float = 0.20" in main
assert "const FOLLOWUP_TRACK_SECONDS: float = 0.20" in main
assert "const STRIKE_ACTIVE_FROM_TIMES = [0.130, 0.130, 0.290]" in main
assert "func release_attack_windup() -> void:" in rig
print("PASS: SERA v185 melee start 2.0m, Bash and hitboxes unchanged (static)")

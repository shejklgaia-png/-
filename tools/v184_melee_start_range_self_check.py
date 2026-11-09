#!/usr/bin/env python3
"""v184 contract: melee starts at 1m, without changing Bash or melee-hit assist."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
stats = (root / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
if 'config/name="SERA v184"' not in project:
    print("SKIP: v184 historical 1m activation contract")
    raise SystemExit(0)
assert (root / "README_v184_ja.md").exists()
assert 'const MELEE_SURFACE_REACH: float = 1.0' in main
assert 'const MELEE_HIT_ASSIST_BASE_REACH: float = 0.75' in main
assert 'const BASH_REACH: float = 0.95' in main
assert '_distance_to_cube_surface(player.position) <= MELEE_HIT_ASSIST_BASE_REACH + 0.08 * float(part_stats.get("tracking", 1.0))' in main
assert 'const BLADE_THICKNESS: float = 0.14' in main
# Melee1, followups and strike homing all share the 1m surface reach.
for marker in (
    'if _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH:',
    '_advance_homing_toward_target(boost_dt, MELEE_SURFACE_REACH)',
    '_advance_homing_toward_target(follow_dt, MELEE_SURFACE_REACH)',
    '_advance_homing_toward_target(delta, MELEE_SURFACE_REACH)',
):
    assert marker in main, marker
# Timers, motion and original hit windows must be unchanged.
assert '"melee_boost_duration": 0.4' in stats
assert '"melee_boost_duration": 0.6' in stats
assert 'const BASH_TRACK_SECONDS: float = 0.20' in main
assert 'const FOLLOWUP_TRACK_SECONDS: float = 0.20' in main
assert 'const STRIKE_ACTIVE_FROM_TIMES = [0.130, 0.130, 0.290]' in main
assert 'const STRIKE_ACTIVE_TO_TIMES = [0.345, 0.345, 0.625]' in main
assert 'func release_attack_windup() -> void:' in rig
print("PASS: normal melee activation is 1.0m; Bash 0.95m and hit assist untouched (static)")

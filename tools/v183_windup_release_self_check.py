#!/usr/bin/env python3
"""v183: Bash/Melee2/Melee3 must not skip authored windup when target gets into range."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
stats = (root / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
if 'config/name="SERA v183"' not in project:
    print("SKIP: v183 historical windup-release version-specific check")
    raise SystemExit(0)
assert (root / "README_v183_ja.md").exists()
release = rig.split("func release_attack_windup() -> void:", 1)[1].split("\nfunc ",1)[0]
assert "attack_windup_active = false" in release
assert "clip_time =" not in release, "Release must not fast-forward to the last windup key"
assert "prior_rotations.clear()" not in release
assert "blend_duration =" not in release
assert "func start_attack_windup(clip_name: String, windup_end: float) -> void:" in rig
assert "clip_time = phase if phase <= attack_windup_end else cycle - phase" in rig
assert 'rig.call("release_attack_windup")' in main
assert "const BASH_TRACK_SECONDS: float = 0.20" in main
assert "const FOLLOWUP_TRACK_SECONDS: float = 0.20" in main
assert "const BASH_WINDUP_KEY: float = 0.20833" in main
assert "const FOLLOWUP_WINDUP_KEYS = [0.0, 0.08333, 0.20833]" in main
assert '"melee_boost_duration": 0.4' in stats
assert '"melee_boost_duration": 0.6' in stats
assert "_advance_homing_toward_target(delta, BASH_REACH)" in main
assert "_advance_homing_toward_target(delta, MELEE_SURFACE_REACH)" in main
print("PASS: no precast-keyframe skip; all v182 chase limits retained (static)")

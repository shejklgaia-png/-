#!/usr/bin/env python3
"""v319: short idle-to-RUN landing bridge, persistent KO/broken-part hits."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
parts = (ROOT / "scripts/target_parts.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert re.search(r'config/name="SERA v319"', project)
for term in (
    "IDLE_TO_RUN_LANDING_SECONDS: float = 0.11",
    "IDLE_TO_RUN_LANDING_POSE_FRACTION: float = 0.45",
    "IDLE_TO_RUN_LANDING_WEIGHT: float = 0.62",
    "current_clip == WAIT_CLIP and wanted == RUN_CLIP",
    "idle_to_run_landing_elapsed = 0.0 if begin_idle_to_run_landing else -1.0",
    "idle_to_run_landing_elapsed + maxf(delta, 0.0)",
    "if not beginning_run:",
    "var landing_weight: float = IDLE_TO_RUN_LANDING_WEIGHT * sin(",
    "var partial_landing: Dictionary = _sample_step_clip_pose(",
    "JUMP_CLIP, str(uid), landing_sample_time)",
):
    assert term in rig, term
assert "func is_targetable(id: String) -> bool:\n    return parts.has(id)" in parts
assert 'func is_intact(id: String) -> bool:' in parts
assert 'return parts.has(id) and not bool(parts[id]["broken"])' in parts
damage = main.split("func _apply_target_part_damage(", 1)[1].split(
    "func _register_strike_hit(", 1)[0]
assert "if target_parts != null:" in damage
assert "if target_hp > 0 and target_parts != null:" not in damage
assert 'var actual_damage: int = int(result["body_damage"])' in damage
assert 'result["applied_damage"] = actual_damage' in damage
assert 'target_hp = maxi(0, target_hp - int(result["body_damage"]))' in damage
assert 'if hp_before_hit > 0 and target_hp == 0:' in damage
for term in (
    'if target_hp > 0 and _distance_to_attack_target_surface',
    'if chase_dt > 0.0 and target_hp > 0',
):
    assert term not in main, term
assert 'if not manual_part_lock_active or locked_part_broken:' in main
assert 'or camera == null or target_hp <= 0' not in main
for expected in (
    "py tools/v319_idle_run_persistent_hits_self_check.py",
    "gd tools/v319_idle_run_persistent_hits_runtime_check.gd",
):
    assert expected in manifest, expected
print("SERA_V319_IDLE_RUN_PERSISTENT_HITS_STATIC_PASS")

#!/usr/bin/env python3
"""SERA v177 A/B loadout static integration check (not a Godot runtime test)."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
def src(name):
    return (root / name).read_text(encoding="utf-8")
project = src("project.godot")
assert 'config/name="SERA v177"' in project
stats = src("scripts/sera_part_stats.gd")
main = src("scripts/main.gd")
eq = src("scripts/sera_equipment.gd")
nexus = src("scripts/command_nexus.gd")
rig = src("scripts/sera_rig.gd")
save = src("scripts/sera_save.gd")
assert "static func build(selected: Dictionary)" in stats
assert 'stats["defense"] = defense_total / float(BODY_SLOTS.size())' in stats
assert 'stats["max_hp"] = hp_total' in stats
for x in ["head","torso","legs","arms","booster","weapon_r","weapon_l"]:
    assert f'"{x}"' in stats
    assert f'"{x}"' in eq and f'"{x}"' in nexus and f'"{x}"' in save
assert 'if slot == "booster":' in eq and 'return ["A", "B"]' in eq
for x in ['_load_part_stats()', '_spend_energy(', '_tick_resources(', '_begin_test_down(',
          '_register_test_hit(', 'guard_break_remaining', 'down_remaining',
          'stagger_remaining', 'part_break_remaining', 'damage_push_mult',
          'damage_time_mult', 'run_speed', 'step_time_mult', 'approach_speed',
          'guard_defense_mult', 'guard_transition', 'boost_speed_mult']:
    assert x in main, x
assert 'set_equipment_motion_scales' in rig
assert 'equipment_damage_scale' in rig
assert 'equipment_guard_transition' in rig
assert 'energy = TEST_EN_MAX' in main and 'shield = TEST_SH_MAX' in main
assert src("README_v177_ja.md").startswith("# SERA v177")
print("PASS: SERA v177 equipment slots, A/B stat aggregation, HUD and runtime hooks (static only)")

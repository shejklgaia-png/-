#!/usr/bin/env python3
"""v180 stat contract for 1/5 player max HP; source-only, not a Godot run."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
stats = (root / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
proj = (root / "project.godot").read_text(encoding="utf-8")
if 'config/name="SERA v180"' not in proj:
    print("SKIP: v180 historical HP test for older version")
    raise SystemExit(0)
assert (root / "README_v180_ja.md").exists()
body = {"head": (20, 26), "torso": (80, 104), "arms": (20, 26),
        "legs": (20, 26), "booster": (20, 26)}
for slot, (a, b) in body.items():
    block = stats.split('    "' + slot + '": {', 1)[1].split('\n    },', 1)[0]
    assert re.search(r'"A": \{"hp": '+str(float(a)), block), (slot, "A")
    assert re.search(r'"B": \{"hp": '+str(float(b)), block), (slot, "B")
assert sum(v[0] for v in body.values()) == 160
assert sum(v[1] for v in body.values()) == 208
assert 'stats["max_hp"] = hp_total' in stats
assert 'stats["defense"] = defense_total / float(BODY_SLOTS.size())' in stats
for phrase in ('func _refresh_player_hp_bar()', 'float(part_stats.get("max_hp", 800.0))',
               'player_hp = float(part_stats.get("max_hp", 800.0))',
               'rig.call("set_training_ko", true)', 'rig.call("set_training_ko", false)'):
    assert phrase in main, phrase
print("PASS: v180 HP A=160 B=208, parts/defense/UI/KO preservation (static)")

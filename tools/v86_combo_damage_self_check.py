#!/usr/bin/env python3
"""SERA v86: static checks on per-combo-stage damage; not runtime validation."""
from pathlib import Path
import re

r=Path(__file__).resolve().parents[1]
main=(r/'scripts/main.gd').read_text('utf-8')
name=(r/'project.godot').read_text('utf-8')
assert 'SERA v86' in name
checks={
  'damage values in strike clip order': 'const STRIKE_DAMAGE = [12, 12, 26]' in main and 'const STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]' in main,
  'stage computed from current strike index': 'var strike_damage: int = int(STRIKE_DAMAGE[strike_index])' in main,
  'target hp uses stage damage': 'target_hp = maxi(0, target_hp - strike_damage)' in main,
  'popup shows stage damage': 'damage_label.text = "%d" % strike_damage' in main,
  'one hit per stage guard remains': 'if strike_did_hit:\n        return' in main and 'strike_did_hit = true' in main,
  'stage hit flag reset remains': 'func _clear_strike_tracking() -> void:\n    strike_did_hit = false' in main and 'func _start_strike(stage: int = 0) -> void:' in main,
  'stage follows combo clip order': 'strike_index = clampi(stage, 0, STRIKE_CLIPS.size() - 1)' in main,
  'cancel times unchanged': 'const STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]' in main,
  'no old flat damage': 'MELEE_DAMAGE' not in main,
  '3 hit total equals 50': sum((12,12,26)) == 50,
}
for label, passed in checks.items():
    assert passed, label
    print('PASS:', label)
print(f'v86 damage static checks: {len(checks)} PASS')

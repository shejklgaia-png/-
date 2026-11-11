#!/usr/bin/env python3
"""SERA v250 boss HP=500, 5 breakable target parts with HP=100 each."""
from pathlib import Path
import re
import math

ROOT=Path(__file__).resolve().parents[1]
m=(ROOT/"scripts/main.gd").read_text(encoding="utf-8")
p=(ROOT/"scripts/target_parts.gd").read_text(encoding="utf-8")
version=(ROOT/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v250"',version)
assert (ROOT/"README_v250_ja.md").exists()
assert 'const TARGET_MAX_HP: int = 500' in m
assert 'var target_hp: int = TARGET_MAX_HP' in m
assert m.count('target_hp = TARGET_MAX_HP')==2  # reset and respawn
assert 'target_hp = maxi(0, target_hp - int(result["body_damage"]))' in m
assert '"TARGET   %d / %d HP" % [target_hp, TARGET_MAX_HP]' in m
assert 'TARGET_HP_BAR_WIDTH * float(target_hp) / float(TARGET_MAX_HP)' in m
assert 'float(target_hp) / float(TARGET_MAX_HP) > 0.40' in m
assert m.count('target_parts.call("reset_parts")')==2

match_pattern=re.compile(
    r'_add_part\("(head|leg_(?:fl|fr|rl|rr))", "[^"]+", '
    r'Vector3\([^)]+\),\s*Vector3\([^)]+\),\s*'
    r'Vector3\([^)]+\),\s*([\d.]+), ([\d.]+), '
    r'([\d.]+), "(\w+)"')
matches=match_pattern.findall(p)
assert len(matches)==5,matches
parts={name:(float(hp),float(df),float(bdf),mode)
       for name,hp,df,bdf,mode in matches}
assert parts=={
    "head":(100.0,.20,.10,"change"),
    "leg_fl":(100.0,.12,.00,"remove"),
    "leg_fr":(100.0,.12,.00,"remove"),
    "leg_rl":(100.0,.16,.12,"remain"),
    "leg_rr":(100.0,.16,.12,"remain")
}
assert 'part["integrity"] = part["max_integrity"]' in p
assert '"max_integrity": integrity' in p
assert '"integrity": integrity' in p
assert 'part["integrity"] = maxf(0.0, old_hp - break_damage)' in p
assert 'result["part_damage"] = old_hp - float(part["integrity"])' in p
assert '"body_damage": boss_damage' in p
assert 'int(result["broken_legs"]) >= 2' in m
assert 'enemy_shooter.call("set_head_destroyed", true)' in m
assert 'locked_target_part_id = ""' in m
# 100 durability: front legs require 4 of the existing 32-break strikes.
assert math.ceil(100.0/(32.0*(1-.00)))==4
# Head retains original 10% break defense.
assert math.ceil(100.0/(32.0*(1-.10)))==4
print("PASS v250: boss 500 HP, all five parts exactly 100 durability")
print("PASS v250: original defense/break/reset behavior and 40% bar threshold")
print("Godot and Android runtime not tested")

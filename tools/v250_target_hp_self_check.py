#!/usr/bin/env python3
"""SERA v250 boss HP=500, 5 breakable target parts with HP=100 each."""
from pathlib import Path
import re
import math

ROOT=Path(__file__).resolve().parents[1]
m=(ROOT/"scripts/main.gd").read_text(encoding="utf-8")
p=(ROOT/"scripts/target_parts.gd").read_text(encoding="utf-8")
version=(ROOT/"project.godot").read_text(encoding="utf-8")
version_match = re.search(r'config/name="SERA v(\d+)"', version)
assert version_match and int(version_match.group(1)) >= 250
assert (ROOT/"README_v250_ja.md").exists()
assert 'const TARGET_MAX_HP: int = 500' in m
assert 'var target_hp: int = TARGET_MAX_HP' in m
# v317 Stage9: KO recovery and timed respawn share exactly one reset body.
assert m.count('target_hp = TARGET_MAX_HP') == 1
assert 'func _reset_target_after_respawn() -> void:' in m
ko = m.split('func _tick_training_ko(delta: float) -> void:', 1)[1].split(
    'func _advance_target_motion(', 1)[0]
respawn = m.split('func _tick_target_respawn(delta: float) -> void:', 1)[1].split(
    'func _reset_target_after_respawn(', 1)[0]
assert '_reset_target_after_respawn()' in ko
assert '_reset_target_after_respawn()' in respawn
assert 'TARGET_LIFECYCLE.respawn_action(' in respawn
assert 'target_hp = maxi(0, target_hp - int(result["body_damage"]))' in m
assert '"TARGET   %d / %d HP" % [target_hp, TARGET_MAX_HP]' in m
assert 'TARGET_HP_BAR_WIDTH * float(target_hp) / float(TARGET_MAX_HP)' in m
assert 'float(target_hp) / float(TARGET_MAX_HP) > 0.40' in m
assert m.count('target_parts.call("reset_parts")') == 1
reset = m.split('func _reset_target_after_respawn() -> void:', 1)[1].split(
    'func _update_enemy_fire_eligibility(', 1)[0]
assert 'target_hp = TARGET_MAX_HP' in reset
assert 'target_parts.call("reset_parts")' in reset
assert 'manual_part_lock_active = not auto_lock_enabled' in reset
assert 'enemy_shooter.call("set_head_destroyed", false)' in reset

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
    "leg_fl":(100.0,.12,.00,"remain"),
    "leg_fr":(100.0,.12,.00,"remain"),
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

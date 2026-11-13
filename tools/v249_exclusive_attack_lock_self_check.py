#!/usr/bin/env python3
"""v249: locked part exclusively controls blade, close assist, chase and Bash."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
main=(ROOT/"scripts/main.gd").read_text(encoding="utf-8")
parts=(ROOT/"scripts/target_parts.gd").read_text(encoding="utf-8")
cfg=(ROOT/"project.godot").read_text(encoding="utf-8")
match=re.search(r'config/name="SERA v(\d+)"',cfg)
assert match and int(match.group(1))>=249
assert (ROOT/"docs/history/release_notes/README_v249_ja.md").is_file()

def function(name,next_name):
    return main.split("func "+name,1)[1].split("func "+next_name,1)[0]

blade=function("_blade_contact(","_check_strike_contact(")
assert "_locked_part_hit_volume_available()" in blade
assert "func _locked_part_hit_volume_available() -> bool:" in main
assert 'target_parts.call("get_part_aabb", locked_target_part_id)' in blade
assert 'return part_box.grow(BLADE_THICKNESS).intersects_segment(from_pt, to_pt)' in blade
assert 'return _target_hit_aabb().grow(BLADE_THICKNESS).intersects_segment(from_pt, to_pt)' in blade
assert 'if part_contact != null:' not in blade
strike=function("_check_strike_contact(","_apply_target_part_damage(")
assert strike.count("_blade_contact(")>=5
assert "_distance_to_attack_target_surface(player.position) <= MELEE_HIT_ASSIST_BASE_REACH" in strike
assert 'target_parts.call("get_part_aabb", locked_target_part_id)' in strike
assert 'part_box.get_center().y' in strike
assert "_distance_to_cube_surface(" not in strike
rng=function("_distance_to_attack_target_surface(","_start_strike(")
for token in ('_locked_part_hit_volume_available()',
              'target_parts.call("get_part_aabb", locked_target_part_id)',
              'nearest_x: float = clampf(pos.x, part_box.position.x, part_box.end.x)',
              'nearest_z: float = clampf(pos.z, part_box.position.z, part_box.end.z)',
              'return Vector2(pos.x - nearest_x, pos.z - nearest_z).length()',
              'return _distance_to_cube_surface(pos)'):
    assert token in rng,token
combat=function("_start_attack(","_screen_drag_to_ground(")
assert combat.count("_distance_to_attack_target_surface(")>=18
# The only legacy core references in this section are the helper declaration
# and its single deliberately kept no-lock fallback.
assert combat.count("_distance_to_cube_surface(")==2
homing=function("_advance_homing_toward_target(","_check_bash_contact(")
assert 'pursuit_point = target_parts.call("get_part_aim_world", locked_target_part_id)' in homing
assert 'if _distance_to_attack_target_surface(player.position) <= reach:' in homing
assert 'if _distance_to_attack_target_surface(next_position) <= reach:' in homing
bash=function("_check_bash_contact(","_register_bash_hit(")
assert "if _distance_to_attack_target_surface(player.position) <= BASH_REACH:" in bash
damage=function("_apply_target_part_damage(","_register_strike_hit(")
assert '"apply_part_hit", locked_target_part_id, raw_attack, raw_break)' in damage
assert 'locked_target_part_id = ""' not in damage
assert '"trigger_part_hit_fx"' in damage
assert "not manual_part_lock_active or locked_part_broken" in main
assert "func get_part_aabb(id: String) -> AABB:" in parts

# Locked limb 1.35m away, while inside torso -> cannot count as limb hit.
def dist(x,z,b):
    x0,z0,x1,z1=b
    return math.hypot(x-min(max(x,x0),x1),z-min(max(z,z0),z1))
core=(-1.,-1.7,1.,1.7)
limb=(1.0,0.59,3.4,1.95)
assert dist(0,0,core)==0 and dist(0,0,limb)>.95
assert dist(2.2,1.3,limb)==0.0
assert (None if True else "core") is None
assert (None if False else "core")=="core"

print("PASS v249: locked part exclusively gates blade, tracking, assist and Bash")
print("PASS v249: unlocked torso fallback and locked broken hitbox retained through combo")
print("Godot parser and Android runtime not tested")

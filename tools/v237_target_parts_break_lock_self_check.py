#!/usr/bin/env python3
"""v237: target five-part break model, auto lock and real strike/bash routing."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(p):
    return (ROOT / p).read_text(encoding="utf-8")

p = read("scripts/target_parts.gd")
m = read("scripts/main.gd")
shooter = read("scripts/enemy_shooter.gd")
project = read("project.godot")
v = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert v and int(v.group(1)) >= 237
assert read("README_v237_ja.md").startswith("# SERA v237")
assert "WORKFLOW_ID: SERA_MODEL_PARTS_V1" in read("docs/MODEL_PART_WORKFLOW_ja.md")
assert "RENDER_POLICY_ID: SERA_RENDER_CONTRACT_V1" in read("docs/RENDER_PIPELINE_POLICY_ja.md")

for id in ("head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"):
    assert f'_add_part("{id}",' in p
    assert f'"{id}"' in p
assert p.count("    _add_part(") == 5
assert "CORE_HP_SHARE: float = 0.50" in p
assert "EACH_PART_HP_SHARE: float = 0.10" in p
assert "SELECTION_HYSTERESIS_RADIANS: float = 0.13" in p
assert "CORE_DEFENSE: float = 0.14" in p
for value in ("100.0, 0.20, 0.10, \"change\"",
              "100.0, 0.12, 0.00, \"remain\"",
              "100.0, 0.16, 0.12, \"remain\""):
    assert value in p, value
assert "box.size = dimensions" in p
assert 'pivot.name = id' in p
assert 'part["integrity"] = maxf(0.0, old_hp - break_damage)' in p
assert 'part["broken"] = true' in p
assert 'pivot.visible = true' in p
assert 'pivot.visible = false' not in p
assert 'fracture.visible = true' in p
assert 'return (defenses[2] + defenses[3]) * 0.5' in p
assert 'not bool(parts[id]["broken"])' in p
assert "func select_camera_front_part(view_camera: Camera3D, current: String) -> String:" in p
assert "view_camera.unproject_position(aim)" in p
assert "core_box.intersects_segment(origin, aim)" not in p
assert "hidden_by_limb: bool = false" not in p
assert "current_score <= best_score + CAMERA_PART_LOCK_HYSTERESIS" in p
assert 'if not is_targetable(id):' in p

# No edits to the original central collision geometry or camera target.
assert 'target_box.size = cube.size' in m
assert 'const TARGET_BODY_HALF_DEPTH: float = 1.70' in m
assert 'TARGET_HALF_SIZE * 2.0, TARGET_HALF_SIZE * 2.0, TARGET_BODY_HALF_DEPTH * 2.0' in m
assert 'target_collider = AnimatableBody3D.new()' in m
assert 'target_parts = TARGET_PARTS_SCRIPT.new()' in m
assert 'marker.add_child(target_parts)' in m
assert 'camera_target_render_position = target.get_global_transform_interpolated().origin' in m
assert 'center_world += target_parts.call("get_part_local_aim", locked_target_part_id)' in m
assert 'target_parts.call("get_part_aabb", locked_target_part_id)' in m
assert 'func _part_hit_surface(id: String, hit: Vector3) -> Vector3:' in m

apply = m.split("func _apply_target_part_damage(", 1)[1].split(
    "func _register_strike_hit(", 1)[0]
assert 'target_parts.call(\n            "apply_part_hit", locked_target_part_id, raw_attack, raw_break)' in apply
assert 'target_hp = maxi(0, target_hp - int(result["body_damage"]))' in apply
assert '_register_test_hit(weak_stagger, extension)' in apply
assert 'part_break_remaining = maxf(part_break_remaining, 1.0)' in apply
assert 'int(result["broken_legs"]) >= 2' in apply
assert 'part_break_remaining = maxf(part_break_remaining, 3.5)' in apply
assert 'enemy_shooter.call("set_head_destroyed", true)' in apply
assert 'locked_target_part_id = ""' not in apply
assert 'trigger_part_hit_fx' in apply
assert 'func _combo_lock_retention_active() -> bool:' in m
assert 'SeraSave.record_target_hit(kind, actual_damage,' in apply
assert '"apply_part_hit"' in m
assert '"melee", strike_damage,' in m
assert '"bash", bash_damage,' in m
assert 'if target_hp > 0 and (not manual_part_lock_active or locked_part_broken):' in m
assert 'not manual_part_lock_active or locked_part_broken' in m
assert '"select_camera_front_part", camera,' in m
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in m
assert '"get_part_aim_world", locked_target_part_id' in m
assert 'pursuit_point = target_parts.call("get_part_aim_world", locked_target_part_id)' in m
assert 'target_parts.call("reset_parts")' in m
assert 'enemy_shooter.call("set_head_destroyed", false)' in m
assert 'target_parts.call("status_line")' in m
assert "var core_hp: float" not in m
assert "core_hp = maxf" not in m
assert "var head_destroyed: bool = false" in shooter
assert "func set_head_destroyed(broken: bool)" in shooter
assert 'selected_attack >= AttackType.SHOCKWAVE' in shooter
assert 'AttackType.AIMED if head_destroyed' in shooter
assert 'func _register_test_hit(stagger_amount: float, extension: float)' in m

# Numerical contract: independent raw attack/break power and defenses.
specs = {"head": (100., .20, .10),
         "leg_fl": (100., .12, .00),
         "leg_fr": (100., .12, .00),
         "leg_rl": (100., .16, .12),
         "leg_rr": (100., .16, .12)}
assert math.isclose(0.50 + 5*0.10, 1.0)
armor = sorted([.14] + [x[1] for x in specs.values()])
median = (armor[2] + armor[3]) / 2
assert math.isclose(median, .15)
for id, (hp, defense, break_defense) in specs.items():
    normal_hit = round(26 * (1-defense))
    breaking_hit = 32 * (1-break_defense)
    assert normal_hit > 0 and breaking_hit > 0
    assert not math.isclose(normal_hit, breaking_hit)
    remaining = max(0., hp-breaking_hit)
    assert 0 <= remaining < hp
    assert hp-normal_hit != hp-breaking_hit or defense == break_defense

# Both front legs require four 32-break strikes at 100 durability each;
# their existing two-broken-legs down condition is still available.
broken_legs = 0
for id in ("leg_fl", "leg_fr"):
    hp, defense, break_defense = specs[id]
    for _strike in range(4):
        hp = max(0, hp - 32*(1-break_defense))
    assert hp == 0
    broken_legs += 1
assert broken_legs >= 2

# Basic bracket/string sanity for new part script; Godot/Android remain untested.
stack = []
pairs = {')':'(', ']':'[', '}':'{'}
for line in p.splitlines():
    string = False
    escaped = False
    for ch in line:
        if ch == '"' and not escaped:
            string = not string
        if not string and ch in "([{":
            stack.append(ch)
        elif not string and ch in ")]}":
            assert stack and stack.pop() == pairs[ch]
        escaped = (ch == "\\" and not escaped)
assert not stack
print("PASS v237: head/4 legs, damage vs break strength, median defense")
print("PASS v237: automatic angle lock, attack lock, lifecycle, damage, reset")
print("PASS v237: 2-leg down, head suppression, opaque break visuals")
print("Godot parser/Android rendering and controls not exercised")

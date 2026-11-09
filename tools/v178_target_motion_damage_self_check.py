#!/usr/bin/env python3
"""v178 moving dummy / per-attack damage source contract. Static, not Godot runtime."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def src(p):
    return (root / p).read_text(encoding="utf-8")
main = src("scripts/main.gd")
shoot = src("scripts/enemy_shooter.gd")
motion = src("scripts/training_target_motion.gd")
project = src("project.godot")
if 'config/name="SERA v178"' not in project:
    print("SKIP: v178 historical moving target / damage version-specific check")
    raise SystemExit(0)
assert src("README_v178_ja.md").startswith("# SERA v178")
for s in ("ENEMY_ATTACK_HP_DAMAGE = [18.0, 22.0, 28.0, 34.0]",
          "ENEMY_ATTACK_SHIELD_COST = [23.0, 28.0, 36.0, 42.0]",
          "attack_index: int = clampi(attack_type, 0",
          "_take_test_damage(incoming_damage)",
          "float(ENEMY_ATTACK_SHIELD_COST[attack_index])",
          "func _tick_training_ko(delta: float)",
          "training_ko_remaining = TRAINING_KO_RECOVERY",
          "func _advance_target_motion(delta: float)",
          'target_motion.call("advance", delta, target.position',
          "target_floor_mark.position = Vector3(",
          "AnimatableBody3D.new()",
          'move_target_button.text = "MOVE: ON"',
          "func _pointer_on_training_test_button(pos: Vector2)",
          "_on_enemy_projectile_hit(player.global_position, incoming.normalized(), true, 0)",
          "incoming_damage_label.visible = true"):
    assert s in main, s
assert "func warning_in_progress() -> bool:" in shoot
assert 'bind(false, _locked_attack)' in shoot and 'bind(true, _locked_attack)' in shoot
assert "projectile_hit.emit(world_position, travel_direction, is_bullet, attack_type)" in shoot
assert "signal projectile_hit(world_position: Vector3, travel_direction: Vector3," in shoot
assert 'func advance(delta: float, current: Vector3, player_pos: Vector3,' in motion
for s in ("frozen or delta <= 0.0", "MIN_BOX_CLEARANCE", "TETHER_RADIUS", "MOVE_SPEED"):
    assert s in motion, s
# Preserve existing player shield-break/down and v177 gear integration.
for s in ('guard_break_remaining = 2.25', "down_remaining = 1.45",
          "energy = TEST_EN_MAX", "shield = TEST_SH_MAX", "_load_part_stats()"):
    assert s in main
print("PASS: v178 moving target / attack-specific HP+SH damage / KO wiring (static only)")

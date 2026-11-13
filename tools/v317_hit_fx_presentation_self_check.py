#!/usr/bin/env python3
"""SERA v317 Stage8: scene-owned FX life, explicit presentation/respawn order."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
presentation = (root / "scripts/sera_hit_fx_presentation.gd").read_text(encoding="utf-8")
assert 'const HIT_FX_PRESENTATION = preload("res://scripts/sera_hit_fx_presentation.gd")' in main
assert "extends RefCounted" in presentation
for method in ("present_projectile_hit", "present_target_body_flash",
               "present_damage_popup", "present_incoming_damage_popup"):
    assert f"static func {method}(" in presentation, method
    assert f"HIT_FX_PRESENTATION.{method}(" in main, method
for forbidden in ("get_tree(", "get_node(", "target_parts", "target_respawn_remaining",
                  "static var", "Material.new(", "Label.new(", "load(", "queue_free("):
    assert forbidden not in presentation, forbidden
projectile = main.split("func _advance_projectile_hit_overlay(delta: float) -> void:", 1)[1].split(
    "func _add_round_ground_shadow(", 1)[0]
for token in (
    "if projectile_hit_overlay == null:",
    "projectile_hit_flash_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "HIT_FX_PRESENTATION.present_projectile_hit(",
    "projectile_hit_overlay, projectile_hit_flash_remaining, PROJECTILE_HIT_FLASH_SECONDS)",
):
    assert token in projectile, token
assert projectile.index("if projectile_hit_overlay == null:") < projectile.index(
    "projectile_hit_flash_remaining = COMBAT_TIMERS.remaining_after_delta(")
body = main.split("func _advance_hit_fx(delta: float) -> void:", 1)[1].split(
    "func _input(event: InputEvent) -> void:", 1)[0]
ordered = (
    "if hit_flash_remaining > 0.0:",
    "hit_flash_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "HIT_FX_PRESENTATION.present_target_body_flash(",
    "target_mesh.position = Vector3.ZERO",
    "target_mesh.rotation_degrees.z = 0.0",
    'target_parts.call("advance_part_hit_fx", delta)',
    'hit_burst.call("advance", delta)',
    "if damage_popup_remaining > 0.0:",
    "HIT_FX_PRESENTATION.present_damage_popup(",
    "elif damage_label != null:",
    "damage_label.visible = false",
    "incoming_damage_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "HIT_FX_PRESENTATION.present_incoming_damage_popup(",
    "if target_respawn_remaining > 0.0:",
    "target_respawn_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "if target_respawn_remaining <= 0.0 and _combo_lock_retention_active():",
    "target_respawn_remaining = 0.01",
    "target_hp = TARGET_MAX_HP",
    'target_parts.call("reset_parts")',
    'locked_target_part_id = ""',
)
indices = [body.index(token) for token in ordered]
assert indices == sorted(indices), indices
# Preserve all numerical curves and apply them only to the referenced nodes.
for token in (
    "overlay.color = Color(1.0, 0.26, 0.15, 0.13 * intensity)",
    "overlay.visible = remaining > 0.0",
    'material.albedo_color = Color("e53935").lerp(Color("632535"), ratio * 0.78)',
    "material.emission_energy_multiplier = lerpf(0.08, 0.03, ratio)",
    'material.emission = Color("a92724").lerp(Color("6b1727"), ratio)',
    "view_camera.unproject_position(impact_origin + Vector3.UP * 0.28)",
    "(0.58 - remaining) * 75.0",
    "label.position = screen_pt - Vector2(26.0, 30.0 + lift)",
    "label.modulate.a = minf(1.0, remaining / 0.17)",
    "label.modulate.a = minf(1.0, remaining / 0.18)",
    "if remaining <= 0.0:",
    "label.visible = false",
):
    assert token in presentation, token
print("SERA_HIT_FX_PRESENTATION_STATIC_PASS")

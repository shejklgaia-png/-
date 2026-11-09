#!/usr/bin/env python3
"""SERA v179: static source contract for SERA HP bar and reversible KO pose/palette."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(name):
    return (ROOT / name).read_text(encoding="utf-8")
project = read("project.godot")
main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
shader = read("shaders/sera_ko_dark.gdshader")
if 'config/name="SERA v179"' not in project:
    print("SKIP: v179 historical KO/HP bar version-specific check")
    raise SystemExit(0)
assert read("README_v179_ja.md").startswith("# SERA v179")
for phrase in (
    "func _refresh_player_hp_bar() -> void:",
    'player_hp_label.name = "PlayerHpLabel"',
    'player_hp_background.name = "PlayerHpBackground"',
    'player_hp_fill.name = "PlayerHpFill"',
    "PLAYER_HP_BAR_WIDTH * remaining",
    'float(part_stats.get("max_hp", 800.0))',
    "if remaining <= 0.25:",
    "if remaining <= 0.50:",
    "player_hp = maxf(0.0, player_hp - final_damage)",
    "_refresh_player_hp_bar()",
    'rig.call("set_training_ko", true)',
    'rig.call("set_training_ko", false)',
    "training_ko_remaining = TRAINING_KO_RECOVERY",
    "player_hp = float(part_stats.get("max_hp", 800.0))",
):
    assert phrase in main, phrase
assert main.index('rig.call("set_training_ko", true)') > main.index("if combat_state != CombatState.IDLE:", main.index("func _begin_training_ko"))
assert main.index('rig.call("set_training_ko", false)') < main.index("player.position = Vector3.ZERO", main.index("func _tick_training_ko"))
for phrase in (
    "func set_training_ko(active: bool) -> void:",
    'clip_time = float(animations[DAMAGE_CLIP]["last_key_time"])',
    "training_ko_active: bool = false",
    "if not loading_ok or training_ko_active:",
    "var t: float = clip_time if training_ko_active and current_clip == DAMAGE_CLIP else",
    "if training_ko_active:",
    "overlay = _ko_material_b if",
    "part.material_overlay = overlay",
    "_refresh_character_overlay()",
    "func _clear_motion_afterimages() -> void:",
    "if training_ko_active:\n        return",
):
    assert phrase in rig, phrase
assert 'KO_DARK_SHADER = preload("res://shaders/sera_ko_dark.gdshader")' in rig
assert "set_tint" in shader and "ko_brightness" in shader
assert "ALBEDO = color.rgb * set_tint * ko_brightness;" in shader
# Previous training target HP bar and v178 systems remain present.
for phrase in ('hp_label.name = "TargetHpLabel"', 'hp_fill.name = "TargetHpFill"',
    "ENEMY_ATTACK_HP_DAMAGE", "func _advance_target_motion(delta: float)"):
    assert phrase in main, phrase
print("PASS: SERA v179 KO palette/pose and SERA HP bar integration (static only)")

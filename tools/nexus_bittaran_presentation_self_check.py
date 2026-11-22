#!/usr/bin/env python3
"""NEXUS selected equipment glows, and Bittaran spawn/name clear the combat HUD."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

nexus = source("scripts/command_nexus.gd")
rig = source("scripts/sera_rig.gd")
equipment = source("scripts/sera_equipment.gd")
battle = source("scripts/bittaran_battle.gd")
hud = source("scripts/sera_clean_training_hud.gd")
main = source("scripts/main.gd")
manifest = source("tools/sera_ci_manifest.txt")

assert "func visible_meshes_for(slot: String)" in equipment
assert "piece.visible" in equipment
assert "func get_equipment_visible_meshes(slot: String)" in rig
assert "func _sync_customization_part_glow()" in nexus
assert "func _clear_customization_part_glow()" in nexus
assert 'get_equipment_visible_meshes", customize_part_preview_slot' in nexus
assert "part.material_overlay = customize_selection_material" in nexus
assert "part.material_overlay = null" in nexus
assert "material.no_depth_test = false" in nexus
assert "RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in nexus
assert "func _inspect_customization_part(slot: String)" in nexus
inspect = nexus.split("func _inspect_customization_part(slot: String)")[1].split("\nfunc ")[0]
assert "_sync_customization_part_glow()" in inspect
restore = nexus.split("func _restore_customization_preview()")[1].split("\nfunc ")[0]
assert "_clear_customization_part_glow()" in restore
assert "func _choose_customization_part(choice: String)" in nexus
choose = nexus.split("func _choose_customization_part(choice: String)")[1].split("\nfunc ")[0]
assert "_sync_customization_part_glow()" in choose

# v537: hand motion rotates the full-body preview but never pans/re-scales it.
drag = nexus.split("func _rotate_customization_preview(delta: Vector2) -> void:")[1].split("\nfunc ")[0]
assert "var pitch_delta: float = -delta.y" in drag
assert "_constrain_customization_preview_to_safe_area()" not in drag
assert "customize_preview_position.x +=" not in drag
assert "customize_preview_position.y -=" not in drag
assert "customize_preview_scale *=" not in drag
# v537: explicitly visible ON/OFF blinking, not continuous material breathing.
assert "const CUSTOMIZE_SELECTION_BLINK_PERIOD_SECONDS: float = 1.0" in nexus
assert "func _update_customization_part_blink(delta: float) -> void:" in nexus
assert "_update_customization_part_blink(delta)" in nexus
assert "part.material_overlay = null" in nexus
assert "part.material_overlay = customize_selection_material" in nexus
# The right equipment list must highlight the inspected row without
# invoking the thumbnail equipment picker or changing the equipped UID.
assert "func _sync_customization_row_selection() -> void:" in nexus
assert "_sync_customization_row_selection()" in inspect
assert 'button.add_theme_stylebox_override("normal",' in nexus

distance = float(re.search(r"^const BOSS_START_DISTANCE_METERS: float = ([0-9.]+)", battle, re.M).group(1))
assert distance == 12.0
assert 'target.position.z = -BOSS_START_DISTANCE_METERS' in battle
assert 'target_floor_mark.position.z = -BOSS_START_DISTANCE_METERS' in battle
assert 'target.position = Vector3(0, TARGET_BASE_HEIGHT, -8.0)' in main
boss_y = float(re.search(r"_make_boss_label\(layer, NAME_TEXT, ([0-9.]+)", battle).group(1))
victory_y = float(re.search(r'_make_boss_label\(layer, "BITTARAN DEFEATED", ([0-9.]+)', battle).group(1))
part_top = float(re.search(r"^const PART_ROW_TOP: float = ([0-9.]+)", hud, re.M).group(1))
assert boss_y >= part_top + 8.0 + 7.0 + 12.0, (boss_y, part_top)
assert victory_y >= boss_y + 34.0 + 8.0, (victory_y, boss_y)
assert 'label.name = "BittaranName" if caption == NAME_TEXT else "BittaranVictory"' in battle
assert "py tools/nexus_bittaran_presentation_self_check.py" in manifest
assert "gd tools/nexus_bittaran_presentation_runtime_check.gd" in manifest
print("PASS NEXUS selected mesh glow and Bittaran 12m entry / nonoverlapping HUD")

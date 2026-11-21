#!/usr/bin/env python3
"""SERA: portrait LABO confirmation is an accessible, tall, square-first layout."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest=(ROOT/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
start=src.index("    confirmation_overlay = Control.new()")
end=src.index("func _set_labo_scroll_input_enabled(",start)
confirm=src[start:end]
for required in [
    "confirm_panel.anchor_top = 0.105",
    "confirm_panel.anchor_bottom = 0.895",
    "var craft_info := VBoxContainer.new()",
    'accent_rail.name = "LaboConfirmAccentRail"',
    'confirmation_stats_list.name = "LaboConfirmStatRows"',
    'preview_outline.name = "LaboConfirmPreviewTechFrame"',
    'StatUI.baseline_rows(equipment_blueprint)',
    "confirmation_item_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT",
    'confirmation_preview_square.name = "LaboConfirmSquarePreview"',
    "confirmation_preview_square.ratio = 1.0",
    'confirmation_preview_host.name = "LaboConfirmRotatablePart"',
    "confirmation_item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    'confirmation_craft_card.custom_minimum_size.y = 610.0',
    "func _layout_craft_confirmation() -> void:",
    'confirmation_preview_square.custom_minimum_size = Vector2(side, side)',
]:
    assert required in src,required
assert '"BASE STATUS"' not in confirm
assert 'confirmation_item_icon.custom_minimum_size = Vector2(136, 136)' not in confirm
assert 'var craft_info := HBoxContainer.new()' not in confirm
assert 'confirmation_preview_host.custom_minimum_size = Vector2(136, 136)' not in confirm
assert 'func _show_craft_rotatable_part(blueprint: String) -> void:' in src
assert 'confirmation_preview_viewport.size = Vector2i(384, 384)' in src
# No 5px secondary inset: the 3D grid and its border occupy one square.
for side in ("left", "right", "top", "bottom"):
    assert f"square_skin.content_margin_{side} = 0.0" in confirm
assert "square_skin.set_border_width_all(1)" in confirm
for required in [
    "confirmation_preview_host.visible = true",
    'confirmation_title.text = "以下の装備を作成します" if is_craft else title',
    'confirmation_prompt.text = "作成しますか？" if is_craft else',
]:
    assert required in src,required
assert 'confirmation_preview_host.visible = false' in src
assert 'SubViewport.UPDATE_DISABLED' in src
for test in ["py tools/labo_square_craft_confirmation_self_check.py",
             "gd tools/labo_square_craft_confirmation_runtime_check.gd"]:
    assert test in manifest, test
print("SERA_LABO_SQUARE_CONFIRM_STATIC_OK")

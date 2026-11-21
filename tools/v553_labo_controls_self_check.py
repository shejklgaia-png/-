#!/usr/bin/env python3
"""LABO: confirmation layout, font-free markings and 1..99 selectors."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
marks = (root / "scripts/sera_mark_icon.gd").read_text(encoding="utf-8")
materials = (root / "scripts/sera_base_materials.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const MAX_BATCHES: int = 99" in materials
assert "batches > MAX_BATCHES" in materials
assert "var amount := SpinBox.new()" not in base
for token in ("ConversionStepper_", "ConversionMinus_", "ConversionCountFrame_",
              "ConversionCount_", "ConversionPlus_", 'amount_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER',
              'amount_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER',
              'increment.disabled = conversion_batches >= BaseMaterials.MAX_BATCHES',
              'decrement.disabled = conversion_batches <= 1'):
    assert token in base, token
for token in ('LaboConfirmCraftCard', 'LaboConfirmItemIcon',
              'LaboConfirmItemStats', 'LaboConfirmLayout', 'LaboConfirmPrompt',
              'LaboConfirmItemName', '_craft_selected_prototype, selected_prototype'):
    assert token in base, token
# A single prominent craft headline, enlarged equipment preview and a short
# decision question must replace the redundant confirmation labels/notice.
for obsolete in ('LaboConfirmSaveNotice', '作成後、この装備は倉庫に保存されます。',
                 '装備の作成確認', 'LaboStats.baseline(equipment_blueprint)\n'):
    assert obsolete not in base, obsolete
for token in (
    'confirmation_title.text = "以下の装備を作成します" if is_craft else title',
    'confirmation_prompt.text = "作成しますか？" if is_craft else',
    'confirmation_system.visible = not is_craft',
    'confirmation_subtitle.visible = not is_craft',
    'confirmation_craft_card.custom_minimum_size.y = 610.0',
    'confirmation_preview_square.ratio = 1.0',
    'confirmation_item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)',
    'craft_info_column.alignment = BoxContainer.ALIGNMENT_CENTER',
    'var craft_info := VBoxContainer.new()',
    'confirmation_item_name.add_theme_font_size_override("font_size", 30)',
    'confirmation_item_stats.add_theme_font_size_override("font_size", 19)',
    'LaboStats.baseline(equipment_blueprint).replace("（現行Aセット参照）", "")',
):
    assert token in base, token
assert 'func _request_confirmation(' in base
assert 'func _dismiss_confirmation()' in base
assert 'func _accept_confirmation()' in base
for token in ('_add_labo_mark_icon(junk_button, "junk")',
              '_add_labo_mark_icon(favorite, "favorite")',
              '_add_labo_mark_icon(junk, "junk")',
              'FavoriteMarkIcon', 'JunkMarkIcon'):
    assert token in base + warehouse, token
assert 'title.text = str(entry.get("name", ""))' in warehouse
assert 'title.text = mark +' not in warehouse
# Successful mark changes are represented by icons, not redundant SYSTEM notices.
assert '"分類を保存しました。"' not in base
for token in (
    'var warehouse_header_marks: HBoxContainer',
    'detail_marks.name = "WarehouseDetailHeaderMarks"',
    '"WarehouseHeaderFavoriteMarkIcon"',
    '"WarehouseHeaderJunkMarkIcon"',
    '_set_warehouse_header_marks(bool(item.get("favorite", false)),',
    'func _set_warehouse_header_marks(favorite: bool = false, junk: bool = false) -> void:',
    '_set_warehouse_header_marks()',
):
    assert token in base, token
for token in (
    'var inline_mark_size: float = clampf(_card_width * 0.09, 20.0, 28.0)',
    'var marker_x: float = title.position.x + title.size.x + name_to_mark_gap',
    'var name_width: float = label_font.get_string_size(',
    'while marked_count > 0 and font_px > 17 and name_width > available_name:',
    'title.add_theme_font_size_override("font_size", font_px)',
    'favorite_mark.position = Vector2(marker_x, mark_y)',
    'junk_mark.position = Vector2(marker_x, mark_y)',
):
    assert token in warehouse, token
assert 'draw_colored_polygon(points, tint)' in marks
assert 'draw_rect(' in marks
assert 'py tools/v553_labo_controls_self_check.py' in manifest
assert 'gd tools/v553_labo_controls_runtime_check.gd' in manifest
print("SERA_V553_LABO_CONTROLS_STATIC_PASS")

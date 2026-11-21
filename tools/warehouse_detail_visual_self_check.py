#!/usr/bin/env python3
"""Warehouse detail modal uses the SERA matte technical design language."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root / "scripts/sera_warehouse_detail_popup.gd").read_text("utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")
for required in (
    'const ChamferSkin = preload("res://scripts/sera_chamfer_skin.gd")',
    'const MarkIcon = preload("res://scripts/sera_mark_icon.gd")',
    'name = "WarehouseEquipmentDetailPopup"',
    'panel.name = "WarehouseDetailWindow"',
    'ChamferSkin.style(Color("#0d1b27"), Color("#55798a"))',
    'WarehouseDetailEyebrow',
    'WarehouseDetailSectionRule',
    'WarehouseDetailMark',
    'WarehouseDetailPreviewFrame',
    'WarehouseDetailPreviewCenter',
    'WarehouseDetail3D',
    'WarehouseDetailStatsScroll',
    'WarehouseDetailControls',
    'close.custom_minimum_size = Vector2(48, 48)',
    'close.size_flags_vertical = Control.SIZE_SHRINK_CENTER',
    'WarehouseFavoriteToggle',
    'WarehouseJunkToggle',
    'LaboSkin.attach_name_underline(detail_name)',
    'stats_container.add_child(table)',
    'preview.call("show_part", blueprint)',
    'preview.call("set_preview_active", false)',
    'set_prototype_mark',
    'Color("#f6cd4f")',
    'Color("#fa6570")',
):
    assert required in src, required
assert 'favorite_button.text = ("★' not in src, "mark glyphs must use vectors"
assert 'LaboSkin.panel_style()' not in src, "no gradient LABO base panel in detail"
assert 'py tools/warehouse_detail_visual_self_check.py' in manifest
assert 'gd tools/warehouse_detail_visual_runtime_check.gd' in manifest
print("SERA_WAREHOUSE_DETAIL_VISUAL_STATIC_PASS")

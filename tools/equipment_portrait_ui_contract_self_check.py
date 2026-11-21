#!/usr/bin/env python3
"""Approved SERA 19-part oblique portraits and one-window UX contract."""
from pathlib import Path

root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text(encoding="utf-8")
capture=read("tools/icon_studio/sera_all_native_capture.gd")
tag=read("tools/icon_studio/tag_all_icons.py")
preview=read("tools/equipment_intake/godot_preview.gd")
nexus=read("scripts/command_nexus.gd")
warehouse=read("scripts/base_facility_system.gd")
window=read("scripts/sera_warehouse_detail_popup.gd")
viewer=read("scripts/sera_part_preview_widget.gd")
glyph=read("scripts/sera_rotatable_mark.gd")
equipment=read("scripts/sera_equipment.gd")
workflow=read(".github/workflows/sera-model-policy.yml")
manifest=read("tools/sera_ci_manifest.txt")

# Same top-right three-quarter view, not previous per-slot rotations.
assert 'const OBLIQUE_POSE: Vector3 = Vector3(26.0, -34.0, 0.0)' in capture
assert "if id == \"H02\":\n            continue" not in capture
assert 'const POSE_NAMES = ["NEXUS_pose", "NEXUSpose"]' in capture
assert 'rig.call("_apply_animation", 0.0)' in capture
assert 'func _equalize_transparent_margins(' in capture
assert 'SIDE_PADDING: int = 34' in capture
assert 'alpha > 0.10' in capture
assert 'count != 19' in capture
assert 'OBLIQUE_POSE = (26.0, -34.0, 0.0)' in tag
assert 'SERA_ICON_PNG_V1' in tag and 'SERA_ICON_MANIFEST_V1' in tag
assert 'if id_ == "H02":' not in tag
assert 'if view_mode == "icon":' not in preview.split("func _apply_preview_standing_pose()",1)[1].split("func _fit_full_body_clearance",1)[0]
assert "NEXUS_pose" in preview

# B booster alone is red, without modifying the rest of the part variants.
assert 'if set_id == "B":' in equipment.split("func _attach_back_booster_group",1)[1]
assert 'Color("#a9343b")' in equipment and 'Color("#ec4a4e")' in equipment
assert 'if set_id == "A":' in equipment.split("func _attach_back_booster_group",1)[1]

# Reusable actual-geometry viewer, gesture and visible cycle-arrow, no 3D
# per-list-cell cost. Close disables SubViewport updates.
for s in ("SubViewport.new()", "EquipmentPreview.new()", "func show_part(", 
          "func feed_touch(", "func feed_drag(", "SubViewport.UPDATE_DISABLED",
          "RotateCue", "func set_preview_active("):
    assert s in viewer,s
assert 'func _draw() -> void:' in glyph and 'draw_arc(' in glyph
assert 'const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")' in window
for s in ("WarehouseEquipmentDetailPopup", "DetailName", "DetailIcon",
          "WarehouseDetailStatsScroll", "WarehouseDetail3D", 
          "WarehouseFavoriteToggle", "WarehouseJunkToggle",
          "StatTable.build(", "func open_item(", "func close_item("):
    assert s in window,s
assert 'var warehouse_detail_popup:' in warehouse
assert '_show_warehouse_item_detail(str(item.get("uid", "")))' in warehouse
assert 'warehouse_detail_popup.open_item(' in warehouse
assert 'warehouse_detail_popup.is_open()' in warehouse
assert 'get_node_or_null("SeraSave")' in window

# Full aggregate top: 3 adaptive columns, dividers. Left small rotated
# active part. Right buttons only actual names, 3-col scroll picker.
for s in ("hud.add_child(customize_stats_scroll)",
          "StatColumnRule", "customize_stats_grid.columns = 3",
          "CustomizeSinglePartPreview", "CustomizeBodyRotateCue",
          "CustomizePartPickerOverlay", "CustomizePartPickerScroll",
          "customize_part_grid.columns = 3", "func _show_customization_part_picker(",
          "func _choose_customization_part(", "func _close_customization_part_picker(",
          "func _refresh_single_part_preview(", "customize_part_picker.visible",
          "SeraSave.equip_prototype(", "SeraSave.clear_equipped_prototype("):
    assert s in nexus,s
assert 'selectable.find(current_choice)' not in nexus
assert 'if Rect2(row.position, row.size).has_point(local)' in nexus
assert 'nexus_equipment' not in nexus # no leaked old component singleton
assert "gd tools/equipment_portrait_ui_runtime_check.gd" in manifest
assert "py tools/equipment_portrait_ui_contract_self_check.py" in manifest
assert "sera_all_native_capture.gd" in workflow
print("SERA_EQUIPMENT_PORTRAIT_UI_STATIC_PASS")

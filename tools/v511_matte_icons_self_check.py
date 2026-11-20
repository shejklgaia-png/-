#!/usr/bin/env python3
"""v511: exact matte artwork atlas and complete icon/blueprint coverage."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
icon_script = (ROOT/"scripts/sera_item_icons.gd").read_text(encoding="utf-8")
catalog = (ROOT/"scripts/sera_prototype_catalog.gd").read_text(encoding="utf-8")
ui = (ROOT/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
save = (ROOT/"scripts/sera_save.gd").read_text(encoding="utf-8")
nexus = (ROOT/"scripts/command_nexus.gd").read_text(encoding="utf-8")
atlas = ROOT/"assets/ui/sera_matte_icon_atlas.webp"
assert atlas.is_file() and atlas.stat().st_size > 14000, "matte atlas missing/placeholder"
assert atlas.read_bytes()[:4] == b"RIFF" and atlas.read_bytes()[8:12] == b"WEBP"
# Pixel-art materials occupy a separate 3x4 sheet. Existing equipment tiles
# remain untouched in the original 4x5 atlas.
pixel_atlas = ROOT/"assets/ui/sera_pixel_material_atlas.webp"
assert pixel_atlas.is_file() and pixel_atlas.stat().st_size > 7000, "new materials atlas missing"
pixel_data = pixel_atlas.read_bytes()
assert pixel_data[:4] == b"RIFF" and pixel_data[8:12] == b"WEBP"
# The VP8X header contains the exact canvas size as two 24-bit little-endian
# values, with width and height stored minus one.
assert pixel_data[12:16] == b"VP8X", "material art needs alpha-aware WebP"
width = int.from_bytes(pixel_data[24:27], "little") + 1
height = int.from_bytes(pixel_data[27:30], "little") + 1
assert (width, height) == (216, 288), f"unexpected material atlas size: {width}x{height}"
assert 'MATERIAL_ATLAS_PATH' in icon_script
assert 'MATERIAL_COLUMNS: int = 3' in icon_script
assert 'return _material_frame(int(MATERIAL_INDICES[material_id]))' in icon_script
assert "func material_icon(" in icon_script and "func equipment_icon(" in icon_script
assert "const PROTOTYPES" in catalog and '"H01"' in catalog and '"WL01"' in catalog
assert "func craft_prototype(" in save and "func get_owned_prototypes(" in save
assert "func uid_for(" in catalog and "func valid_uid(" in catalog
assert "PrototypeCatalog.uid_for(" in save and "PrototypeCatalog.valid_uid(" in save
assert "func equip_prototype(" in save
assert "func _show_prototype_catalog(" in ui and "func _show_inventory(" in ui
assert "MaterialIcon_" in ui and "PrototypeIcon_" in ui and "ConvertInputIcon" in ui
assert 'card.text = title + "\\n" + info' in ui and "PrototypeIcon_" in ui and "WarehouseItem_" in (ui + (ROOT/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8"))
assert "SourceRank" in ui and "TargetRank" in ui
assert "PrototypeCatalog.display_instance(" in ui
assert "func _tap_equipment_control(" in nexus and "equipped_prototype" in nexus
assert "gd tools/v511_matte_icons_runtime_check.gd" in (
    ROOT/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
print("SERA_MATTE_ICON_STATIC_PASS")

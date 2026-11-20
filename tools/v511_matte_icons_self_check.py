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
assert "func material_icon(" in icon_script and "func equipment_icon(" in icon_script
assert "const PROTOTYPES" in catalog and '"H01"' in catalog and '"WL01"' in catalog
assert "func craft_prototype(" in save and "func get_owned_prototypes(" in save
assert "func uid_for(" in catalog and "func valid_uid(" in catalog
assert "PrototypeCatalog.uid_for(" in save and "PrototypeCatalog.valid_uid(" in save
assert "func equip_prototype(" in save
assert "func _show_prototype_catalog(" in ui and "func _show_inventory(" in ui
assert "MaterialIcon_" in ui and "PrototypeIcon_" in ui and "ConvertInputIcon" in ui
assert 'card.text = title + "\\n" + info' in ui and "PrototypeIcon_" in ui and "WarehouseBlueprint_" in ui
assert "SourceRank" in ui and "TargetRank" in ui
assert "PrototypeCatalog.display_instance(" in ui
assert "func _tap_equipment_control(" in nexus and "equipped_prototype" in nexus
assert "gd tools/v511_matte_icons_runtime_check.gd" in (
    ROOT/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
print("SERA_MATTE_ICON_STATIC_PASS")

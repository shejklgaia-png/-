#!/usr/bin/env python3
"""Reference-style LABO UI cards: reusable native button + clipped art."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
scenes = ["LaboMaterialCard.tscn", "LaboEquipmentCard.tscn", "LaboSectionTab.tscn"]
for name in scenes:
    scene = root / "ui" / "labo" / name
    assert scene.is_file(), name
    data = scene.read_text(encoding="utf-8")
    assert 'type="Button"' in data, name
    if "Card" in name:
        for node in ["CardContent", "Row", "ItemArt", "ItemTitle", "ItemInfo"]:
            assert ('name="' + node + '"') in data, (name, node)
        assert 'type="TextureRect"' in data
        assert 'mouse_filter = 2' in data, "child must not intercept native Button input"
for anchor in ['LaboMaterialCardScene.instantiate()', 'LaboEquipmentCardScene.instantiate()',
               'LaboSectionTabScene.instantiate()', 'var art: TextureRect = card.get_node(',
               'art.texture = texture', 'card.icon = null',
               'source_icon.texture = IconAtlas.material_icon_sized(source_id, 48)',
               'output_icon.texture = IconAtlas.material_icon_sized(target_id, 44)']:
    assert anchor in ui, anchor
assert 'bar.icon = ' not in ui, "conversion bar cannot render image through Button.icon"
assert 'func card_style(' in skin and 'StyleBoxTexture.new()' in skin
assert 'return LaboSkin.card_style(kind)' in warehouse
assert 'const MAX_POOL_CARDS: int = 32' in warehouse
assert 'py tools/v533_labo_visual_self_check.py' in manifest
assert 'gd tools/v533_labo_visual_runtime_check.gd' in manifest
print("SERA_V533_LABO_VISUAL_STATIC_PASS")

#!/usr/bin/env python3
"""v527: prevent missing Android-editor import cache from blanking every LABO card."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
icons = (root / "scripts/sera_item_icons.gd").read_text(encoding="utf-8")
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# The WebP source must be loadable even if Android editor has no imported
# Texture2D. Eager preload reintroduces the import-cache failure.
assert 'const ATLAS: Texture2D = preload(' not in icons
assert 'static func _decode_webp_source(' in icons
assert 'FileAccess.file_exists(' in icons
assert 'FileAccess.get_file_as_bytes(' in icons
assert 'load_webp_from_buffer(' in icons
assert 'ResourceLoader.exists(' in icons
assert 'static func atlas_status(' in icons
assert 'static func material_icon(' in icons and 'static func equipment_icon(' in icons
# Native card creation must not depend on icon decoding and errors. This keeps
# blank, clipped-corner framed cards visible even without the WebP.
assert 'func _queue_card_icon(' in ui and 'func _apply_card_icon(' in ui
assert 'call_deferred("_apply_card_icon"' in ui
assert 'func _apply_card_skin(' in ui and 'call_deferred("_apply_card_skin"' in ui
assert 'row.add_child(card)' in ui and 'card.text = title + "\\n" + info' in ui
for premature in (
    'var icon: Texture2D = IconAtlas.material_icon(id)',
    'var icon: Texture2D = IconAtlas.equipment_icon(id)',
    'trial.icon = IconAtlas.material_icon("scrap_mid")',
):
    assert premature not in ui, "icon decoding must not block creating all rows: " + premature
assert 'IconAtlas.atlas_status()' in ui
assert 'py tools/v527_android_icon_resilience_self_check.py' in manifest
assert 'gd tools/v527_android_icon_resilience_runtime_check.gd' in manifest
print("SERA_V527_ANDROID_ICON_RESILIENCE_STATIC_PASS")

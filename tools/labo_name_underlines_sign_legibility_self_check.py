#!/usr/bin/env python3
"""SERA: resolve unreadable 3D Latin signs and apply subtle underlines to names."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
facility = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
stage = (root / "scripts/labo_hero_stage.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert 'const NAME_UNDERLINE_COLOR: Color = Color("#55798a")' in skin
for token in ('static func attach_name_underline(label: Label) -> void:',
              'static func refresh_name_underline(label: Label) -> void:',
              'label.resized.connect(refresh_name_underline.bind(label), CONNECT_DEFERRED)',
              'line.mouse_filter = Control.MOUSE_FILTER_IGNORE',
              'font.get_string_size(',
              'line.visible = false'):
    assert token in skin, token
for token in ('LaboSkin.attach_name_underline(modal_title)',
              'LaboSkin.attach_name_underline(title_label)',
              'LaboSkin.refresh_name_underline(label)'):
    assert token in facility, token
for token in ('LaboSkin.attach_name_underline(title)',
              'LaboSkin.refresh_name_underline(title)'):
    assert token in warehouse, token
for token in ('LaboSkin.attach_name_underline(focus_title)',
              'LaboSkin.attach_name_underline(entry["label"] as Label)',
              'LaboSkin.attach_name_underline(part["value"] as Label)'):
    assert token in nexus, token
assert 'hero_host.stretch_shrink = 1' in facility
assert 'label.font = LaboSkin.display_font()' in stage
assert 'label.outline_size = 2' in stage
assert 'py tools/labo_name_underlines_sign_legibility_self_check.py' in manifest
assert 'gd tools/labo_name_underlines_sign_legibility_runtime_check.gd' in manifest
print("SERA_LABO_NAME_UNDERLINES_SIGNS_STATIC_PASS")

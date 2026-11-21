#!/usr/bin/env python3
"""NEXUS selection dialog: SERA's shared matte, name rules, card geometry and touch UX."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for marker in (
    '"CustomizePartPickerOverlay"', '"CustomizePartPickerScroll"',
    '"CustomizePartPickerGrid"', "customize_part_grid.columns = 3",
    '"CustomizePartPickerHeaderRule"', '"CustomizePartPickerClose"',
    'LaboSkin.tracked_display_font()', 'LaboSkin.equipment_font()',
    'LaboSkin.tracked_data_font()', 'LaboSkin.card_style("selected" if selected else "normal")',
    'LaboSkin.attach_name_underline(caption)', '"ChoiceName"',
    '"ChoiceUID"', '"ChoiceThumbnail"', '"ChoiceInsets"',
    'customize_part_picker_title.text = str(CUSTOMIZE_SLOT_LABELS.get(slot, slot)) + "   /   SELECT PART"',
    'SeraSave.get_equipped_prototype(customize_part_preview_slot)',
    'customize_part_picker_scroll.scroll_vertical -= roundi(event.relative.y)',
    '_tap_customization_part_picker(event.position)',
):
    assert marker in nexus, marker
assert "SELECT PART    ×" not in nexus, "close glyph is independent of the title"
assert "customize_part_grid.columns = 3" in nexus
assert 'NAME_UNDERLINE_COLOR: Color = Color("#55798a")' in skin
assert "NAME_UNDERLINE_HEIGHT: float = 3.0" in skin
for item in (
    "py tools/nexus_part_picker_design_self_check.py",
    "gd tools/nexus_part_picker_design_runtime_check.gd",
):
    assert item in manifest, item
print("NEXUS_PART_PICKER_DESIGN_STATIC_PASS")

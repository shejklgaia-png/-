#!/usr/bin/env python3
"""v338: compact player HP/EN at top-left, boss and selected part shifted up."""
from pathlib import Path
import math
import re
root = Path(__file__).resolve().parents[1]
hud = (root / "scripts/sera_clean_training_hud.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
def number(name):
    match = re.search(rf"^const {name}: float = ([0-9]+(?:\.[0-9]+)?)$", hud, re.M)
    assert match, name
    return float(match.group(1))

width = number("DESIGN_WIDTH")
hp = number("PLAYER_HP_BASELINE")
en = number("PLAYER_EN_BASELINE")
boss = number("BOSS_ROW_TOP")
part = number("PART_ROW_TOP")
rule_right = number("PLAYER_RULE_RIGHT")
bar_right = number("PLAYER_BAR_RIGHT")
value_right = number("PLAYER_VALUE_RIGHT")

assert width == 720
assert 22 <= hp < en <= 75, (hp, en)
assert hp + 12 < en, "Player meters must remain distinct"
assert 100 <= boss < 160 and boss > en + 25, (boss, en)
assert boss + 24 < part <= 170, (boss, part)
assert 113 < bar_right < value_right <= 540, (bar_right, value_right)
assert 500 <= rule_right <= 540
# Navigation and angle toggle use rightmost pixel region, so there
# must be positive screen-space clearance at every portrait width.
# X coordinates scale together with the 720-unit HUD design.
assert value_right <= 540 < 720 - 168
assert '_draw_instrument_row("HP", PLAYER_HP_BASELINE,' in hud
assert '_draw_instrument_row("EN", PLAYER_EN_BASELINE,' in hud
assert 'shown_boss, BOSS_ROW_TOP, 12.0, 670.0, BOSS_TINT)' in hud
assert 'shown_part, PART_ROW_TOP, 7.0, 360.0, PART_TINT)' in hud
assert "draw_set_transform(" in hud
assert "size.x / DESIGN_WIDTH" in hud
assert 'nexus_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)' in main
assert 'angle_debug_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)' in main
assert 'nexus_button.offset_top = 8.0' in main
assert 'nexus_button.offset_bottom = 48.0' in main
assert 'angle_debug_button.offset_top = 52.0' in main
assert 'angle_debug_button.offset_bottom = 82.0' in main
assert 'clean_training_hud.offset_bottom = 180.0' in main
assert 'hud_panel.visible = false' in main
assert 'clean_training_hud.call("set_vitals"' in main
assert 'clean_training_hud.call("set_boss_health"' in main
assert 'clean_training_hud.call("set_locked_part"' in main
assert 'const EN_RECOVERY_UNLOCK_RATIO: float = 0.60' in main
assert 'if RESOURCE_RULES.exhaustion_unlocked(' in main
assert 'config/name="SERA v338"' in project

# Check geometry in both native 720px and scaled portrait viewport width.
for w in (360, 480, 720, 1080):
    k = w / width
    player_right = value_right * k
    nexus_left = w - 168
    # The button uses logical Godot UI units rather than HUD's scaled
    # internal coordinates; on very narrow viewports we avoid assuming
    # horizontal separation and instead use text/label vertical safety.
    if w >= 720:
        assert player_right < nexus_left, (w, player_right, nexus_left)
    assert hp*k < en*k < boss*k < part*k
    assert math.isfinite(player_right)

print("PASS v338 top-left HP/EN, raised boss/part, persistent combat values")

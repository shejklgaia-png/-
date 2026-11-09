#!/usr/bin/env python3
"""SERA v202: compact left-upper HP/EN HUD and EN 60% re-use lock."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
hud = read("scripts/combat_vitals.gd")
project = read("project.godot")
match = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert match and int(match.group(1)) >= 202
assert (ROOT / "README_v202_ja.md").is_file()

# No extra giant overlay: both read-only meters sit inside the existing header.
overlay = main.split("func _build_overlay() -> void:", 1)[1].split(
    "func _refresh_player_hp_bar() -> void:", 1)[0]
assert 'const CombatVitals = preload("res://scripts/combat_vitals.gd")' in main
for token in (
    'hud_panel.name = "CompactCombatHUD"',
    'vitals_hud = CombatVitals.new()',
    'vitals_hud.name = "CombatVitals"',
    'vitals_hud.position = Vector2(27.0, 62.0)',
    'vitals_hud.size = Vector2(190.0, 61.0)',
    'vitals_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE',
    'hud_panel.add_child(vitals_hud)',
    'hp_label.position = Vector2(414.0, 80.0)',
    'bar_background.position = Vector2(414.0, 105.0)',
    'resources_label.position = Vector2(226.0, 103.0)',
):
    assert token in overlay, token
assert "player_hp_label = Label.new()" not in overlay
assert 'resources_label.text = "DEF %d%%  SH %d"' in main
assert "TARGET_HP_BAR_WIDTH * float(target_hp)" in main

meter = main.split("func _refresh_player_hp_bar() -> void:", 1)[1].split(
    "func _refresh_hp_bar() -> void:", 1)[0]
assert 'vitals_hud.call("set_vitals", player_hp,' in meter
assert "energy, TEST_EN_MAX, energy_exhausted" in meter
assert "extends Control" in hud and "MOUSE_FILTER_IGNORE" in hud
assert 'SECOND_ROW_Y: float = 31.0' in hud
assert 'LOW_RATIO: float = 0.25' in hud
assert '_draw_meter(0.0, "HP"' in hud
assert '_draw_meter(SECOND_ROW_Y, "EN"' in hud
assert 'hp_frame.a = _breath(1.25)' in hud
assert 'en_frame.a = _breath(1.25)' in hud
assert 'en_frame.a = _breath(4.0)' in hud
assert 'elif en_locked:' in hud
assert 'en_fill = MUTED' in hud and 'en_frame = MUTED' in hud
assert 'en_detail = "RECOVER  %d%%"' in hud
assert 'if hp_ratio <= 0.0:\n        hp_fill = MUTED\n        hp_frame = MUTED' in hud
assert 'elif hp_ratio <= LOW_RATIO:' in hud

spend = main.split("func _spend_energy(amount: float) -> bool:", 1)[1].split(
    "func _tick_resources(delta: float) -> void:", 1)[0]
assert spend.index("if energy_exhausted:\n        return false") < spend.index(
    "if energy + 0.0001 < amount:")
assert "if energy <= 0.0001:\n        energy_exhausted = true" in spend
resources = main.split("func _tick_resources(delta: float) -> void:", 1)[1].split(
    "func _take_test_damage(", 1)[0]
assert 'const EN_RECOVERY_UNLOCK_RATIO: float = 0.60' in main
assert 'if energy_exhausted and energy >= TEST_EN_MAX * EN_RECOVERY_UNLOCK_RATIO:' in resources
assert 'energy_exhausted = false' in resources
assert 'energy >= 16.0' not in resources
boost = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "if guard_active and bool(part_stats.get", 1)[0]
assert 'if not boost_energy_ok and not energy_exhausted:' in boost
assert 'energy = 0.0\n                energy_exhausted = true' in boost
assert 'boost_rearm_required = true' in boost
assert "energy = TEST_EN_MAX\n    shield = TEST_SH_MAX\n    energy_exhausted = false" in main

# Numerical invariants: lock at EN=0; do not allow positive spend until 60%.
class Energy:
    def __init__(self):
        self.en = 100.0
        self.locked = False
    def spend(self, amount):
        if amount <= 0:
            return True
        if self.locked or self.en + 0.0001 < amount:
            return False
        self.en = max(0.0, self.en - amount)
        if self.en <= 0.0001:
            self.locked = True
        return True
    def regen(self, amount):
        self.en = min(100.0, self.en + amount)
        if self.locked and self.en >= 60.0:
            self.locked = False

e = Energy()
assert e.spend(100)
assert e.locked and e.en == 0
for value in (0.1, 10.0, 25.0, 59.9):
    e.en = value
    assert e.locked and not e.spend(0.1)
e.en = 59.9
e.regen(0.1)
assert math.isclose(e.en, 60.0) and not e.locked
assert e.spend(20.0) and math.isclose(e.en, 40.0)
assert e.spend(0.0)
# BOOST: insufficient last tick counts as depleted, not a partial-cost loop.
e.en = 0.1
e.locked = False
if not e.spend(0.4) and not e.locked:
    e.en, e.locked = 0.0, True
assert e.en == 0 and e.locked
assert not e.spend(1.0)
# Smooth alpha is bounded and has independent normal/empty rates.
for hz in (1.25, 4.0):
    for x in range(100):
        alpha = 0.30 + 0.70 * (0.5 + 0.5 * math.sin(math.tau * hz * x / 60))
        assert 0.30 - 1e-10 <= alpha <= 1.0 + 1e-10

print("PASS: v202 HP/EN HUD layout, warning/failure/recovery states, EN 60% lock")
print("Godot runtime / Xperia Android: NOT TESTED")

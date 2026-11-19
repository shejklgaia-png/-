#!/usr/bin/env python3
"""v514: intact shield is a solid membrane; only shatter leaves a center hole."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
fx = (ROOT / "scripts/enemy_shield_hit_fx.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v([0-9]+)"', project)
assert 'func _draw_impact(' in fx and 'func _fracture(' in fx
ordinary = fx.split("func _draw_impact(", 1)[1].split("func _redraw(", 1)[0]
shatter = fx.split("func _fracture(", 1)[1].split("static func contact_radius_px(", 1)[0]
# An opaque colored *disc* occupies the impact center for the entire visible
# life of an intact membrane; the white contact flash may fade independently.
assert "_ring(center, 0.0, radius * 0.20, core, core, depth)" in ordinary
assert "membrane_center_color(tone, opacity, flash)" in ordinary
assert "core.a = 0.94 * opacity" in fx
assert "tone.lerp(Color.WHITE, 0.38 * flash)" in fx
# Only on break may an expanding hole be opened. Neither crack nor shards
# change the intact shield drawing or punch a hole through the HP bar.
assert "var hole_radius: float = radius * lerpf(0.14, 0.23, burst)" in shatter
assert "_ring(center, hole_radius, radius * 0.27," in shatter
assert "_ring(center, 0.0" not in shatter
assert "func _fracture(" in fx and "if burst > 0.0:" in shatter
assert "SHIELD_IMPACT" in fx and "material.no_depth_test = false" in fx
assert '"res://scripts/enemy_shield_hit_fx.gd"' in main
for path in (
    "scripts/sera_numeric_hud.gd",
    "scripts/sera_clean_training_hud.gd",
    "scripts/combat_vitals.gd",
):
    assert "shield_hit_fx" not in (ROOT / path).read_text(encoding="utf-8")
print("PASS v514: solid impact membrane, hole only on shatter, crisp depth-based FX")

#!/usr/bin/env python3
"""v516: six hard-edged octagonal frames, sequential emergence and glass burst."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT/path).read_text(encoding="utf-8")
s = read("scripts/enemy_shield_hit_fx.gd")
t = read("tools/sera_ci_manifest.txt")
assert "const FRAME_COUNT: int = 6" in s
assert "const FRAME_SIDES: int = 8" in s
# v519: widen ONLY the intact octagon frames and filled center, not impacts.
assert "const OCTAGON_HORIZONTAL_STRETCH: float = 1.15" in s
assert "cos(angle) * OCTAGON_HORIZONTAL_STRETCH" in s
assert "return Vector2(cos(angle) * OCTAGON_HORIZONTAL_STRETCH, sin(angle))" in s
assert "const EXPAND_SECONDS: float = 0.20" in s
assert "const HOLD_SECONDS: float = 0.20" in s
assert "const FADE_SECONDS: float = 0.20" in s
assert "const IMPACT_SECONDS: float = 0.60" in s
assert "const CRACK_EXTEND_SECONDS: float = 0.065" in s
assert "const CRACK_FADE_END_SECONDS: float = 0.16" in s
assert "const GLASS_SHARD_COUNT: int = 14" in s
assert "func _octagon_frame(" in s and "func _octagon_disc(" in s
assert "func _frame_outer_radius(" in s
assert "var inner_radius: float" in s
assert "const VISUAL_SIZE_MULTIPLIER: float = 0.30" in s
assert "func _draw_glass_shard(" in s
assert "static func frame_alpha(" in s
assert "static func visible_frame_count(" in s
assert "static func crack_tip_opacity(" in s
assert "func _fracture(" in s and 'entry["shards"]' in s
assert "func _ring(" not in s, "old radial-gradient blur must be removed"
assert "smoothstep(0.68, 1.0" in s, "crack tip must taper to alpha zero"
assert "material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX" in s
assert "material.no_depth_test = false" in s
assert "material.render_priority = RENDER_ORDER.SHIELD_IMPACT" in s
assert "gd tools/v516_octagonal_shield_runtime_check.gd" in t
assert "py tools/v516_octagonal_shield_self_check.py" in t
for name in ("scripts/sera_numeric_hud.gd", "scripts/sera_clean_training_hud.gd"):
    assert "shield_hit_fx" not in read(name)
print("PASS v516: six crisp octagons, 0.2/0.2/0.2s and glass shards")

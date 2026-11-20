#!/usr/bin/env python3
"""v524: contiguous octagon bands, 30%-size VFX and one-color decelerating shards."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fx = (ROOT / "scripts/enemy_shield_hit_fx.gd").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# These requirements come from the approved visual spec, not current implementation.
assert "const VISUAL_SIZE_MULTIPLIER: float = 0.30" in fx
assert "* VISUAL_SIZE_MULTIPLIER" in fx
assert "const FRAME_COUNT: int = 6" in fx
assert "const FRAME_SIDES: int = 8" in fx
assert "func _frame_outer_radius(" in fx
assert "var inner_radius: float" in fx
assert "_octagon_frame(center, radius, inner_radius, frame_color, depth)" in fx
assert "func _octagon_disc(" in fx
assert "const GLASS_SHARD_COUNT: int = 14" in fx
assert "const GLASS_SHARD_COLOR: Color =" in fx
assert "static func shard_distance_px(" in fx
assert "1.0 - pow(1.0 - travel, 2.0)" in fx
assert 'rng.randf_range(0.0, TAU)' in fx
for field in ("spawn", "angle", "speed", "length", "width", "tilt", "spin", "notch", "tip_bias"):
    assert f'"{field}"' in fx, f"glass shard must randomize {field}"
assert "bright := Color(" not in fx and "cyan := Color(" not in fx, (
    "individual glass shard triangles must share a single tint")
assert "gd tools/v524_shield_shards_runtime_check.gd" in manifest
assert "py tools/v524_shield_shards_self_check.py" in manifest
print("PASS v524: seamless six-sided layers, 0.30 scale, single-color randomized easing shards")

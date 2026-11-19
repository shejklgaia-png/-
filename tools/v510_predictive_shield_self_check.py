#!/usr/bin/env python3
"""v510: predictive shield is a contact effect, never an HP bar overlay."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
main = read("scripts/main.gd")
boss = read("scripts/bittaran_battle.gd")
shield = read("scripts/enemy_predictive_shield.gd")
fx = read("scripts/enemy_shield_hit_fx.gd")
order = read("scripts/render_order_policy.gd")
assert "const MAX_SP: float = 100.0" in shield
assert "const MELEE_REDUCTION: float = 0.25" in shield
assert "const RANGED_REDUCTION: float = 0.95" in shield
assert "const REGEN_DELAY: float = 4.0" in shield
assert "const REGEN_PER_SECOND: float = 20.0" in shield
assert "const ENEMY_SHIELD_SCRIPT = preload(" in main
assert "const ENEMY_SHIELD_FX_SCRIPT = preload(" in main
assert "enemy_predictive_shield.apply_hit(" in main
assert "shield_hit_fx.call(\"start_impact\"" in main
assert "shield_hit_fx.call(\"advance\"" in main
assert "enemy_predictive_shield.reset()" in main
assert "super._apply_target_part_damage(" in boss
assert "super._build_hit_effects()" not in boss  # inherited _build_hit_effects in _ready
assert "const SHIELD_IMPACT: int = 115" in order
assert "material.render_priority = RENDER_ORDER.SHIELD_IMPACT" in fx
assert "material.no_depth_test = false" in fx
assert "material.vertex_color_use_as_albedo = true" in fx
# v512: alpha compositing preserves the saturated cyan/yellow/red state colors.
assert "material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX" in fx
assert "material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD" not in fx
assert "static func contact_opacity(progress: float) -> float:" in fx
assert "static func contact_core_flash(progress: float) -> float:" in fx
assert "const CRACK_EXTEND_SECONDS: float = 0.065" in fx
assert "const CRACK_FADE_END_SECONDS: float = 0.16" in fx
assert "const IMPACT_SECONDS: float = 0.60" in fx
assert "const FRACTURE_SECONDS: float = 0.65" in fx
assert "func state_color(ratio: float)" in fx
assert "AudioStreamWAV.new()" in fx
# v511: the shield must be visibly in front of armor even at oblique hit angles.
assert "SHIELD_SURFACE_OFFSET: float = 0.14" in fx
assert "const CONTACT_RADIUS_START_PX: float = 100.0" in fx
assert "const CONTACT_RADIUS_END_PX: float = 260.0" in fx
assert "const FRACTURE_REACH_START_PX: float = 90.0" in fx
assert "const FRACTURE_REACH_END_PX: float = 470.0" in fx
assert "const BURST_RADIUS_MAX_PX: float = 470.0" in fx
assert "const MIN_VISUAL_SCALE: float = 0.85" in fx
assert "const IMPACT_SECONDS: float = 0.60" in fx
assert "const FRACTURE_SECONDS: float = 0.65" in fx
# The only visible indicator remains the localized FX; no secondary HP overlay.
assert "func contact_radius_px(progress: float) -> float:" in fx
assert "const FRONT_OFFSET: float = 0.06" in read("scripts/hit_burst.gd")
# No shield paint or second HP meter; do not make HP loss unreadable.
assert "enemy_predictive_shield" not in read("scripts/sera_numeric_hud.gd")
assert "shield_hit_fx" not in read("scripts/sera_numeric_hud.gd")
assert "shield_hit_fx" not in read("scripts/sera_clean_training_hud.gd")
assert "shield_hit_fx" not in read("scripts/combat_vitals.gd")
print("PASS v510 shield: contract, 3D depth layer, shared training/Bittaran FX, no HP overlay")

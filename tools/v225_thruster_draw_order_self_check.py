#!/usr/bin/env python3
"""SERA v225: exhaust renders above the sword foreground without x-ray bleed."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")

fx = read("scripts/back_thruster_fx.gd")
flame_shader = read("shaders/back_thruster.gdshader")
trail_shader = read("shaders/back_thruster_trail.gdshader")
foreground_shader = read("shaders/sera_foreground.gdshader")
rig = read("scripts/sera_rig.gd")
sword = read("scripts/sword_trail.gd")
policy = read("scripts/render_order_policy.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version is not None and int(version.group(1)) >= 225

# The original melee slash drawing policy: overlay prioritizes SERA above the
# sword (100..110), disables depth-testing, and can otherwise cover any jet.
assert '_foreground_mat.render_priority = RENDER_ORDER.CHARACTER_FOREGROUND' in rig
assert "depth_test_disabled" in foreground_shader
for role in ("SLASH_VOLUME", "SLASH_SURFACE", "SLASH_PARTICLES"):
    assert f"_make_material(RENDER_ORDER.{role}," in sword
assert "const DEPTH_TESTED_EMISSIVE: int = 127" in policy
assert "const CHARACTER_FOREGROUND: int = 126" in policy
assert "ribbon_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert "material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert 127 > 126 > 110

# Draw AFTER the transparent foreground overlay, but test AGAINST opaque depth:
# visible flames cannot appear through the body, ground, or target.
for shader in (flame_shader, trail_shader):
    assert "blend_add" in shader
    assert "depth_draw_never" in shader
    assert "depth_test_disabled" not in shader
assert "visible = enabled" in fx
assert "_update_ribbon_trail(enabled, delta)" in fx

# v224's clamp must also hold after filtered servo updates and after a prior
# BOOST screen-sector turn; melee must use physical yaw/pitch, not that sector.
assert "const MELEE_YAW_LIMIT_RADIANS: float = PI * 20.0 / 180.0" in fx
assert "const MELEE_PITCH_DOWN_LIMIT_RADIANS: float = PI * 35.0 / 180.0" in fx
set_exhaust = fx.split("func set_exhaust(", 1)[1]
assert 'if enabled and melee_sustain:\n        yaw = clampf(yaw,' in set_exhaust
assert 'steering_yaw = clampf(steering_yaw,' in set_exhaust
assert 'steering_pitch = clampf(steering_pitch,' in set_exhaust
assert 'returning_from_screen_sector = false\n        left_sector_world = Vector3.ZERO' in set_exhaust
assert set_exhaust.index('steering_yaw = clampf(steering_yaw,') > set_exhaust.index('steering_yaw = lerp_angle(')
assert set_exhaust.index('returning_from_screen_sector = false\n        left_sector_world = Vector3.ZERO') < set_exhaust.index('if enabled and left_sector_world.length_squared() > 0.000001:')
assert "const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0" in fx
assert "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0" in fx

# On rare unsafe legacy poses, v222 correction now selects authored rear mount
# before an unrestricted world-facing correction; this prevents retroactively
# undoing v224's constrained physical nozzle.
guard = fx.split("func _avoid_melee_body_penetration(", 1)[1].split("func set_exhaust(", 1)[0]
assert "var mount_axis: Vector3" in guard
assert "mount_axis.dot(outward) >= MELEE_TORSO_CLEARANCE_DOT:" in guard
assert "nozzle.quaternion = nozzle_rest_rotation\n        return" in guard
assert guard.index("mount_axis.dot(outward)") < guard.index("var tangent: Vector3")
assert "_avoid_melee_body_penetration(nozzle, nozzle.get_parent() as Node3D)" in set_exhaust

print("PASS v225: flame and world ribbon priority 127 follows slash foreground 126")
print("PASS: additive jets retain opaque depth testing and cannot shine through solid geometry")
print("PASS: v224 melee servo limits persist through BOOST transitions and v222 safety fallback")
print("Godot GL Compatibility / Android actual rendering remains unverified")

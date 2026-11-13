#!/usr/bin/env python3
"""v321 active-contract checks: low RUN stance, smooth camera, visible sheath, stable materials."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
equip = (root/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
math = (root/"scripts/sera_camera_math.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")

assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 321
assert "RUN_LOW_STANCE_ROOT_Y: float = -0.235" in rig
assert "RUN_LOW_STANCE_BOB_SCALE: float = 0.25" in rig
assert "blended_translation.y = RUN_LOW_STANCE_ROOT_Y + clampf(" in rig
assert "if uid == RUN_ROOT_BONE_UUID:" in rig
assert "var facing := Quaternion(Vector3.UP, run_facing_yaw)" in rig
assert "func set_moving(" in rig
assert "var max_travel: float = maxf(16.0, rate * max_lag * 1.7) * dt" in math
assert "next = current + travel.normalized() * max_travel" in math
assert "next = desired - error.normalized() * max_lag" not in math
assert "static func stable_near_bearing(" in math
assert "CAMERA_MATH.stable_near_bearing(" in main
assert "camera_near_bearing_initialized" in main
assert 'group_name == "katana_r_saya"' in equip
assert "katana_sheathed_blade_meshes.append(child)" in equip
assert "equipped and (not is_stowed_blade or not drawn)" in equip
assert "katana_drawn_meshes.append(child)" in equip
# The authored base material (textured standard/B or author-colored C/D) must
# not be replaced with the palette-only transparent foreground slash overlay.
overlays = rig.split("func _refresh_character_overlay() -> void:", 1)[1].split(
    "func _build_motion_afterimage_pool()", 1)[0]
assert "_foreground_mat_b" not in overlays
assert "overlay = _foreground_mat" not in overlays
assert "part.material_overlay = overlay" in overlays
assert "overlay = _energy_flash_material" in overlays
assert "overlay = _ko_material_b if" in overlays
for test in ("py tools/v321_run_camera_katana_material_self_check.py",
             "gd tools/v321_run_camera_katana_material_runtime_check.gd"):
    assert test in manifest
print("SERA_V321_RUN_CAMERA_KATANA_MATERIAL_STATIC_PASS")

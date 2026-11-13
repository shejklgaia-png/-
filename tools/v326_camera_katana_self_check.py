#!/usr/bin/env python3
"""v326: camera fit floor is continuous; Katana FX respects authored transform."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
trail = (root / "scripts/sword_trail.gd").read_text(encoding="utf-8")
runtime = (root / "tools/v326_camera_katana_runtime_check.gd").read_text(encoding="utf-8")
fit = main.split("func _fit_full_frame() -> void:", 1)[1].split(
    "func _relax_camera_fit_radius", 1)[0]
relax = main.split("func _relax_camera_fit_radius(delta: float) -> void:", 1)[1].split(
    "func _place_camera()", 1)[0]
assert "var safe_floor: float" in fit and "_minimum_boost_camera_radius()" in fit
assert "camera_fit_radius_floor = maxf(camera_fit_radius_floor, safe_floor)" in fit
assert "candidate_floor = maxf(candidate_floor, safe_floor)" in relax
assert "_full_frame_safe()" in fit and "for i in range(16):" in fit
assert "effect_root.transform = source_plane.transform" in trail
assert "rotate_object_local(Vector3.UP, PI)" not in trail
assert "if katana_second:" not in trail.split("func begin_swing(", 1)[1].split("func stop_swing(", 1)[0]
assert 'Melee_katana2' in runtime and 'Melee_katana' in runtime
# The v326 camera/Swordeffect contract remains active in all later versions.
import re
version = re.search(r'config/name="SERA v(\d+)"', (root / "project.godot").read_text(encoding="utf-8"))
assert version and int(version.group(1)) >= 326
print("PASS v326 camera fit + authored Katana arc contracts")

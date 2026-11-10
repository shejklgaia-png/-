#!/usr/bin/env python3
"""SERA v207: held BOOST recovery, continuous rear exhaust steering and EN warning."""
from __future__ import annotations

import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
fx = (root / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
shader = (root / "shaders/sera_energy_flash.gdshader").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")

assert 'config/name="SERA v207"' in project
assert "const BOOST_START_RADIUS_RATIO: float = 1.10" in main
assert "const BOOST_EXIT_RADIUS_RATIO: float = 0.90" in main
assert "const BOOST_CONFIRM_SECONDS: float = 0.10" in main
assert "const EN_RECOVERY_UNLOCK_RATIO: float = 0.60" in main
assert "boost_rearm_required" not in main
assert "_update_boost_gesture(BOOST_CONFIRM_SECONDS)" in main
assert "if was_energy_exhausted and not energy_exhausted:" in main
assert "if not gesture_active or guard_active or damage_reaction_active" in main
assert "movement_boost_active = false" in main
assert "boost_has_activated_this_gesture = true" in main

# Both normal exact-zero spend and a too-small BOOST end-of-tick charge flash.
assert main.count("_enter_energy_exhaustion()") >= 3
assert "energy_recovery_pause = 0.25" in main
assert "EN_EMPTY_FLASH_SECONDS: float = 0.60" in main
assert "EN_EMPTY_FLASH_HZ: float = 7.0" in main
assert 'rig.call("set_energy_flash_active", red_phase)' in main
assert 'rig.call("set_energy_flash_active", false)' in main
assert "func set_energy_flash_active(active: bool) -> void:" in rig
assert "elif energy_flash_active:" in rig
assert "overlay = _energy_flash_material" in rig
assert rig.index("if training_ko_active:", rig.index("func _refresh_character_overlay")) < rig.index("elif energy_flash_active:", rig.index("func _refresh_character_overlay"))
assert "ENERGY_FLASH_SHADER" in rig and "res://shaders/sera_energy_flash.gdshader" in rig
assert "shader_type spatial;" in shader
assert "ALPHA = 0.86;" in shader

# The authored nozzle points toward local +Z. Reverse movement (-Z) should
# remain on the rear-center axis, including infinitesimally left/right samples.
assert "nozzle.global_transform.basis.inverse()" in fx
assert "rear_denominator" in fx and "atan2(local_dir.x, rear_denominator)" in fx
assert "clampf(requested_yaw," in fx
assert "-YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS" in fx
assert "-PITCH_LIMIT_RADIANS, PITCH_LIMIT_RADIANS" in fx

max_yaw = math.radians(38.0)
def desired_yaw(x: float, z: float) -> float:
    denom = max(z, 0.0) + 2.0 * max(-z, 0.0) + 0.25
    return max(-max_yaw, min(max_yaw, math.atan2(x, denom)))

assert abs(desired_yaw(0.0, -1.0)) < 1e-8
assert abs(desired_yaw(0.01, -1.0)) < math.radians(1.0)
assert abs(desired_yaw(-0.01, -1.0)) < math.radians(1.0)
assert desired_yaw(1.0, 0.0) == max_yaw
assert desired_yaw(-1.0, 0.0) == -max_yaw
samples = [desired_yaw(x / 1000.0, -1.0) for x in range(-100, 101)]
assert max(abs(b - a) for a, b in zip(samples, samples[1:])) < math.radians(0.1)
print("SERA v207 BOOST, rear exhaust and EN-empty flash static checks passed")

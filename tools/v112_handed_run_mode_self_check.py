#!/usr/bin/env python3
"""v112: preferred-thumb RUN bias, mirror mode, and persistent HUD wiring."""
from pathlib import Path
import math

root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")

for required in (
    "const RUN_MODE_BASE_CENTER_DEGREES: float = 100.0",
    "const RUN_PREFERRED_SIDE_EXTRA_DEGREES: float = 20.0",
    "const RUN_MODE_HYSTERESIS_DEGREES: float = 5.0",
    "var run_left_handed: bool = false",
    "func set_run_left_handed(enabled: bool) -> void:",
    "func _run_forward_sector_center(direction: Vector2) -> float:",
    "func _run_input_angle_degrees(direction: Vector2) -> float:",
    "run_retreat_mode = angle > edge_center",
    "if angle < edge_center - RUN_MODE_HYSTERESIS_DEGREES:",
    "elif angle > edge_center + RUN_MODE_HYSTERESIS_DEGREES:",
    "run_retreat_mode = (_run_input_angle_degrees(run_direction_target)",
):
    assert required in rig, required

for required in (
    'const HANDEDNESS_SETTINGS_FILE: String = "user://sera_settings.cfg"',
    'left_handed = bool(settings.get_value("controls", "left_handed", false))',
    'settings.set_value("controls", "left_handed", left_handed)',
    "settings.save(HANDEDNESS_SETTINGS_FILE)",
    "handedness_button.pressed.connect(_toggle_handedness)",
    'rig.call("set_run_left_handed", left_handed)',
    "handedness_button.mouse_filter = Control.MOUSE_FILTER_STOP",
    "handedness_button.text =",
    "if _pointer_on_step_hud(event.position):",
    'rig.call("set_moving", running, movement_boost_active, local_run_direction)',
):
    assert required in main, required

assert "SERA v112" in project
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const RUN_TURN_MAX_LEAN_DEGREES: float = 15.0" in rig
assert "const RUN_MODE_BLEND_SECONDS: float = 0.18" in rig
assert "const RUN_ROOT_TURN_SPEED_DEGREES: float = 450.0" in rig

def favored_center(left_handed, side):
    return 100 + (20 if (side == "right" if left_handed else side == "left") else 0)

def next_retreat(active_retreat, angle, center):
    if active_retreat:
        return not (angle < center - 5)
    return angle > center + 5

for handed in [False, True]:
    favored = "right" if handed else "left"
    unfavored = "left" if handed else "right"
    assert favored_center(handed, favored) == 120
    assert favored_center(handed, unfavored) == 100
    assert next_retreat(False, 110, 120) is False
    assert next_retreat(False, 124, 120) is False
    assert next_retreat(False, 126, 120) is True
    assert next_retreat(True, 116, 120) is False
    assert next_retreat(True, 118, 120) is True
    assert next_retreat(False, 106, 100) is True
    assert next_retreat(True, 94, 100) is False
    assert next_retreat(True, 96, 100) is True

# New gesture / preset switch uses midpoint without hysteresis.
assert (110 > favored_center(False, "left")) is False
assert (110 > favored_center(True, "left")) is True
assert (110 > favored_center(True, "right")) is False
print("v112 mirrored hand preference, boundary hysteresis, HUD/config wiring: PASS")

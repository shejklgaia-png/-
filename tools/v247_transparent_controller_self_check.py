#!/usr/bin/env python3
"""SERA v247: remove only the former right-bottom controller-zone background."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 247
assert (ROOT / "README_v247_ja.md").exists()

# The former rectangle was rendered by both a four-corner fade polygon and
# a solid lower strip. No idle background shapes are allowed in _draw.
draw = ui.split("func _draw() -> void:", 1)[1].split("func _draw_attack_ripple()", 1)[0]
for obsolete in (
    "CONTROLLER_FRAME_START_RATIO", "OPERATION_ZONE_",
    "fade_vertices", "fade_colors", "frame_left", "solid_top",
    "draw_polygon(", "draw_rect(",
):
    assert obsolete not in draw, obsolete
    assert obsolete not in ui.split("func _draw() -> void:", 1)[0], obsolete

# Active moving stick, lock-on reticle, attack ripple and flick wake remain.
for token in (
    "if target_marker_visible:", "if attack_ripple_active:",
    "_draw_attack_ripple()", "if flick_wake_active:",
    "_draw_flick_wake()", "if dragging:",
    "_draw_analog_controller(accent, low)",
):
    assert token in draw, token

# Never change the touch start area, hit thresholds, gestures, or lock buttons.
for token in (
    "const RUN_CONTROL_RADIUS: float = 70.0",
    "const RUN_INPUT_DEADZONE_PIXELS: float = 11.25",
    "const DRAG_RADIUS: float = 105.0",
    "const BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.90",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "func _controller_start_area_contains(pos: Vector2) -> bool:",
    "_pointer_on_step_hud(event.position)",
    "_pointer_on_lock_mode_button(event.position)",
    "_lock_switch_direction_at(event.position)",
    "func _end_drag(release_pos: Vector2) -> void:",
):
    assert token in main, token
assert "const CONTROLLER_RUN_RADIUS: float = 70.0" in ui
assert "var boost_base_radius: float = 105.0" in ui
print("PASS v247: no idle right-bottom rectangle or gradient; touch and lock controls preserved")

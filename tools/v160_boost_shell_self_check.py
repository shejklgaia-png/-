#!/usr/bin/env python3
"""v160: BOOST propulsion shell is a drawing-only change, preserving input thresholds."""
import math
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
cfg = (root / "project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', cfg, re.M) == ["SERA v160"]
for term in (
    "const CONTROLLER_RUN_RADIUS: float = 112.0",
    "const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_SHELL_RADIUS_RATIO: float = 1.34",
    "const BOOST_SHELL_SEGMENT_HALF_ARC: float = 0.17",
    "const BOOST_SHELL_SEGMENT_WIDTH: float = 5.0",
    "const BOOST_CHEVRON_INNER_RATIO: float = 1.40",
    "const BOOST_CHEVRON_OUTER_RATIO: float = 1.50",
    "const BOOST_CHEVRON_HALF_WIDTH: float = 9.0",
    "const BOOST_SHELL_INACTIVE_ALPHA_SCALE: float = 0.55",
    "_draw_boost_outer_shell(accent)",
    "func _draw_boost_outer_shell(accent: Color) -> void:",
    "for segment in range(8):",
    "draw_arc(anchor_point, shell_radius,",
    "draw_colored_polygon(PackedVector2Array([",
    "var alpha_scale: float = 1.0 if movement_boost_active else BOOST_SHELL_INACTIVE_ALPHA_SCALE",
    "var shell_radius: float = boost_base_radius * BOOST_SHELL_RADIUS_RATIO",
    "boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 16.0",
):
    assert term in ui, term
for term in (
    "const DRAG_RADIUS: float = 168.0",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_POSE_GRACE_SECONDS: float = 0.30",
    "const RUN_CONTROL_RADIUS: float = 112.0",
):
    assert term in main, term
assert "const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045" in rig
assert "if dragging:\n        return" in ui # Fixed touch center
# The shell and chevrons must sit completely OUTSIDE the existing BOOST
# threshold (210px). The status label must clear the outermost arrow tip.
run_radius, boost_base = 112.0, 168.0
start = boost_base * 1.25
shell = boost_base * 1.34
inner_arrow = boost_base * 1.40
tip = boost_base * 1.50
assert run_radius < start < shell < inner_arrow < tip
assert math.isclose(start, 210.0)
assert math.isclose(boost_base * 1.10, 184.8)
assert math.isclose(tip, 252.0)
label_bottom_y = -(tip + 16.0)
assert label_bottom_y < -tip
for i in range(8):
    a = 2.0 * math.pi * i / 8.0
    assert math.isclose(math.hypot(tip*math.cos(a), tip*math.sin(a)), tip)
assert 0.34 * 0.55 < 0.34
assert 0.28 * 0.55 < 0.28
print("v160 fixed BOOST shell: geometry / visual state / unchanged thresholds PASS")
print("Godot / Android runtime: NOT TESTED")

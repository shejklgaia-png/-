#!/usr/bin/env python3
"""v281 regression: shared cubic Bezier for SERA's backward flip flight."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 281
assert "BACK_SOMERSAULT_DISTANCE: float = 5.0" in main
assert "BACK_SOMERSAULT_HEIGHT: float = 1.5" in main
assert "BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80" in main
assert "BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in main
assert "BACK_SOMERSAULT_ARC_CONTROL_HEIGHT_RATIO: float = 4.0 / 3.0" in main
curve = main.split("func _back_somersault_arc_offset(progress: float) -> Vector3:", 1)[1].split(
    "func _advance_back_somersault(", 1)[0]
assert "Vector3.ZERO.bezier_interpolate(" in curve
assert "BACK_SOMERSAULT_LANDING_SLIDE_DISTANCE" in curve
assert "BACK_SOMERSAULT_REAR_FLIGHT_SECONDS" in curve
assert "func _back_somersault_landing_slide_offset(progress: float) -> float:" in curve
assert "control_up, terminal_rear_control + control_up, finish, p" in curve
advance = main.split("func _advance_back_somersault(delta: float) -> void:", 1)[1].split(
    "func _cancel_back_somersault(", 1)[0]
assert "var previous_offset: Vector3 = _back_somersault_arc_offset(previous)" in advance
assert "var next_offset: Vector3 = _back_somersault_arc_offset(progress)" in advance
assert "var arc_delta: Vector3 = next_offset - previous_offset" in advance
assert "_move_player_swept(Vector3(arc_delta.x, 0.0, arc_delta.z), true)" in advance
# Preserve the Bezier up/down while settling any pre-existing float to 0.
assert "lerpf(back_somersault_start.y, 0.0," in advance
assert "progress) + next_offset.y" in advance
assert "BACK_SOMERSAULT_HEIGHT * sin(PI * progress)" not in advance
assert 'rig.call("set_back_somersault_progress", pose_progress)' in advance
assert "rig.rotation.x = angle" in advance
assert "if back_somersault_has_authored_clip and not bool(" in advance
assert "_register_side_kick_hit()" in advance
assert "_begin_landing(true)" in advance
print("V281_SOMERSAULT_BEZIER_STATIC_PASS")

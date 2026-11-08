#!/usr/bin/env python3
"""SERA v133: source-only immediate target-outline toggles."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
script = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
outline = (root/"scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
assert 'config/name="SERA v143 - Straight transfer and instant glow off"' in project
def section(a, b):
    return script.split("func "+a, 1)[1].split("func "+b, 1)[0]
choose = section("_select_target(target_name: String) -> void:", "_focus_arrived(")
back = section("_return_to_overview() -> void:", "_overview_arrived(")
arrived = section("_overview_arrived() -> void:", "_move_camera(")
tap = section("_tap_at(point: Vector2) -> void:", "_polygon_bounds(")
user_input = section("_input(event: InputEvent) -> void:", "_tap_at(")
assert choose.index('outline.set("active_target", target_name)') < choose.index("in_transition = true")
assert choose.index("_update_projected_silhouettes()") < choose.index("_move_camera(")
assert choose.index("outline.queue_redraw()") < choose.index("_move_camera(")
assert back.index('outline.set("active_target", "")') < back.index("_move_camera(")
assert back.index("outline.queue_redraw()") < back.index("_move_camera(")
assert 'outline.set("active_target", "")' not in arrived
assert 'focused_target = ""' in arrived and "_update_projected_silhouettes()" in arrived
assert "_return_to_overview()" in tap and "_select_target(candidate)" in tap
assert "InputEventScreenTouch" in user_input and "InputEventMouseButton" in user_input
assert "_return_to_overview()" in user_input
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in script
assert "focus_tween.set_trans(Tween.TRANS_CUBIC)" in script
assert 'for candidate in ["TRAINING", "SYSTEM", "CUSTOMIZE", "DATA ARCHIVE", "DEPLOYMENT"]:' in script
assert 'var selected: bool = name == active_target' in outline
assert '0.98 if selected' in outline
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in script
assert "CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO" in script
print("v133 target press/back outline timing: STATIC PASS")
print("Godot and Android runtime: NOT TESTED")

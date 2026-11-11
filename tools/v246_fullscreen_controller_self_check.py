#!/usr/bin/env python3
"""SERA v246: borderless fullscreen floating controller, except actual UI buttons."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
match = re.search(r'config/name="SERA v(\d+)"', project)
assert match and int(match.group(1)) >= 246
assert (ROOT / "README_v246_ja.md").is_file()

start = main.split("func _controller_start_area_contains(pos: Vector2) -> bool:", 1)[1].split(
    "func _pointer_on_lock_mode_button(", 1)[0]
for token in ("pos.x >= 0.0", "pos.x <= screen.x",
              "pos.y >= 0.0", "pos.y <= screen.y"):
    assert token in start, token
assert "CONTROLLER_REGION_START_RATIO" not in start

buttons = main.split("func _pointer_on_step_hud(pos: Vector2) -> bool:", 1)[1].split(
    "# The body remains", 1)[0]
assert "handedness_button.get_global_rect().has_point(pos)" in buttons
assert 'enemy_debug_ui.find_children("*", "Button", true, false)' in buttons
assert "gui_button.get_global_rect().has_point(pos)" in buttons
assert "hud_panel.get_global_rect().has_point(pos)" not in buttons

touch = main.split("func _input(event: InputEvent) -> void:", 1)[1].split(
    "func _guard_can_start()", 1)[0]
for token in (
    "_pointer_on_lock_mode_button(event.position)",
    "_lock_switch_direction_at(event.position)",
    "_pointer_on_training_test_button(event.position)",
    "_pointer_on_nexus_button(event.position)",
    "_pointer_on_step_hud(event.position)",
    "current_touch < 0 and _controller_start_area_contains(event.position)",
    "if not _controller_start_area_contains(event.position):",
    "_begin_drag(event.position)",
    "_change_drag(event.position)",
    "_end_drag(event.position)",
):
    assert token in touch, token
assert touch.count("_controller_start_area_contains(event.position)") == 2
assert touch.count("_pointer_on_step_hud(event.position)") == 2
assert touch.index("_pointer_on_step_hud(event.position)") < touch.index(
    "current_touch < 0 and _controller_start_area_contains(event.position)")

# v247 removes the remaining gradient/fill as well as border/corner strokes.
draw = ui.split("func _draw() -> void:", 1)[1].split("func _draw_attack_ripple()", 1)[0]
assert "_draw_analog_controller(accent, low)" in draw
for removed in (
    "draw_polygon(fade_vertices", "OPERATION_ZONE_",
    "var frame_left", "draw_rect(Rect2(frame_left",
    "draw_rect(frame_rect", "corner_tint", "var frame_rect",
    "draw_line(Vector2(frame_left + 12.0",
):
    assert removed not in draw, removed

for token in (
    "const RUN_CONTROL_RADIUS: float = 105.0",
    "const RUN_INPUT_DEADZONE_PIXELS: float = 16.875",
    "const DRAG_RADIUS: float = 157.5",
    "const BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.90",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "func _update_guard_hold() -> void:",
    "func _end_drag(release_pos: Vector2) -> void:",
):
    assert token in main, token
assert "const CONTROLLER_RUN_RADIUS: float = 105.0" in ui
assert "var boost_base_radius: float = 157.5" in ui

# Mathematical layout model: full viewport except the 3 unchanged
# lock-button footprints and other actual UI buttons.
w, h = 720.0, 1280.0
left = (w*.5+8, h*.5+8, w*.5+112, h*.5+66)
middle = (w*.75-64, h*.5+8, w*.75+64, h*.5+66)
right = (w-112, h*.5+8, w-8, h*.5+66)
def usable(x, y):
    return 0 <= x <= w and 0 <= y <= h and not any(
        x0 <= x <= x1 and y0 <= y <= y1
        for x0,y0,x1,y1 in (left,middle,right))
for point in ((10,10), (100,500), (100,1100), (640,1100), (620,400)):
    assert usable(*point)
for point in ((-1,500), (721,500), (400,670), (540,670), (650,670)):
    assert not usable(*point)

print("PASS v246: fullscreen joystick start and individual UI button exclusions")
print("PASS v246-v248: frame/fill/gradient removed; current input/display sizes coherent")
print("Godot parser, Android device and actual multitouch are NOT verified")

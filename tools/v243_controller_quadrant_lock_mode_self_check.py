#!/usr/bin/env python3
"""v243 AUTO/MANUAL button and fullscreen gesture ownership, updated through v293."""
from pathlib import Path

# v317: lock projections reside in the canonical delegated module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
parts = (ROOT / "scripts/target_parts.gd").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"',
                    (ROOT / "project.godot").read_text(encoding="utf-8"))
assert version and int(version.group(1)) >= 243
assert (ROOT / "docs/history/release_notes/README_v243_ja.md").exists()

for token in (
    "const CONTROLLER_REGION_START_RATIO: float = 0.50",
    "const LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76",
    "const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)",
    "const LOCK_MODE_BUTTON_SIZE: Vector2 = Vector2(128.0, 58.0)",
    "const CONTROLLER_BUTTON_TOP_INSET: float = 8.0",
    "const LOCK_SWITCH_EDGE_INSET: float = 8.0",
    "var auto_lock_enabled: bool = true",
    "var manual_part_lock_active: bool = false",
    "func _controller_start_area_contains(pos: Vector2) -> bool:",
    "INPUT_GESTURES.controller_contains(",
    "button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    "var base: float = 0.5 if left_handed else 0.0",
    "button.anchor_left = base",
    "button.anchor_right = base",
    "lock_mode_button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    'lock_mode_button.text = ""',
    "lock_switch_left_button.disabled = auto_lock_enabled",
    "lock_switch_right_button.disabled = auto_lock_enabled",
    "_build_lock_switch_buttons(layer)",
    "auto_lock_enabled = not auto_lock_enabled",
    "manual_part_lock_active = not auto_lock_enabled",
    "lock_mode_button.get_global_rect().has_point(pos)",
):
    assert token in main, token
assert "layer.add_child(touch_ui)" in main
assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in main
for token in ("if dragging:", "_draw_analog_controller(accent, low)"):
    assert token in ui, token
for obsolete in ("CONTROLLER_FRAME_START_RATIO", "OPERATION_ZONE_",
                 "draw_rect(frame_rect.grow(-2.0)", "corner_tint"):
    assert obsolete not in ui, obsolete

input_fn = main.split("func _input(event: InputEvent) -> void:", 1)[1].split(
    "func _guard_can_start()", 1)[0]
for token in (
    "current_touch < 0 and _controller_start_area_contains(event.position)",
    "if not _controller_start_area_contains(event.position):",
    "if event.index == step_hud_touch:",
    "if event.index == current_touch:",
    "elif step_hud_mouse_press:",
    "elif mouse_down:",
    "_change_drag(event.position)", "_end_drag(event.position)"
):
    assert token in input_fn, token
assert input_fn.count("if _pointer_on_lock_mode_button(event.position):") == 2
assert input_fn.count("_toggle_auto_lock_mode()") == 0
assert 'auto_lock_enabled = bool(settings.get_value(' in main
assert input_fn.count("_switch_lock_screen_direction(switch_direction)") == 2
assert input_fn.index("_pointer_on_lock_mode_button(event.position)") < input_fn.index(
    "_lock_switch_direction_at(event.position)")
assert input_fn.index("_lock_switch_direction_at(event.position)") < input_fn.index(
    "_pointer_on_training_test_button(event.position)")
manual = main.split("func _switch_lock_screen_direction(direction: int) -> void:", 1)[1].split(
    "func _update_target_marker_projection()", 1)[0]
assert "direction == 0 or auto_lock_enabled or target_parts == null" in manual
assert "or _combo_lock_retention_active()" in manual
assert "LOCK_MANAGEMENT.manual_screen_neighbor(" in manual
assert "forward_id if not forward_id.is_empty() else wrapped_id" in LOCK_MODULE
assert 'parts.call("get_visible_part_ids",' in LOCK_MODULE
assert "locked_target_part_id = next_id" in manual
assert "manual_part_lock_active = true" in manual
assert "func get_visible_part_ids(" in parts

# Both handed layouts keep the 3 glyphs in one screen half.
width=720.
height=1280.
y=height*0.76+8
for left_handed in (False, True):
    base=width*0.5 if left_handed else 0.0
    x=base+8
    boxes=[(x,y,x+104,y+58),(x+112,y,x+240,y+58),
           (x+248,y,x+352,y+58)]
    assert all(0 <= a < c <= width for a,b,c,d in boxes)
    assert boxes[0][2] < boxes[1][0] and boxes[1][2] < boxes[2][0]
    assert all((a>=width*.5 if left_handed else c<=width*.5)
               for a,b,c,d in boxes)
print("V243_HANDED_GLYPH_LOCK_AND_FULLSCREEN_STATIC_PASS")

for _bound in ("pos.x >= 0.0", "pos.y >= 0.0", "pos.x <= screen.x", "pos.y <= screen.y"):
    assert _bound in SERA_INPUT, _bound

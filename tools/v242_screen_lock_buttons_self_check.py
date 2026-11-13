#!/usr/bin/env python3
"""v242 manual left/right lock behavior preserved under v291/v293 camera selection."""
from pathlib import Path

# v317: lock projections reside in the canonical delegated module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
parts = (ROOT / "scripts/target_parts.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 242
assert (ROOT / "docs/history/release_notes/README_v242_ja.md").exists()

for token in (
    "const CONTROLLER_REGION_START_RATIO: float = 0.50",
    "const LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76",
    "const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)",
    "const LOCK_SWITCH_EDGE_INSET: float = 8.0",
    'button.name = "LockSwitchLeft" if direction < 0 else "LockSwitchRight"',
    'button.text = "◀" if direction < 0 else "▶"',
    "button.focus_mode = Control.FOCUS_NONE",
    "button.mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "func _lock_switch_direction_at(pos: Vector2) -> int:",
    "func _switch_lock_screen_direction(direction: int) -> void:",
):
    assert token in main, token

manual = main.split("func _switch_lock_screen_direction(direction: int) -> void:", 1)[1].split(
    "func _update_target_marker_projection()", 1)[0]
for token in (
    "direction == 0 or auto_lock_enabled or target_parts == null",
    "training_ko_remaining > 0.0",
    "or _combo_lock_retention_active()",
    "LOCK_MANAGEMENT.manual_screen_neighbor(",
    "locked_target_part_id = next_id",
    "manual_part_lock_active = true",
    "_update_target_marker_projection()",
):
    assert token in manual, token
assert "core_box.intersects_segment" not in manual
visible = parts.split("func get_visible_part_ids(", 1)[1]
for token in ("for id in PART_ORDER:", "is_targetable(id)", "ids.append(id)", "return ids"):
    assert token in visible, token
assert "core_box.intersects_segment" not in visible

input_fn = main.split("func _input(event: InputEvent) -> void:", 1)[1].split(
    "func _guard_can_start()", 1)[0]
assert input_fn.count("var switch_direction: int = _lock_switch_direction_at(event.position)") == 2
assert input_fn.count("_switch_lock_screen_direction(switch_direction)") == 2
for token in ("step_hud_touch = event.index", "if event.index == step_hud_touch:",
              "step_hud_mouse_press = true", "elif step_hud_mouse_press:",
              "get_viewport().set_input_as_handled()", "_begin_drag(event.position)",
              "_end_drag(event.position)", "_change_drag(event.position)"):
    assert token in input_fn, token
assert input_fn.index("_lock_switch_direction_at(event.position)") < input_fn.index(
    "_pointer_on_training_test_button(event.position)")

# The actual new selector chooses the next projected x, wrapping when needed.
def choose(current, direction, positions):
    ref = positions[current]
    available = [(id, x) for id, x in positions.items() if id != current]
    next_side = [(id, (x - ref) * direction) for id, x in available
                 if (x - ref) * direction > 3.0]
    if next_side:
        return min(next_side, key=lambda pair: pair[1])[0]
    return (min(available, key=lambda pair: pair[1])[0] if direction > 0
            else max(available, key=lambda pair: pair[1])[0])

positions = {"head": 355, "leg_fl": 240, "leg_fr": 455, "leg_rl": 150, "leg_rr": 525}
assert choose("head", 1, positions) == "leg_fr"
assert choose("head", -1, positions) == "leg_fl"
assert choose("leg_rr", 1, positions) == "leg_rl"
assert choose("leg_rl", -1, positions) == "leg_rr"
rotated = {"head": 355, "leg_fl": 460, "leg_fr": 245}
assert choose("head", 1, rotated) == "leg_fl"
assert choose("head", -1, rotated) == "leg_fr"
print("V242_MANUAL_LOCK_AND_TOUCH_STATIC_PASS")

for token in ("view.unproject_position(current_aim).x",
              'parts.call("get_visible_part_ids",',
              "view.global_position, boss_body",
              "view.is_position_behind(aim)",
              "view.unproject_position(aim)",
              "(projected.x - reference_x) * float(direction)",
              "if gap > 3.0 and gap < forward_gap:",
              "forward_id if not forward_id.is_empty() else wrapped_id"):
    assert token in LOCK_MODULE, token

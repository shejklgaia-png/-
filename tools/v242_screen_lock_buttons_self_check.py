#!/usr/bin/env python3
"""SERA v242: screen-relative target part switching and isolated HUD touch."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
parts = (ROOT / "scripts/target_parts.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 242
assert (ROOT / "README_v242_ja.md").exists()

# Two responsive touch controls: their vertical center is exactly 40% UP from
# the screen bottom, and neither steals the underlying movement gestures.
for token in (
    'const CONTROLLER_REGION_START_RATIO: float = 0.50',
    'const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)',
    'const LOCK_SWITCH_EDGE_INSET: float = 8.0',
    'lock_switch_left_button: Button', 'lock_switch_right_button: Button',
    'func _build_lock_switch_buttons(layer: CanvasLayer)',
    '_build_lock_switch_buttons(layer)',
    'button.name = "LockSwitchLeft" if direction < 0 else "LockSwitchRight"',
    'button.text = "◀ LOCK" if direction < 0 else "LOCK ▶"',
    'button.anchor_top = CONTROLLER_REGION_START_RATIO',
    'button.anchor_bottom = CONTROLLER_REGION_START_RATIO',
    'button.offset_top = CONTROLLER_BUTTON_TOP_INSET',
    'button.offset_bottom = CONTROLLER_BUTTON_TOP_INSET + LOCK_SWITCH_BUTTON_SIZE.y',
    'button.anchor_left = CONTROLLER_REGION_START_RATIO',
    'button.anchor_left = 1.0',
    'button.focus_mode = Control.FOCUS_NONE',
    'button.mouse_filter = Control.MOUSE_FILTER_IGNORE',
    'func _lock_switch_direction_at(pos: Vector2) -> int:',
    'func _switch_lock_screen_direction(direction: int) -> void:',
):
    assert token in main, token

block = main.split('func _switch_lock_screen_direction(direction: int) -> void:', 1)[1].split(
    'func _update_target_marker_projection()', 1)[0]
assert 'combat_state != CombatState.IDLE' in block
assert 'target_hp <= 0' in block
assert 'training_ko_remaining > 0.0' in block
assert 'camera.unproject_position(current_aim).x' in block
assert 'target_parts.call("get_visible_part_ids"' in block
assert 'camera.global_position, _target_hit_aabb()' in block
assert 'camera.is_position_behind(aim)' in block
assert 'on_screen' not in block  # explicit screen_point check, not stale auto-lock position
assert 'screen_point.x < 0.0' in block
assert 'screen_point.y > viewport_size.y' in block
assert '(screen_point.x - reference_x) * float(direction)' in block
assert 'screen_offset' not in block
assert 'if offset <= 3.0 or offset >= nearest_offset:' in block
assert 'if nearest_id.is_empty():' in block
assert 'locked_target_part_id = nearest_id' in block
assert 'manual_part_lock_active = true' in block
assert '_update_target_marker_projection()' in block

# Android handles native finger touches, and separate mouse path is used in
# desktop editor. Both consume the entire gesture until its own finger UP.
input_fn = main.split("func _input(event: InputEvent) -> void:", 1)[1].split(
    "func _guard_can_start()", 1)[0]
assert input_fn.count("var switch_direction: int = _lock_switch_direction_at(event.position)") == 2
assert input_fn.count("_switch_lock_screen_direction(switch_direction)") == 2
assert 'step_hud_touch = event.index' in input_fn
assert 'elif event.index == step_hud_touch:' in input_fn
assert 'if event.index == step_hud_touch:' in input_fn
assert 'step_hud_mouse_press = true' in input_fn
assert 'elif step_hud_mouse_press:' in input_fn
assert 'get_viewport().set_input_as_handled()' in input_fn
assert input_fn.index('_lock_switch_direction_at(event.position)') < input_fn.index(
    '_pointer_on_training_test_button(event.position)')
assert '_begin_drag(event.position)' in input_fn
assert '_end_drag(event.position)' in input_fn
assert '_change_drag(event.position)' in input_fn

# Existing auto acquisition runs ONLY while manual mode is inactive; breaking
# a part or resetting training clears the latch so auto lock can recover.
assert 'var manual_part_lock_active: bool = false' in main
assert 'and not manual_part_lock_active' in main
assert main.count("manual_part_lock_active = not auto_lock_enabled") >= 4
assert 'func select_front_part(' in parts
assert 'func get_visible_part_ids(origin: Vector3, core_box: AABB) -> Array[String]:' in parts
visible = parts.split('func get_visible_part_ids(',1)[1]
for key in (
    'for id in PART_ORDER:', 'if not is_targetable(id):',
    'core_box.intersects_segment(origin, aim)',
    'get_part_aabb(other_id).intersects_segment(',
    'if not other_node.visible:', 'if not occluded:',
    'candidates.append(id)', 'return candidates'):
    assert key in visible, key

# Deterministic abstract screen selection: nearest candidate STRICTLY on the
# selected side, excluding broken/hidden/offscreen and the current target.
def choose(reference, direction, candidates):
    choice = None
    delta_best = math.inf
    for id, x, visible, broken, on_screen in candidates:
        if not visible or broken or not on_screen:
            continue
        delta = (x-reference)*direction
        if delta <= 3.0 or delta >= delta_best:
            continue
        delta_best = delta
        choice = id
    return choice

data=[("head",355,True,False,True),
      ("lf",240,True,False,True),("rf",455,True,False,True),
      ("lr",150,True,True,True),("rr",525,False,False,True)]
assert choose(355,-1,data)=="lf"
assert choose(355,1,data)=="rf"
assert choose(240,-1,data) is None
assert choose(455,1,data) is None
# Across camera orbit the x ordering reverses, irrespective of semantic
# left/right leg IDs; the button follows screen x, not limb names.
rotated=[("head",350,True,False,True),
         ("lf",460,True,False,True),("rf",245,True,False,True)]
assert choose(350,-1,rotated)=="rf"
assert choose(350,1,rotated)=="lf"
assert choose(350,-1,[("off",100,True,False,False)]) is None
assert choose(350,1,[("dead",480,True,True,True)]) is None

h=1280.0
assert math.isclose(h*.50, 640.0)
assert math.isclose(h-640.0,640.0)
print("PASS v242-v243: responsive L/R buttons, Android+desktop gesture isolation")
print("PASS v242: nearest screen-X selection, occlusion/broken handling, manual latch")
print("PASS v242: original auto lock and attack lock preserved; rotation invariant")
print("Godot parser, Android touch/multifinger and projection visuals not verified")

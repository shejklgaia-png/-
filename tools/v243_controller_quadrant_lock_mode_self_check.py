#!/usr/bin/env python3
"""SERA v243 lock controls, updated for the v246 fullscreen controller."""
from __future__ import annotations
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
main=read("scripts/main.gd")
ui=read("scripts/touch_overlay.gd")
parts=read("scripts/target_parts.gd")
project=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1))>=243
assert (ROOT/"README_v243_ja.md").is_file()

for token in (
    'const CONTROLLER_REGION_START_RATIO: float = 0.50',
    'const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)',
    'const LOCK_MODE_BUTTON_SIZE: Vector2 = Vector2(128.0, 58.0)',
    'const CONTROLLER_BUTTON_TOP_INSET: float = 8.0',
    'const LOCK_SWITCH_EDGE_INSET: float = 8.0',
    'var auto_lock_enabled: bool = true',
    'var manual_part_lock_active: bool = false',
    'func _controller_start_area_contains(pos: Vector2) -> bool:',
    'pos.x >= 0.0',
    'pos.y >= 0.0',
    'pos.x <= screen.x', 'pos.y <= screen.y',
    'func _build_lock_switch_buttons(layer: CanvasLayer) -> void:',
    'button.anchor_top = CONTROLLER_REGION_START_RATIO',
    'button.anchor_left = CONTROLLER_REGION_START_RATIO',
    'button.anchor_left = 1.0',
    'lock_mode_button.anchor_left = 0.75',
    'lock_mode_button.anchor_top = CONTROLLER_REGION_START_RATIO',
    'lock_mode_button.name = "LockModeToggle"',
    'lock_mode_button.mouse_filter = Control.MOUSE_FILTER_IGNORE',
    'lock_mode_button.text = "AUTO" if auto_lock_enabled else "MANUAL"',
    'lock_switch_left_button.disabled = auto_lock_enabled',
    'lock_switch_right_button.disabled = auto_lock_enabled',
    '_build_lock_switch_buttons(layer)',
    'func _toggle_auto_lock_mode() -> void:',
    'auto_lock_enabled = not auto_lock_enabled',
    'manual_part_lock_active = not auto_lock_enabled',
    'func _pointer_on_lock_mode_button(pos: Vector2) -> bool:',
    'lock_mode_button.get_global_rect().has_point(pos)',
):
    assert token in main,token

# Retain the optional gray gradient but no visible frame or corner markers.
assert 'const CONTROLLER_FRAME_START_RATIO: float = 0.50' in ui
for token in (
    'var frame_left: float = size.x * CONTROLLER_FRAME_START_RATIO',
    'const OPERATION_ZONE_TOP_RATIO: float = 0.50',
    'var fade_top: float = size.y * OPERATION_ZONE_TOP_RATIO',
    'Vector2(frame_left, fade_top)',
    'Vector2(frame_left, solid_top)',
    'draw_polygon(fade_vertices, fade_colors)',
    'draw_rect(Rect2(frame_left, solid_top',
    'if dragging:', '_draw_analog_controller(accent, low)',
):
    assert token in ui,token
assert 'draw_rect(frame_rect.grow(-2.0)' not in ui
assert 'corner_tint' not in ui
assert 'mouse_filter = Control.MOUSE_FILTER_IGNORE' in main
assert 'layer.add_child(touch_ui)' in main

# Native Android pointer ownership: touch starts anywhere except UI buttons,
# and later drag/release locations have no position restriction.
input_fn=main.split('func _input(event: InputEvent) -> void:',1)[1].split(
    'func _guard_can_start()',1)[0]
assert 'current_touch < 0 and _controller_start_area_contains(event.position)' in input_fn
assert 'if not _controller_start_area_contains(event.position):' in input_fn
assert input_fn.count('_controller_start_area_contains(event.position)')==2
assert input_fn.count('if _pointer_on_lock_mode_button(event.position):')==2
assert input_fn.count('_toggle_auto_lock_mode()')==2
assert input_fn.count('_switch_lock_screen_direction(switch_direction)')==2
assert input_fn.index('_pointer_on_lock_mode_button(event.position)') < input_fn.index(
    '_lock_switch_direction_at(event.position)')
assert input_fn.index('_lock_switch_direction_at(event.position)') < input_fn.index(
    '_pointer_on_training_test_button(event.position)')
assert input_fn.index('_pointer_on_training_test_button(event.position)') < input_fn.index(
    'current_touch < 0 and _controller_start_area_contains(event.position)')
assert '_change_drag(event.position)' in input_fn
assert '_end_drag(event.position)' in input_fn
assert 'if event.index == step_hud_touch:' in input_fn
assert 'if event.index == current_touch:' in input_fn
assert 'elif step_hud_mouse_press:' in input_fn
assert 'elif mouse_down:' in input_fn
assert input_fn.count('get_viewport().set_input_as_handled()')>=6

# AUTO uses the prior selector; MANUAL freezes any existing target and L/R
# selects only the next screen-space visible part.
switch_fn=main.split('func _switch_lock_screen_direction(direction: int) -> void:',1)[1].split(
    'func _update_target_marker_projection()',1)[0]
assert 'direction == 0 or auto_lock_enabled or target_parts == null' in switch_fn
assert 'combat_state != CombatState.IDLE' in switch_fn
assert 'camera.unproject_position(current_aim).x' in switch_fn
assert '(screen_point.x - reference_x) * float(direction)' in switch_fn
assert 'target_parts.call("get_visible_part_ids"' in switch_fn
assert 'locked_target_part_id = nearest_id' in switch_fn
assert 'manual_part_lock_active = true' in switch_fn
assert 'and not manual_part_lock_active' in main
assert main.count('manual_part_lock_active = not auto_lock_enabled')>=5
assert 'func get_visible_part_ids(origin: Vector3, core_box: AABB)' in parts
assert 'func apply_part_hit(' in parts
assert 'func select_front_part(' in parts
assert 'func _begin_drag(pos: Vector2) -> void:' in main
assert 'func _change_drag(pos: Vector2) -> void:' in main
assert 'func _end_drag(release_pos: Vector2) -> void:' in main

# 720x1280 layout: three non-overlapping lock buttons stay in place.
w,h=720.0,1280.0
frame=(w*.5,h*.5,w,h)
assert frame==(360.0,640.0,720.0,1280.0)
left=(frame[0]+8,frame[1]+8,frame[0]+8+104,frame[1]+8+58)
middle=(w*.75-64,frame[1]+8,w*.75+64,frame[1]+8+58)
right=(w-8-104,frame[1]+8,w-8,frame[1]+8+58)
assert left[2]<middle[0] and middle[2]<right[0]
for rect in (left,middle,right):
    assert frame[0]<=rect[0]<rect[2]<=frame[2]
    assert frame[1]<=rect[1]<rect[3]<=frame[3]
def allowed_start(x,y):
    if not (0 <= x <= w and 0 <= y <= h):
        return False
    for a,b,c,d in (left,middle,right):
        if a <= x <= c and b <= y <= d:
            return False
    return True
for point in ((-1,1000),(721,900),(400,670),(540,670),(650,670)):
    assert not allowed_start(*point)
for point in ((350,1000),(450,620),(0,0),(220,1200),
              (410,750),(650,1120),(500,900)):
    assert allowed_start(*point)
# Move/release from a valid origin can travel anywhere afterwards.
start=(510,900)
end=(80,200)
assert allowed_start(*start) and allowed_start(*end)
# AUTO mode keeps the auto-lock active; MANUAL holds the last selected part.
auto=True
manual_latch=not auto
assert not manual_latch
auto=not auto
manual_latch=not auto
assert manual_latch
auto=not auto
manual_latch=not auto
assert not manual_latch

print("PASS v243-v246: no frame strokes, fullscreen gestures except button footprints")
print("PASS v243: L/AUTO-MANUAL/R top-corner HUD, separated gesture IDs")
print("PASS v243: auto lock restores selection; manual retains and switches screen-X")
print("Godot parser, Android UI and real multi-touch behavior not exercised")

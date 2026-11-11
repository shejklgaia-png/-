#!/usr/bin/env python3
"""SERA v248: the entire floating controller geometry and hit distances are 1.5x v247."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 248
assert (ROOT / "README_v248_ja.md").exists()

def number(src,kind,name):
    m = re.search(rf'^{kind} {name}: float = ([0-9.]+)',src,re.M)
    assert m, (kind,name)
    return float(m.group(1))

for src,kind,name,old in (
    (main,"const","RUN_CONTROL_RADIUS",70.0),
    (main,"const","RUN_INPUT_DEADZONE_PIXELS",11.25),
    (main,"const","DRAG_RADIUS",105.0),
    (ui,"const","CONTROLLER_RUN_RADIUS",70.0),
    (ui,"var","radius",70.0),
    (ui,"var","boost_base_radius",105.0),
    (ui,"const","BOOST_SHELL_SEGMENT_WIDTH",3.125),
    (ui,"const","BOOST_CHEVRON_HALF_WIDTH",5.625),
):
    assert math.isclose(number(src,kind,name),old*1.5), name

assert math.isclose(number(main,"const","BOOST_START_RADIUS_RATIO"),1.10)
assert math.isclose(number(main,"const","BOOST_EXIT_RADIUS_RATIO"),.90)
assert math.isclose(number(main,"const","BOOST_CONFIRM_SECONDS"),.10)
assert math.isclose(number(ui,"const","CONTROLLER_BOOST_START_RADIUS_RATIO"),1.10)
assert math.isclose(number(main,"const","DRAG_RADIUS")*1.10,173.25)
assert math.isclose(number(main,"const","DRAG_RADIUS")*.90,141.75)

# No display-only radius or hidden input mismatch: both the ring and
# analog movement/BOOST hysteresis must use these upscaled values.
for token in (
    'radius = CONTROLLER_RUN_RADIUS',
    'boost_base_radius = max_radius',
    'draw_arc(anchor_point, boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO,',
    'draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 2.8125, true)',
    '0.0, TAU, 96, boost_guide, 1.875, true)',
    '0.0, TAU, 48, low, 1.875, true)',
    'angle - 0.26, angle + 0.26, 20, indicator_color, 6.5625, true)',
    'tip, base + sideways * 8.4375, base - sideways * 8.4375',
    'var shell_radius: float = boost_base_radius * BOOST_SHELL_RADIUS_RATIO',
    'var label_width: float = 155.625',
    'var label_height: float = 31.875',
    'boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 15.0',
    'draw_rect(rect, rim_color, false, 1.875, true)',
    'Vector2(rect.position.x, rect.position.y + 22.5)',
    'mode_label, HORIZONTAL_ALIGNMENT_CENTER, label_width, 17, accent)',
):
    assert token in ui,token
for token in (
    'if distance <= RUN_INPUT_DEADZONE_PIXELS:',
    '(RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)',
    'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
    'if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:',
    'elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:',
    'boost_confirm_elapsed >= BOOST_CONFIRM_SECONDS',
    'func _controller_start_area_contains(pos: Vector2) -> bool:',
    'func _end_drag(release_pos: Vector2) -> void:',
):
    assert token in main,token

# A finger at a proportional distance produces identical analog output.
def strength(d,full,dead):
    return min(1.0,max(0.0,(d-dead)/(full-dead)))
for i in range(251):
    distance = i*1.0
    assert math.isclose(strength(distance,70.0,11.25),
                        strength(distance*1.5,105.0,16.875),abs_tol=1e-10)
    assert (distance >= 105.0*1.1) == (distance*1.5 >= 157.5*1.1)
    assert (distance < 105.0*.9) == (distance*1.5 < 157.5*.9)

# UI buttons, lock-on reticle and separate flick/guard actions stay intact.
for token in (
    'const STEP_FLICK_MIN_HORIZONTAL: float = 78.0',
    'const STEP_FLICK_MIN_VERTICAL: float = 78.0',
    'const STEP_FLICK_MIN_PIXELS_PER_SEC: float = 500.0',
    '_pointer_on_step_hud(event.position)',
    '_pointer_on_lock_mode_button(event.position)',
    '_lock_switch_direction_at(event.position)',
    'func _update_guard_hold() -> void:',
    'const BOOST_SPEED_BLEND_SECONDS: float = 0.20',
):
    assert token in main,token

# v247 transparent idle background must not regress.
static_draw = ui.split("func _draw() -> void:",1)[1].split("func _draw_attack_ripple()",1)[0]
assert 'draw_polygon(' not in static_draw
assert 'draw_rect(' not in static_draw
assert '_draw_analog_controller(accent, low)' in static_draw

print("PASS v248: 1.5x RUN/BOOST display, thresholds, shell, arrows and text")
print("PASS v248: proportional input response; no fullscreen / flick / guard regression")
print("Android Godot runtime / tactile feel remain unverified")

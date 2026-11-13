#!/usr/bin/env python3
"""SERA v245 baseline (125% of v244), plus v248 150% enlargement."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import math
import re

ROOT=Path(__file__).resolve().parents[1]
main=(ROOT/"scripts/main.gd").read_text(encoding="utf-8")
boost_policy=(ROOT/"scripts/sera_boost_state.gd").read_text(encoding="utf-8")
ui=(ROOT/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
project=(ROOT/"project.godot").read_text(encoding="utf-8")

def const(source,name):
    hit=re.search(r"^const "+name+r": float = ([0-9.]+)",source,re.M)
    assert hit is not None,name
    return float(hit.group(1))
def v(source,name):
    hit=re.search(r"^var "+name+r": float = ([0-9.]+)",source,re.M)
    assert hit is not None,name
    return float(hit.group(1))

version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1))>=245
assert (ROOT/"docs/history/release_notes/README_v245_ja.md").is_file()

# Prior exact radii: v244 RUN=56, deadzone=9, BOOST=84.
scale=1.25*1.5
for old,actual in (
    (56.,const(main,"RUN_CONTROL_RADIUS")),
    (9.,const(main,"RUN_INPUT_DEADZONE_PIXELS")),
    (84.,const(main,"DRAG_RADIUS")),
    (56.,const(ui,"CONTROLLER_RUN_RADIUS")),
    (56.,v(ui,"radius")),
    (84.,v(ui,"boost_base_radius")),
    (2.5,const(ui,"BOOST_SHELL_SEGMENT_WIDTH")),
    (4.5,const(ui,"BOOST_CHEVRON_HALF_WIDTH")),
):
    assert math.isclose(actual,old*scale,abs_tol=1e-9),(old,actual)
assert math.isclose(const(main,"RUN_CONTROL_RADIUS"),105.)
assert math.isclose(const(main,"RUN_INPUT_DEADZONE_PIXELS"),16.875)
assert math.isclose(const(main,"DRAG_RADIUS"),157.5)
assert math.isclose(v(ui,"boost_base_radius"),const(main,"DRAG_RADIUS"))
assert math.isclose(const(ui,"CONTROLLER_RUN_RADIUS"),const(main,"RUN_CONTROL_RADIUS"))
assert math.isclose(const(main,"BOOST_START_RADIUS_RATIO"),1.10)
assert math.isclose(const(main,"BOOST_EXIT_RADIUS_RATIO"),.90)
assert math.isclose(const(ui,"CONTROLLER_BOOST_START_RADIUS_RATIO"),
                    const(main,"BOOST_START_RADIUS_RATIO"))
assert math.isclose(const(main,"DRAG_RADIUS")*1.10,173.25)
assert math.isclose(const(main,"DRAG_RADIUS")*.90,141.75)
for token in (
    'INPUT_GESTURES.analog_stick_direction(',
    'RUN_INPUT_DEADZONE_PIXELS, RUN_CONTROL_RADIUS)',
    'BOOST_STATE.next_gesture_state(', 
    'DRAG_RADIUS, BOOST_START_RADIUS_RATIO, BOOST_EXIT_RADIUS_RATIO,', 
    'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
    'if current_touch < 0 and _controller_start_area_contains(event.position):',
    'if not _controller_start_area_contains(event.position):',
    'const CONTROLLER_REGION_START_RATIO: float = 0.50',
    'const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)',
    'var auto_lock_enabled: bool = true',
):
    assert token in main,token
# Inspect the same threshold equations at their new canonical location.
for token in (
    "if finger_distance < drag_radius * exit_ratio:",
    "elif finger_distance >= drag_radius * start_ratio:",
    "if next_confirmation >= confirm_seconds:",
):
    assert token in boost_policy, token

for token in (
    'radius = CONTROLLER_RUN_RADIUS',
    'boost_base_radius = max_radius',
    'draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 2.8125, true)',
    '0.0, TAU, 96, boost_guide, 1.875, true)',
    '0.0, TAU, 48, low, 1.875, true)',
    'angle - 0.26, angle + 0.26, 20, indicator_color, 6.5625, true)',
    'base + sideways * 8.4375, base - sideways * 8.4375',
    'var label_width: float = 155.625',
    'var label_height: float = 31.875',
    'boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 15.0',
    'draw_rect(rect, rim_color, false, 1.875, true)',
    'HORIZONTAL_ALIGNMENT_CENTER, label_width, 17, accent)',
):
    assert token in ui,token

# Time/velocity, attack/STEP flick classification and guard hold are not
# dimensions of the analog RUN/BOOST hit-zone and stay intentionally intact.
for name,value in (
    ("BOOST_CONFIRM_SECONDS",.10),
    ("BOOST_SPEED_BLEND_SECONDS",.20),
    ("STEP_FLICK_MIN_HORIZONTAL",78.),
    ("STEP_FLICK_MIN_VERTICAL",78.),
    ("STEP_FLICK_MIN_PIXELS_PER_SEC",500.),
    ("CONTROLLER_REGION_START_RATIO",.50),
):
    assert math.isclose(const(main,name),value),(name,value)
assert "func _update_guard_hold() -> void:" in main
assert "func _switch_lock_screen_direction(direction: int) -> void:" in main
assert "func _end_drag(release_pos: Vector2) -> void:" in main

# v245 was 125% of v244; v248 is another 150% of v245.
for step in range(0,101):
    old=step/100*56.
    new=old*scale
    def strength(distance,run,dead):
        return max(0.,min(1.,(distance-dead)/(run-dead)))
    assert math.isclose(strength(old,56.,9.),
                        strength(new,105.,16.875),abs_tol=1e-9)
    assert (old>=84.*1.10)==(new>=157.5*1.10)
print("PASS v245-v248: RUN 105px / deadzone 16.875px / BOOST 157.5px")
print("PASS v245-v248: BOOST entry 173.25px / exit 141.75px; v245 1.25x then v248 1.5x")
print("PASS v245-v248: ring, arrow and text scaled; lock/STEP/guard preserved")
print("Android touch and Godot rendering are unverified")

assert "if distance <= deadzone:" in SERA_INPUT
assert "(radius - deadzone), 0.0, 1.0)" in SERA_INPUT

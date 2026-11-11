#!/usr/bin/env python3
"""SERA v245-v246: RUN/BOOST joystick + hit radius 125% of v244."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
main=(ROOT/"scripts/main.gd").read_text(encoding="utf-8")
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
assert (ROOT/"README_v245_ja.md").is_file()

# Prior exact radii: v244 RUN=56, deadzone=9, BOOST=84.
scale=1.25
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
assert math.isclose(const(main,"RUN_CONTROL_RADIUS"),70.)
assert math.isclose(const(main,"RUN_INPUT_DEADZONE_PIXELS"),11.25)
assert math.isclose(const(main,"DRAG_RADIUS"),105.)
assert math.isclose(v(ui,"boost_base_radius"),const(main,"DRAG_RADIUS"))
assert math.isclose(const(ui,"CONTROLLER_RUN_RADIUS"),const(main,"RUN_CONTROL_RADIUS"))
assert math.isclose(const(main,"BOOST_START_RADIUS_RATIO"),1.10)
assert math.isclose(const(main,"BOOST_EXIT_RADIUS_RATIO"),.90)
assert math.isclose(const(ui,"CONTROLLER_BOOST_START_RADIUS_RATIO"),
                    const(main,"BOOST_START_RADIUS_RATIO"))
assert math.isclose(const(main,"DRAG_RADIUS")*1.10,115.5)
assert math.isclose(const(main,"DRAG_RADIUS")*.90,94.5)
for token in (
    'if distance <= RUN_INPUT_DEADZONE_PIXELS:',
    '(RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)',
    'if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:',
    'elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:',
    'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
    'if current_touch < 0 and _controller_start_area_contains(event.position):',
    'if not _controller_start_area_contains(event.position):',
    'const CONTROLLER_REGION_START_RATIO: float = 0.50',
    'const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)',
    'var auto_lock_enabled: bool = true',
):
    assert token in main,token
for token in (
    'radius = CONTROLLER_RUN_RADIUS',
    'boost_base_radius = max_radius',
    'draw_arc(anchor_point, radius, 0.0, TAU, 96, rim_color, 1.875, true)',
    '0.0, TAU, 96, boost_guide, 1.25, true)',
    '0.0, TAU, 48, low, 1.25, true)',
    'angle - 0.26, angle + 0.26, 20, indicator_color, 4.375, true)',
    'base + sideways * 5.625, base - sideways * 5.625',
    'var label_width: float = 103.75',
    'var label_height: float = 21.25',
    'boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 10.0',
    'draw_rect(rect, rim_color, false, 1.25, true)',
    'HORIZONTAL_ALIGNMENT_CENTER, label_width, 11, accent)',
    'const CONTROLLER_FRAME_START_RATIO: float = 0.50',
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

# 25% larger relative to v244 at all normalized RUN/BOOST distances.
for step in range(0,101):
    old=step/100*56.
    new=old*1.25
    def strength(distance,run,dead):
        return max(0.,min(1.,(distance-dead)/(run-dead)))
    assert math.isclose(strength(old,56.,9.),
                        strength(new,70.,11.25),abs_tol=1e-9)
    assert (old>=84.*1.10)==(new>=105.*1.10)
print("PASS v245: RUN 70px / deadzone 11.25px / BOOST 105px")
print("PASS v245: BOOST entry 115.5px / exit 94.5px, all +25% over v244")
print("PASS v245-v246: ring, arrow and text +25%; lock/STEP/guard preserved")
print("Android touch and Godot rendering are unverified")

#!/usr/bin/env python3
"""Historical v244/v245 RUN/BOOST ratios with v248 further 1.5x scaling."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
cfg=(root/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v(\d+)"',cfg) and int(re.search(r'config/name="SERA v(\d+)"',cfg).group(1))>=244
assert (root/"README_v244_ja.md").is_file()

def const(src,name):
    match=re.search(r"^const "+name+r": float = ([0-9.]+)",src,re.M)
    assert match,name
    return float(match.group(1))
def declared_var(src,name):
    match=re.search(r"^var "+name+r": float = ([0-9.]+)",src,re.M)
    assert match,name
    return float(match.group(1))

run=const(main,"RUN_CONTROL_RADIUS")
dead=const(main,"RUN_INPUT_DEADZONE_PIXELS")
baseline=const(main,"DRAG_RADIUS")
start_ratio=const(main,"BOOST_START_RADIUS_RATIO")
exit_ratio=const(main,"BOOST_EXIT_RADIUS_RATIO")
run_draw=const(ui,"CONTROLLER_RUN_RADIUS")
boost_draw=declared_var(ui,"boost_base_radius")
initial_run_draw=declared_var(ui,"radius")
ui_start_ratio=const(ui,"CONTROLLER_BOOST_START_RADIUS_RATIO")
# v244 0.5x, v245 1.25x and v248 1.5x = 0.9375x original v243.
scale=.5*1.25*1.5
assert math.isclose(run,112.0*scale)
assert math.isclose(dead,18.0*scale)
assert math.isclose(baseline,168.0*scale)
assert math.isclose(run_draw,run)
assert math.isclose(initial_run_draw,run)
assert math.isclose(boost_draw,baseline)
assert start_ratio == ui_start_ratio == 1.10
assert exit_ratio == .90
assert math.isclose(baseline*start_ratio,173.25)
assert math.isclose(baseline*exit_ratio,141.75)

for token in (
    'if distance <= RUN_INPUT_DEADZONE_PIXELS:',
    '(RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)',
    'if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:',
    'elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:',
    'boost_confirm_elapsed >= BOOST_CONFIRM_SECONDS',
    'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
    'func _controller_start_area_contains(pos: Vector2) -> bool:',
    'const CONTROLLER_REGION_START_RATIO: float = 0.50',
    'current_touch < 0 and _controller_start_area_contains(event.position)',
    'if not _controller_start_area_contains(event.position):',
):
    assert token in main,token
for token in (
    'radius = CONTROLLER_RUN_RADIUS',
    'boost_base_radius = max_radius',
    'draw_arc(anchor_point, boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO,',
    'var shell_radius: float = boost_base_radius * BOOST_SHELL_RADIUS_RATIO',
    'boost_base_radius * BOOST_CHEVRON_OUTER_RATIO',
    '_draw_analog_controller(accent, low)',
):
    assert token in ui,token
assert 'const BOOST_SHELL_SEGMENT_WIDTH: float = 4.6875' in ui
assert 'const BOOST_CHEVRON_HALF_WIDTH: float = 8.4375' in ui
assert 'var label_width: float = 155.625' in ui
assert 'var label_height: float = 31.875' in ui
assert 'HORIZONTAL_ALIGNMENT_CENTER, label_width, 17, accent)' in ui

# RUN/BOOST size changes do not alter flick/guard/attack thresholds, lock
# controls, boost timing, speed or camera. v246 expands touch start locations.
preserved={
    'STEP_FLICK_MIN_HORIZONTAL':78.,
    'STEP_FLICK_MIN_VERTICAL':78.,
    'STEP_FLICK_MIN_PIXELS_PER_SEC':500.,
    'BOOST_CONFIRM_SECONDS':.10,
    'CONTROLLER_REGION_START_RATIO':.50,
}
for name,value in preserved.items():
    assert math.isclose(const(main,name),value),(name,const(main,name))
assert 'const BOOST_SPEED_BLEND_SECONDS: float = 0.20' in main
assert 'OPERATION_ZONE_' not in ui
assert 'func _update_guard_hold() -> void:' in main
assert 'func _end_drag(release_pos: Vector2) -> void:' in main
assert 'func _switch_lock_screen_direction(direction: int) -> void:' in main

# v248 input strength keeps the same normalized analog curve after scaling.
def intensity(distance,full,deadzone):
    return max(0,min(1,(distance-deadzone)/(full-deadzone)))
for distance in (0,8.4375,16.875,33.75,52.5,105.):
    now=intensity(distance,run,dead)
    old=intensity(distance/scale,112.,18.)
    assert math.isclose(now,old,abs_tol=1e-9)
assert baseline*exit_ratio < baseline*start_ratio
assert math.isclose((baseline*start_ratio)/(168.*start_ratio),scale)
assert math.isclose((baseline*exit_ratio)/(168.*exit_ratio),scale)
print("PASS v244-v248: RUN 105px, deadzone 16.875px, BOOST baseline 157.5px")
print("PASS v244-v248: BOOST start 173.25px / end 141.75px, 93.75% of v243")
print("PASS v244-v248: proportional visual scaling; flick/guard unchanged")
print("Godot runtime and Android touch/visual sizes NOT tested")

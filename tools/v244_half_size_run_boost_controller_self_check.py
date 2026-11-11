#!/usr/bin/env python3
"""SERA v244-v245: scale RUN/BOOST input and dynamic visuals proportionally."""
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
assert math.isclose(run,112.0*.625)
assert math.isclose(dead,18.0*.625)
assert math.isclose(baseline,168.0*.625)
assert math.isclose(run_draw,run)
assert math.isclose(initial_run_draw,run)
assert math.isclose(boost_draw,baseline)
assert start_ratio == ui_start_ratio == 1.10
assert exit_ratio == .90
assert math.isclose(baseline*start_ratio,115.5)
assert math.isclose(baseline*exit_ratio,94.5)

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
    'const CONTROLLER_FRAME_START_RATIO: float = 0.50',
    '_draw_analog_controller(accent, low)',
):
    assert token in ui,token
assert 'const BOOST_SHELL_SEGMENT_WIDTH: float = 3.125' in ui
assert 'const BOOST_CHEVRON_HALF_WIDTH: float = 5.625' in ui
assert 'var label_width: float = 103.75' in ui
assert 'var label_height: float = 21.25' in ui
assert 'HORIZONTAL_ALIGNMENT_CENTER, label_width, 11, accent)' in ui

# This change does NOT half flick/guard/attack thresholds, lock controls,
# input acquisition region, boost timing, speed, or the camera.
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
assert 'const CONTROLLER_FRAME_START_RATIO: float = 0.50' in ui
assert 'func _update_guard_hold() -> void:' in main
assert 'func _end_drag(release_pos: Vector2) -> void:' in main
assert 'func _switch_lock_screen_direction(direction: int) -> void:' in main

# 50% (v244) * 125% (v245) = 62.5% of v243. The stick response
# follows exactly the same normalized curve over the scaled distance.
def intensity(distance,full,deadzone):
    return max(0,min(1,(distance-deadzone)/(full-deadzone)))
for distance in (0,5.625,11.25,22.5,35.,70.):
    now=intensity(distance,run,dead)
    old=intensity(distance*1.6,112.,18.)
    assert math.isclose(now,old,abs_tol=1e-9)
assert baseline*exit_ratio < baseline*start_ratio
assert math.isclose((baseline*start_ratio)/(168.*start_ratio),.625)
assert math.isclose((baseline*exit_ratio)/(168.*exit_ratio),.625)
print("PASS v244-v245: RUN 70px, deadzone 11.25px, BOOST baseline 105px")
print("PASS v244-v245: BOOST start 115.5px / end 94.5px, both 62.5% of v243")
print("PASS v244-v245: proportional visual scaling; flick/guard/quadrant unchanged")
print("Godot runtime and Android touch/visual sizes NOT tested")

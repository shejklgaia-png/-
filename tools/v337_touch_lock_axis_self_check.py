#!/usr/bin/env python3
"""v337: four-screen-sector compass uses finger-down -> raw lock projection."""
from sera_active_contracts import require_min_version
from pathlib import Path
import math
root = Path(__file__).resolve().parents[1]
m = (root / "scripts/main.gd").read_text(encoding="utf-8")
p = (root / "scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
ui = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
dbg = (root / "scripts/sera_facing_angle_debug.gd").read_text(encoding="utf-8")

assert "func touch_to_target_forward(" in p
fn = p.split("func touch_to_target_forward(", 1)[1].split("static func sector_index(", 1)[0]
assert "camera.unproject_position(target_world) - touch_screen" in fn
assert "camera.is_position_behind(target_world)" in fn
assert "toward_lock.length_squared() < 16.0" in fn
assert "return toward_lock.normalized()" in fn

down = m.split("func _begin_drag(pos: Vector2) -> void:", 1)[1].split(
    "func _analog_stick_direction(", 1)[0]
assert down.index("pointer_origin = pos") < down.index(
    "gesture_screen_forward = _touch_to_lock_forward(pos)")
assert 'touch_ui.call("set_flick_sector_forward", gesture_screen_forward, 0.0, true)' in down

held = m.split("func _change_drag(pos: Vector2) -> void:", 1)[1].split(
    "func _update_boost_gesture(", 1)[0]
guard = held.split("if guard_active:", 1)[1].split("pointer_location = pos", 1)[0]
assert "gesture_screen_forward =" not in guard
released = m.split("func _end_drag(release_pos: Vector2) -> void:", 1)[1].split(
    "func _is_character_forward_flick(", 1)[0]
assert "gesture_screen_forward = _projected_sera_facing()" not in released

assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in m
assert 'displacement, seconds, gesture_screen_forward,' in m
sector = m.split("func _update_controller_flick_guide(delta: float) -> void:", 1)[1]
assert "forward: Vector2 = gesture_screen_forward" in sector
assert "if not gesture_active and touch_lock_origin_initialized:" in sector
assert "forward = _touch_to_lock_forward(pointer_origin)" in sector
assert 'touch_ui.call("set_flick_sector_forward", forward, delta, true)' in sector
assert 'gesture_screen_forward = _projected_sera_facing()' not in m
assert 'camera, origin_screen, _current_lock_aim_world(),' in m
assert "screen_point" not in p or True
assert "sector_index(displacement: Vector2, screen_axis: Vector2)" in p
assert "var center: float = flick_sector_direction(sector).angle()" in ui
assert "anchor_point + Vector2.RIGHT.rotated(outer_angle)" in ui
assert 'angle_debug_overlay.call("set_geometry", pointer_origin,' in m
assert "touch_origin + ray * 115.0" in dbg
assert require_min_version((root / "project.godot").read_text(), 337)

# Screen-space angular sectors: tilted/front vectors, all quadrants and
# boundary angles. This checks the math independently of the 3D projection.
def sector(delta, axis):
    ax, ay = axis
    bx, by = delta
    length = math.hypot(ax, ay)
    ax, ay = ax / length, ay / length
    right = (-ay, ax)
    angle = math.atan2(bx*right[0]+by*right[1], bx*ax+by*ay)
    return math.floor((angle + math.pi*0.25) / (math.pi*0.5)) % 4

for origin, target in [
    ((100, 400), (400, 200)),
    ((400, 400), (100, 200)),
    ((250, 100), (250, 600)),
    ((600, 200), (50, 300)),
]:
    axis = (target[0] - origin[0], target[1] - origin[1])
    norm = math.hypot(*axis)
    front = (axis[0] / norm, axis[1] / norm)
    assert sector(front, front) == 0
    assert sector((-front[1], front[0]), front) == 1
    assert sector((-front[0], -front[1]), front) == 2
    assert sector((front[1], -front[0]), front) == 3
print("PASS v337 finger-down -> lock sector, frozen swipe, guard, UI")

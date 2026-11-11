#!/usr/bin/env python3
"""SERA v254: exactly eight 45-degree sectors, STEP quantization and Bash gating."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
def read(path): return (root / path).read_text(encoding="utf-8")
main = read("scripts/main.gd")
policy = read("scripts/flick_direction_policy.gd")
project = read("project.godot")
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 254
assert (root/"README_v254_ja.md").is_file()
assert "Mandatory eight-way 45-degree directional flick sectors" in read("AGENTS.md")
assert "45°×8区画" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")

for phrase in (
    "const SECTOR_COUNT: int = 8",
    "const SECTOR_ANGLE: float = TAU / float(SECTOR_COUNT)",
    "static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:",
    "var angle: float = atan2(displacement.dot(right), displacement.dot(forward))",
    "return posmod(floori((angle + SECTOR_ANGLE * 0.5) / SECTOR_ANGLE)",
    "static func eight_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:",
    "var sector: int = sector_index(displacement, screen_axis)",
    "return Vector2.UP.rotated(float(sector) * SECTOR_ANGLE)",
    "sector_index(displacement, screen_axis) == 0",
    "static func within_sector(",
    "static func is_flick(",
):
    assert phrase in policy, phrase

step = main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:", 1)[1].split(
    "func _start_omni_step(", 1)[0]
assert "return FLICK_DIRECTION_POLICY.eight_way_direction(displacement, Vector2.UP)" in step
for phrase in ("seconds > STEP_FLICK_MAX_SECONDS",
               "distance < STEP_FLICK_MIN_HORIZONTAL",
               "distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC",
               "gesture_max_travel > distance * 1.20"):
    assert phrase in step, phrase
assert "return displacement / distance" not in step
omni = main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step()",1)[0]
for phrase in ("var direction: Vector2 = flick.normalized()",
               "var radial_distance: float = BACK_STEP_DISTANCE if direction.y >= 0.0 else STEP_FORWARD_DISTANCE",
               "step_radial_delta = direction.y * radial_distance",
               "step_linear_fallback = true",
               "rig.call(\"start_omni_step\", direction)"):
    assert phrase in omni, phrase
assert "step_arc_length = clampf(" in omni
assert "STEP_MIN_ARC_LENGTH, STEP_MAX_ARC_LENGTH)" in omni

drag = main.split("func _change_drag(",1)[1].split("func _update_boost_gesture(",1)[0]
release = main.split("func _end_drag(",1)[1].split("func _remember_jump_flick_sample(",1)[0]
classifier = main.split("func _is_character_forward_flick(",1)[1].split(
    "func _is_upward_jump_flick(",1)[0]
assert "FLICK_DIRECTION_POLICY.within_sector(" in drag
assert "return FLICK_DIRECTION_POLICY.is_flick(" in classifier
assert "gesture_screen_forward" in classifier
assert "_classify_recent_character_forward_flick()" in release
assert "_is_character_forward_flick(release_pos - pointer_origin, press_duration)" in release
assert "if bash_requested and _request_combo_bash():" in release
assert "_classify_step_flick(" in release
assert "if _start_omni_step(flick_direction):" in release
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in main
assert "_screen_drag_to_ground(direction_input)" in main

# Numeric mirror of the GDScript atan2/floor/posmod algorithm.
sector_angle = math.tau / 8
def sector(displacement, axis=(0,-1)):
    x,y = displacement
    ax,ay = axis
    if math.hypot(x,y)<1e-6 or math.hypot(ax,ay)<1e-6:
        return -1
    am = math.hypot(ax,ay)
    ax,ay = ax/am,ay/am
    rx,ry = -ay,ax
    angle = math.atan2(x*rx+y*ry,x*ax+y*ay)
    return math.floor((angle+sector_angle/2)/sector_angle)%8

def direction(n):
    theta=n*sector_angle
    return math.sin(theta),-math.cos(theta)

assert sector((0,0))==-1
assert sector((0,-1))==0
assert sector((1,-1))==1
assert sector((1,0))==2
assert sector((1,1))==3
assert sector((0,1))==4
assert sector((-1,1))==5
assert sector((-1,0))==6
assert sector((-1,-1))==7
for i in range(8):
    expected = direction(i)
    assert sector(expected)==i, (i,expected,sector(expected))
    assert math.isclose(math.hypot(*expected),1,abs_tol=1e-10)
    for delta in (-22.4, -10.0, 0.0, 12.0, 22.4):
        theta = i*45.0+delta
        input_dir=(math.sin(math.radians(theta)),-math.cos(math.radians(theta)))
        assert sector(input_dir)==i,(i,theta,sector(input_dir))
    # Every 45-degree wedge is disjoint; just past each edge belongs
    # to one of its two neighbors. At the 22.5 tie, clockwise wins.
    ahead=(math.sin(math.radians(i*45+22.6)),-math.cos(math.radians(i*45+22.6)))
    behind=(math.sin(math.radians(i*45-22.6)),-math.cos(math.radians(i*45-22.6)))
    assert sector(ahead)==(i+1)%8
    assert sector(behind)==(i-1)%8
# Projected character facing can be rotated independently of screen-up.
for actor_angle in range(0,360,5):
    axis=(math.sin(math.radians(actor_angle)),-math.cos(math.radians(actor_angle)))
    assert sector(axis,axis)==0
    assert sector((-axis[0],-axis[1]),axis)==4
    for i in range(8):
        theta=math.radians(actor_angle+i*45.0)
        vec=(math.sin(theta),-math.cos(theta))
        assert sector(vec,axis)==i,(actor_angle,i,sector(vec,axis))
# The v253 Bash sector gate must remain one 45-degree wedge (±22.5°).
for angle in (-22.4,-1,0,1,22.4):
    d=(math.sin(math.radians(angle)),-math.cos(math.radians(angle)))
    forward=d[1]*-1
    side=abs(d[0])
    assert sector(d)==0 and side<=forward*.42+1e-10
for angle in (-22.6,22.6,45,90,180,270):
    d=(math.sin(math.radians(angle)),-math.cos(math.radians(angle)))
    assert sector(d)!=0
print("PASS v254: eight exclusive 45-degree sectors + diagonals/boundaries")
print("PASS v254: screen-based STEP, actor-facing Bash, thresholds and shared policy")
print("Godot parser, Android input and animation feel not tested")

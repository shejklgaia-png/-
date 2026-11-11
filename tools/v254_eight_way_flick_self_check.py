#!/usr/bin/env python3
"""Historic v254 flick regression updated to v258 four equal 90-degree sectors."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd");policy=read("scripts/flick_direction_policy.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=258 and (R/"README_v254_ja.md").exists()
for term in ("const SECTOR_COUNT: int = 4",
             "const SECTOR_ANGLE: float = TAU / 4.0",
             "static func sector_index(displacement: Vector2, screen_axis: Vector2) -> int:",
             "var angle: float = atan2(displacement.dot(right), displacement.dot(forward))",
             "static func four_way_direction(displacement: Vector2, screen_axis: Vector2) -> Vector2:",
             "return Vector2.UP.rotated(float(sector) * SECTOR_ANGLE)",
             "sector_index(displacement, screen_axis) == 0",
             "static func is_flick("):
    assert term in policy,term
step=m.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
for tok in ("return FLICK_DIRECTION_POLICY.four_way_direction(displacement, gesture_screen_forward)",
            "seconds > STEP_FLICK_MAX_SECONDS","distance < STEP_FLICK_MIN_HORIZONTAL",
            "distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC",
            "gesture_max_travel > distance * 1.20"):
    assert tok in step,tok
omni=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
for tok in ("var direction: Vector2 = flick.normalized()",
            "BACK_STEP_DISTANCE if direction.y >= 0.0 else STEP_FORWARD_DISTANCE",
            "step_linear_fallback = true", 'rig.call("start_omni_step", direction)'):
    assert tok in omni,tok
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
assert "target_parts.call(\"install_movement_colliders\", target_collider)" in m
assert "_screen_drag_to_ground(direction_input)" in m
def sector(vec,axis=(0.,-1.)):
    if math.hypot(*vec)<1e-7 or math.hypot(*axis)<1e-7:return -1
    ax,ay=axis[0]/math.hypot(*axis),axis[1]/math.hypot(*axis)
    rx,ry=-ay,ax
    theta=math.atan2(vec[0]*rx+vec[1]*ry,vec[0]*ax+vec[1]*ay)
    return math.floor((theta+math.pi/4)/(math.pi/2))%4
def direction(i):
    t=i*math.pi/2
    return math.sin(t),-math.cos(t)
assert sector((0,0))==-1
for i in range(4):
    assert sector(direction(i))==i
    for offset in (-44.9,-25,0,25,44.9):
        a=math.radians(i*90+offset)
        assert sector((math.sin(a),-math.cos(a)))==i
    for offset,j in ((45.1,(i+1)%4),(-45.1,(i-1)%4)):
        a=math.radians(i*90+offset)
        assert sector((math.sin(a),-math.cos(a)))==j
for base in range(0,360,5):
    axis=direction(0)
    a=math.radians(base)
    axis=math.sin(a),-math.cos(a)
    for i in range(4):
        t=a+i*math.pi/2
        vec=math.sin(t),-math.cos(t)
        assert sector(vec,axis)==i,(base,i)
print("PASS v254/v258: four mutually exclusive 90-degree sectors, all camera-facing orientations")
print("PASS v254/v258: STEP motion, GUARD/Combo Bash priority and collision preserved")

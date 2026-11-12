#!/usr/bin/env python3
"""v262 all-angle STEP input, distance and 4-clip pose continuity."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
main=read("scripts/main.gd");p=read("scripts/flick_direction_policy.gd");rig=read("scripts/sera_rig.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=262
assert (R/"README_v262_ja.md").exists()
policy=p.split("static func screen_step_direction(displacement: Vector2) -> Vector2:",1)[1].split("static func within_sector(",1)[0]
assert "return displacement.normalized()" in policy and "return Vector2.ZERO" in policy
assert "four_way_direction(" not in policy
step=main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split("func _start_omni_step(",1)[0]
motion=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
pose=rig.split("func _blended_directional_step_pose(uid: String, t: float) -> Dictionary:",1)[1].split("func start_omni_step(",1)[0]
for s in ("return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)","seconds > STEP_FLICK_MAX_SECONDS","distance < STEP_FLICK_MIN_HORIZONTAL","distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC"):
    assert s in step,s
for s in ("var direction: Vector2 = flick.normalized()","step_arc_length = _step_fixed_distance_for_direction(direction)","step_radial_delta = 0.0","var world_step: Vector3 = _screen_drag_to_ground(direction)","var pose_direction: Vector2 = _step_local_pose_direction(world_step)","step_linear_offset = Vector2(world_step.x, world_step.z)",'rig.call("start_omni_step", pose_direction)',"step_linear_fallback = true"):
    assert s in motion,s
for s in ("_sample_step_clip_pose(STEP_FORWARD_CLIP, uid, 0.0)","_sample_step_clip_pose(STEP_BACK_CLIP, uid, 0.0)","STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP","atan2(absf(direction.x), absf(direction.y))","alpha = alpha * alpha * (3.0 - 2.0 * alpha)",'.slerp(lateral["rotation"], alpha)','.lerp(lateral["position"], alpha)'):
    assert s in pose,s
assert "directional_step_vector = direction.normalized()" in rig
assert "_move_player_swept(requested, true)" in main
def v(a):return (math.sin(math.radians(a)),-math.cos(math.radians(a)))
def ease(t):return t*t*(3-2*t)
def alpha(x):
    t=math.atan2(abs(x[0]),abs(x[1]))/(math.pi/2)
    return ease(t)
def distance(x):
    angle=math.atan2(max(x[1],0.0),abs(x[0]))/(math.pi/2)
    return 3+2*ease(angle)
for a,w,d in ((0,0,3),(90,1,3),(180,0,5),(270,1,3)):
    x=v(a)
    assert math.isclose(alpha(x),w,abs_tol=1e-10)
    if d is not None:assert math.isclose(distance(x),d,abs_tol=1e-10)
for a in (30,45,60,120,135,150,210,225,240,300,315,330):
    assert 0<alpha(v(a))<1
for a in (45,135,225,315):assert math.isclose(alpha(v(a)),.5,abs_tol=1e-10)
last=v(0);last_alpha=alpha(last);last_dist=distance(last)
for k in range(1,1441):
    cur=v(k*.25)
    assert math.isclose(math.hypot(*cur),1,abs_tol=1e-10)
    assert math.dist(last,cur)<.0045
    assert abs(alpha(cur)-last_alpha)<.009
    assert abs(distance(cur)-last_dist)<.04
    assert 3-1e-10<=distance(cur)<=5+1e-10
    last=cur;last_alpha=alpha(cur);last_dist=distance(cur)
assert "const SECTOR_COUNT: int = 4" in p
assert "return sector_index(displacement, screen_axis) == 0" in p
assert "displacement, seconds, Vector2.UP," in main
assert "_combo_followup_input_window_open()" in main
assert "left_sector_world = left_sector_world.slerp(" in main
print("PASS v262: unquantized 360deg STEP, 0.25deg sweep and 3m/5m ends")
print("PASS v262: four authored poses with eased interpolation; collision/Bash/boost retained")
print("Godot/Android runtime not verified")

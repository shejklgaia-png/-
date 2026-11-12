#!/usr/bin/env python3
"""v262: full 360deg STEP aiming + seamless four-authored-clip pose interpolation."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text(encoding="utf-8")
main=read("scripts/main.gd")
policy=read("scripts/flick_direction_policy.gd")
rig=read("scripts/sera_rig.gd")
project=read("project.godot")
m=re.search(r'^config/name="SERA v(\d+)"$',project,re.M)
assert m and int(m.group(1))>=262
assert (ROOT/"README_v262_ja.md").exists()
assert "CURRENT v262 360-degree STEP" in read("AGENTS.md")
assert "v262 — STEPの進行方向" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
p=policy.split("static func screen_step_direction(displacement: Vector2) -> Vector2:",1)[1].split(
    "static func within_sector(",1)[0]
assert "if displacement.length_squared() < 0.000001:" in p
assert "return Vector2.ZERO" in p
assert "return displacement.normalized()" in p
assert "four_way_direction(" not in p
step=main.split("func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",1)[1].split(
    "func _start_omni_step(",1)[0]
motion=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step()",1)[0]
pose=rig.split("func _blended_directional_step_pose(uid: String, t: float) -> Dictionary:",1)[1].split(
    "func start_omni_step(",1)[0]
for k in ("return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)",
          "seconds > STEP_FLICK_MAX_SECONDS",
          "distance < STEP_FLICK_MIN_HORIZONTAL",
          "distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC",
          "gesture_max_travel > distance * 1.20"):
    assert k in step,k
for k in ("var direction: Vector2 = flick.normalized()",
          "var camera_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT).normalized()",
          "var facing_forward: Vector3 = -player.global_transform.basis.z",
          "var back_mix: float = smoothstep(-0.25, 0.25, direction.y)",
          "STEP_FORWARD_DISTANCE, BACK_STEP_DISTANCE, back_mix)",
          "step_radial_delta = direction.y * radial_distance",
          "step_speed_current = lerpf(radial_speed, lateral_speed, absf(direction.x))",
          "var world_step: Vector3 = (camera_right * direction.x * side_length",
          "- facing_forward * step_radial_delta",
          "world_step = world_step.normalized() * step_arc_length",
          "step_linear_fallback = true",
          "step_linear_offset = Vector2(world_step.x, world_step.z)",
          "rig.call(\"start_omni_step\", direction)",
          "_cancel_combo_followup_windows_for_movement()"):
    assert k in motion,k
for k in ("_sample_step_clip_pose(STEP_FORWARD_CLIP, uid, 0.0)",
          "_sample_step_clip_pose(STEP_BACK_CLIP, uid, 0.0)",
          "STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP",
          "var alpha: float = atan2(absf(direction.x), absf(direction.y)) / (PI * 0.5)",
          "alpha = alpha * alpha * (3.0 - 2.0 * alpha)",
          '.slerp(lateral["rotation"], alpha)',
          '.lerp(lateral["position"], alpha)',
          '.lerp(lateral["scale"], alpha)'):
    assert k in pose,k
assert "directional_step_vector = direction.normalized()" in rig
assert 'current_clip == STEP_RIGHT_CLIP' in rig
assert "_switch_clip(STEP_RIGHT_CLIP, 0.12)" in rig
assert "_switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, 0.16)" in rig

# 0 degrees = screen UP. The unit swipe vector must rotate freely through
# all quadrants and across 45/90/180/270/360 without quantized jumps.
def screen_direction(deg):
    a=math.radians(deg)
    return (math.sin(a),-math.cos(a))

def alpha_for(v):
    raw=math.atan2(abs(v[0]),abs(v[1]))/(math.pi*.5)
    return raw*raw*(3-2*raw)

def smoothstep(low,high,y):
    t=max(0.,min(1.,(y-low)/(high-low)))
    return t*t*(3-2*t)

def step_distance(v,radius=6.0):
    x,y=v
    side_length=min(max(2.,radius*math.radians(35.)),min(4.,10*.40))
    forwardback=3.+smoothstep(-.25,.25,y)
    radial=y*forwardback
    distance=max(2.,min(4.,math.hypot(abs(x)*side_length,radial)))
    return radial,distance

canonical=[(0,(0,-1),3.0),(90,(1,0),None),
           (180,(0,1),4.0),(270,(-1,0),None)]
for deg,expected,dist in canonical:
    v=screen_direction(deg)
    assert math.isclose(v[0],expected[0],abs_tol=1e-12)
    assert math.isclose(v[1],expected[1],abs_tol=1e-12)
    assert alpha_for(v) >= 0
    if dist is not None:
        assert math.isclose(step_distance(v)[1],dist,abs_tol=1e-10)
    if deg in (0,180):
        assert math.isclose(alpha_for(v),0,abs_tol=1e-10)
    else:
        assert math.isclose(alpha_for(v),1,abs_tol=1e-10)
# At 45° a 50/50 interpolation, at 30° still a real diagonal.
for deg in (30,45,60,120,135,150,210,225,240,300,315,330):
    v=screen_direction(deg)
    assert abs(v[0])>0.01 and abs(v[1])>0.01
    assert 0.0 < alpha_for(v) < 1.0
for deg in (45,135,225,315):
    assert math.isclose(alpha_for(screen_direction(deg)),.5,abs_tol=1e-10)
# Full angle sweep in 0.25degree increments, including boundaries and wrap.
previous=screen_direction(0)
previous_alpha=alpha_for(previous)
previous_dist=step_distance(previous)[1]
for i in range(1,1441):
    deg=i*.25
    v=screen_direction(deg)
    assert math.isclose(math.hypot(*v),1.,abs_tol=1e-10)
    assert math.hypot(v[0]-previous[0],v[1]-previous[1])<.0045
    a=alpha_for(v)
    assert abs(a-previous_alpha) < .009
    radial,dist=step_distance(v)
    assert 2.0-1e-10 <= dist <= 4.0+1e-10
    assert abs(dist-previous_dist) < .035
    # Applying STEP's old four-way sector would lose angle; v262 does not.
    previous=v;previous_alpha=a;previous_dist=dist
# Smoothstep produces continuous slope at side vector y=0 and at +/-0.25.
for y in (-.25,0.,.25):
    e=1e-5
    left=3.+smoothstep(-.25,.25,y-e)
    middle=3.+smoothstep(-.25,.25,y)
    right=3.+smoothstep(-.25,.25,y+e)
    assert abs(right-left)<1e-4
    assert 3.0<=middle<=4.0
# Guard/Combo Bash retains its old 90-degree SERA-forward classifier.
assert "const SECTOR_COUNT: int = 4" in policy
assert "return sector_index(displacement, screen_axis) == 0" in policy
assert "displacement, seconds, gesture_screen_forward," in main
assert "and _is_character_forward_flick(release_pos - pointer_origin, press_duration)" in main
assert "not _combo_followup_input_window_open()" in main
assert "held_boost_left_sector_world = left_sector_world" in main
assert "_move_player_swept(requested, true)" in main
print("PASS v262: 360-degree unquantized STEP vector, all quadrant boundaries, continuous lengths")
print("PASS v262: eased four-clip pose blend, preserved cardinal 3m/4m and collision/BOOST/Bash")
print("Static/numerical checks only; Godot/Android visual playback not exercised")

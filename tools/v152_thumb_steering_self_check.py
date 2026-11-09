#!/usr/bin/env python3
"""v152: human-thumb swipe responsiveness without finger-jitter chatter.

Static source tests and independent synthetic touch + physics scenarios.
No Godot engine nor Xperia touch/visual run performed.
"""
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
overlay = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', project, re.M) == ["SERA v152"]
assert (root / "README_v152_ja.md").exists()

def part(start, end):
    return main.split("func " + start, 1)[1].split("func " + end, 1)[0]

begin = part("_begin_drag(pos: Vector2) -> void:",
             "_change_drag(pos: Vector2) -> void:")
change = part("_change_drag(pos: Vector2) -> void:",
              "_update_swipe_steering(delta: float) -> void:")
steering = part("_update_swipe_steering(delta: float) -> void:",
                "_update_boost_gesture(_delta: float) -> void:")
boost_gate = part("_update_boost_gesture(_delta: float) -> void:",
                  "_end_drag(release_pos: Vector2) -> void:")
release = part("_end_drag(release_pos: Vector2) -> void:",
               "_remember_jump_flick_sample(pos: Vector2) -> void:")
physics = part("_physics_process(delta: float) -> void:",
               "_close_step_target_relative_yaw(")
guard = part("_set_guard(active: bool) -> void:",
             "_update_guard_hold()")

for token in (
        "SWIPE_HEADING_SAMPLE_PIXELS: float = 12.0",
        "SWIPE_HEADING_WINDOW_MSEC: int = 80",
        "SWIPE_HEADING_TURN_CONFIRM_PIXELS: float = 20.0",
        "SWIPE_HEADING_TURN_CONFIRM_DEGREES: float = 40.0",
        "SWIPE_HEADING_DEADBAND_DEGREES: float = 12.0",
        "SWIPE_STEERING_FOLLOW_SECONDS: float = 0.055",
        "SWIPE_STEERING_FAST_FOLLOW_SECONDS: float = 0.020",
        "SWIPE_STEERING_FAST_TURN_DEGREES: float = 65.0",
        "SWIPE_STEERING_SNAP_TURN_DEGREES: float = 140.0",
        "SWIPE_BOOST_TRAVEL_PIXELS: float = 140.0",
        "SWIPE_BOOST_RESET_DOT: float = 0.65"):
    assert token in main, token

assert "swipe_heading_target = Vector2.ZERO" in begin
assert "swipe_heading_samples.clear()" in begin
assert 'swipe_heading_samples.append({"ms": Time.get_ticks_msec(), "pos": pos})' in begin
assert "swipe_boost_origin = pos" in begin
assert "var segment: Vector2 = pos - pointer_location" in change
assert 'swipe_heading_samples.append({"ms": now_ms, "pos": pos})' in change
assert "SWIPE_HEADING_WINDOW_MSEC" in change
assert "recent_displacement: Vector2" in change
assert "recent_displacement / travel" in change
assert "SWIPE_HEADING_DEADBAND_DEGREES" in change
assert "SWIPE_HEADING_TURN_CONFIRM_PIXELS" in change
assert "swipe_heading_target = next_heading" in change
assert "direction_input = next_heading" in change  # First intentional stroke only
assert "next_heading.dot(swipe_heading_target) < SWIPE_BOOST_RESET_DOT" in change
assert "swipe_boost_origin = pos" in change
assert "swipe_boost_travel = maxf(swipe_boost_travel, forward_travel)" in change
assert "swipe_boost_travel += distance" not in main
assert "swipe_boost_travel >= SWIPE_BOOST_TRAVEL_PIXELS" in change
assert "boost_has_activated_this_gesture = true" in change
assert "wrapf(target_angle - current_angle, -PI, PI)" in steering
assert "error >= deg_to_rad(SWIPE_STEERING_SNAP_TURN_DEGREES)" in steering
assert "SWIPE_STEERING_FAST_FOLLOW_SECONDS" in steering
assert "SWIPE_STEERING_FOLLOW_SECONDS" in steering
assert "Vector2.from_angle(" in steering
assert "lerp_angle(current_angle, target_angle, alpha)" in steering
assert "_update_swipe_steering(delta)" in physics
assert physics.index("_update_swipe_steering(delta)") < physics.index("var running: bool")
assert "swipe_boost_origin = pointer_location" in boost_gate
assert "swipe_heading_samples.clear()" in boost_gate
assert "direction_input = Vector2.ZERO" in release
assert "swipe_heading_samples.clear()" in release
assert "swipe_heading_target = Vector2.ZERO" in guard
assert "_classify_step_flick(" in release
assert "_start_attack()" in release
assert "_update_guard_hold()" in physics
assert "TAP_MAX_TRAVEL: float = 18.0" in main
assert "GUARD_HOLD_SECONDS: float = TAP_MAX_DURATION" in main
assert "BOOST  x1.5" in main
assert "player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * (" in physics
assert "MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0" in physics
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in physics
assert "RUN_DIRECTION_BLEND_SECONDS: float = 0.055" in rig
assert "SWIPE_HEADING_FOLLOW_SECONDS: float = 0.052" in overlay

def vec_dot(a,b):
    return a[0]*b[0]+a[1]*b[1]

def vector(x,y):
    length = math.hypot(x,y)
    return x/length,y/length

def wrap(a):
    return (a + math.pi) % (2*math.pi) - math.pi

class Thumb:
    def __init__(self):
        self.time = 0
        self.pos = (0.,0.)
        self.samples = [(0,self.pos)]
        self.target = None
        self.applied = None
        self.boost_origin = self.pos
        self.distance = 0.
        self.boost = False
        self.changes = 0
    def move(self, dx, dy, ms=16):
        self.time += ms
        self.pos=(self.pos[0]+dx,self.pos[1]+dy)
        self.samples.append((self.time,self.pos))
        while len(self.samples)>1 and (
                self.time-self.samples[0][0]>80 or len(self.samples)>20):
            self.samples.pop(0)
        recent=(self.pos[0]-self.samples[0][1][0],
                self.pos[1]-self.samples[0][1][1])
        travel=math.hypot(*recent)
        if travel >= 12.:
            next_heading=vector(*recent)
            if self.target is None:
                self.target=next_heading
                self.applied=next_heading
                self.changes+=1
            else:
                difference=math.acos(max(-1.,min(1.,vec_dot(next_heading,self.target))))
                minimum=20. if difference>math.radians(40) else 12.
                if difference>=math.radians(12) and travel>=minimum:
                    if vec_dot(next_heading,self.target)<.65:
                        self.distance=0.
                        self.boost_origin=self.pos
                        self.boost=False
                    self.target=next_heading
                    self.changes+=1
        if self.target is not None:
            offset=(self.pos[0]-self.boost_origin[0],
                    self.pos[1]-self.boost_origin[1])
            self.distance=max(self.distance,max(0.,vec_dot(offset,self.target)))
            if self.distance>=140.:
                self.boost=True
        self.step(ms/1000.)
    def step(self,dt):
        if self.target is None:
            return
        if self.applied is None:
            self.applied=self.target
            return
        old=math.atan2(self.applied[1],self.applied[0])
        new=math.atan2(self.target[1],self.target[0])
        error=abs(wrap(new-old))
        if error>=math.radians(140):
            self.applied=self.target
        else:
            tau=.020 if error>=math.radians(65) else .055
            a=1-math.exp(-max(0.,dt)/tau)
            heading=old+wrap(new-old)*a
            self.applied=math.cos(heading),math.sin(heading)

# All 360° compass directions are still valid with an intentional 16px input.
for degrees in range(0,360,5):
    a=math.radians(degrees)
    g=Thumb()
    g.move(16*math.cos(a),16*math.sin(a))
    assert g.target is not None
    assert abs(math.hypot(*g.target)-1)<1e-12

# Human tremor: ±3px horizontal, ±4px vertical during a moving hold
# should not change heading or accidentally reach the BOOST threshold.
g=Thumb()
for i in range(12):
    g.move(10,0)
assert not g.boost
before=g.changes
for i in range(30):
    g.move(-3 if i%2 else 3, -4 if i%2 else 4)
assert g.changes==before
assert g.distance<140.
assert not g.boost
assert g.target==(1.,0.)

# BOOST is net distance. A finger oscillating ±20px never charges 140px.
g=Thumb()
for i in range(30):
    g.move(-20 if i%2 else 20,0)
assert not g.boost

# One deliberate 140px forward stroke, followed by a human 180° turn:
# the new heading should register within four 10px reverse samples (64ms)
# and BOOST must turn off. Another forward-in-new-direction stroke can BOOST.
g=Thumb()
for i in range(14):
    g.move(10,0)
assert g.boost
turn_index=None
for i in range(8):
    g.move(-10,0)
    if turn_index is None and g.target[0]<-.5:
        turn_index=i+1
assert turn_index is not None and turn_index <= 4
assert not g.boost
assert g.applied[0] < -.5
for i in range(14):
    g.move(-10,0)
assert g.boost

# Rate-independent response to a moderate 35° direction change. A big
# reversal uses the fast/snap branch, so a tiny angular smoothing constant
# never makes a deliberate 180° turn unresponsive.
for fps in (30,60,120):
    current=0.
    target=math.radians(35)
    for _ in range(fps):
        a=1-math.exp(-(1/fps)/.055)
        current+=wrap(target-current)*a
    assert abs(wrap(target-current))<1e-8

print("v152 human-thumb jitter, 360 heading, responsive reversal and net BOOST: STATIC+MATH PASS")
print("Godot editor, Android touch, on-device latency and visuals: NOT TESTED")

#!/usr/bin/env python3
"""v163: symmetric eased RUN<->BOOST speed with continuous mid-blend reversals."""
from pathlib import Path
import re
import math
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
cfg=(root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',cfg,re.M)==["SERA v163"]
for token in (
    "const MOVEMENT_BOOST_MULTIPLIER: float = 1.5",
    "const BOOST_SPEED_BLEND_SECONDS: float = 0.20",
    "const BOOST_POSE_GRACE_SECONDS: float = 0.50",
    "const BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.95",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "var boost_speed_transition_start: float = 1.0",
    "var boost_speed_transition_target: float = 1.0",
    "var boost_speed_transition_elapsed: float = BOOST_SPEED_BLEND_SECONDS",
    "func _reset_boost_speed_transition() -> void:",
    "func _update_boost_speed(delta: float) -> void:",
    "boost_speed_transition_start = boost_speed_multiplier",
    "boost_speed_transition_target = wanted",
    "boost_speed_transition_elapsed = 0.0",
    "boost_speed_transition_elapsed + maxf(delta, 0.0)",
    "var eased: float = t * t * (3.0 - 2.0 * t)",
    "boost_speed_multiplier = lerpf(",
    "    _update_boost_speed(delta)",
    "player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * boost_speed_multiplier",
):
    assert token in main,token
assert "boost_speed_multiplier = move_toward(" not in main
assert main.count("_reset_boost_speed_transition()") >= 5
assert "const BOOST_TO_RUN_BLEND_SECONDS: float = 0.20" in rig
assert "const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.10" in ui
class Speed:
    def __init__(self):
        self.value=1.;self.start=1.;self.target=1.;self.elapsed=.2
    def tick(self,boost,dt):
        desired=1.5 if boost else 1.
        if not math.isclose(desired,self.target):
            self.start=self.value
            self.target=desired
            self.elapsed=0.
        self.elapsed=min(.2,self.elapsed+max(0.,dt))
        t=min(1.,max(0.,self.elapsed/.2))
        eased=t*t*(3.-2.*t)
        self.value=self.start+(self.target-self.start)*eased
        return self.value
    def reset(self):
        self.value=1.;self.start=1.;self.target=1.;self.elapsed=.2
s=Speed()
assert s.tick(False,.01)==1.
assert s.tick(True,0.)==1.
up=[s.tick(True,.01) for _ in range(20)]
assert all(a<=b for a,b in zip(up,up[1:]))
assert math.isclose(up[-1],1.5)
assert (up[1]-up[0]) < (up[9]-up[8])
assert (up[-1]-up[-2]) < (up[9]-up[8])
down=[s.tick(False,.01) for _ in range(20)]
assert all(a>=b for a,b in zip(down,down[1:]))
assert math.isclose(down[-1],1.0)
# Mid-acceleration cancellation must start at the exact current speed.
s.reset()
for i in range(8): before=s.tick(True,.01)
after=s.tick(False,0.)
assert math.isclose(before,after)
assert s.start==before and s.target==1.
for i in range(5): before=s.tick(False,.01)
after=s.tick(True,0.)
assert math.isclose(before,after)
assert s.start==before and s.target==1.5
for i in range(20): s.tick(True,.01)
assert math.isclose(s.value,1.5)
s.reset()
assert (s.value,s.start,s.target,s.elapsed)==(1.,1.,1.,.2)
print("v163 smooth RUN/BOOST bidirectional speed / reversal continuity: PASS")
print("Godot / Android device: NOT TESTED")

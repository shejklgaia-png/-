#!/usr/bin/env python3
"""v162: 0.50s BOOST pose hold followed by eased 0.20s BOOST -> RUN crossfade."""
from pathlib import Path
import math
import re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
cfg=(root/"project.godot").read_text(encoding="utf-8")
if "SERA v162" not in cfg:
    print("SKIP: historical v162 BOOST animation transition test (requires SERA v162)")
    raise SystemExit(0)
assert re.findall(r'^config/name="([^"]+)"$',cfg,re.M)==["SERA v162"]
for term in (
    "const BOOST_POSE_GRACE_SECONDS: float = 0.50",
    "boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS",
    "boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)",
    "movement_boost_active or boost_pose_grace_remaining > 0.0",
    'rig.call("set_moving", show_moving_pose, show_boost_pose, local_run_direction)',
    "const BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.95",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const RUN_CONTROL_RADIUS: float = 112.0",
):
    assert term in main,term
for term in (
    "const BOOST_TO_RUN_BLEND_SECONDS: float = 0.20",
    "const BOOST_STATE_BLEND_SECONDS: float = 0.08",
    "var boost_to_run_crossfade: bool = false",
    "boost_to_run_crossfade = (current_clip == BOOST_CLIP and wanted == RUN_CLIP)",
    "if current_clip == BOOST_CLIP and wanted == RUN_CLIP:",
    "fade_seconds = BOOST_TO_RUN_BLEND_SECONDS",
    "elif wanted == BOOST_CLIP or current_clip == BOOST_CLIP:",
    "fade_seconds = BOOST_STATE_BLEND_SECONDS",
    "if boost_to_run_crossfade:",
    "blend_weight = blend_weight * blend_weight * (3.0 - 2.0 * blend_weight)",
    "(prior_rotations[uid] as Quaternion).slerp(q, blend_weight)",
    "(prior_offsets[uid] as Vector3).lerp(translation, blend_weight)",
):
    assert term in rig,term
assert "const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.10" in ui
assert "func _draw_boost_outer_shell(accent: Color) -> void:" in ui
# Emulate state changes with 10ms ticks (0.5s hold + 0.2s crossfade).
class Visual:
    def __init__(self): self.grace=0.0; self.mode="WAIT"; self.fade=0.0
    def tick(self,dt,real_boost,moving=True,gesture=True,interrupted=False):
        if not gesture or interrupted: self.grace=0.
        elif real_boost: self.grace=.50
        else: self.grace=max(0.,self.grace-dt)
        pose_boost=real_boost or self.grace>0.
        wanted="BOOST" if pose_boost and gesture else ("RUN" if moving else "WAIT")
        if wanted!=self.mode:
            self.fade=0.
            self.fade_seconds=.20 if self.mode=="BOOST" and wanted=="RUN" else .08
            self.mode=wanted
        else: self.fade+=dt
        return self.mode
sim=Visual()
assert sim.tick(.01,True)=="BOOST"
for i in range(49):
    assert sim.tick(.01,False)=="BOOST",i
assert sim.tick(.01,False)=="RUN"
assert math.isclose(sim.fade_seconds,.20)
def eased(t): return t*t*(3-2*t)
assert eased(0)==0 and eased(1)==1
assert math.isclose(eased(.5),.5)
assert eased(.25)<.25 and eased(.75)>.75
# 10ms frames converge exactly to the fully mixed RUN pose after 0.2s.
for i in range(20): sim.tick(.01,False)
assert sim.fade>=.20-1e-9
# Re-BOOST during fade abandons RUN and starts a new BOOST cycle.
assert sim.tick(.01,True)=="BOOST"
assert math.isclose(sim.grace,.5)
assert math.isclose(sim.fade_seconds,.08)
for i in range(20): assert sim.tick(.01,False)=="BOOST"
assert sim.tick(.01,False,gesture=False,moving=False)=="WAIT"
print("v162 BOOST 0.50s hold -> eased 0.20s RUN transition / reboost interruption: PASS")
print("Godot engine and Android device: NOT TESTED")

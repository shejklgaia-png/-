#!/usr/bin/env python3
"""v159: prevent transient RUN/WAIT rig poses during BOOST direction changes."""
from pathlib import Path
import re, math
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
if "SERA v159" not in project:
    print("SKIP: historical v159 BOOST-pose regression (requires SERA v159)")
    raise SystemExit(0)
assert re.findall(r'^config/name="([^"]+)"
for token in (
    "const BOOST_POSE_GRACE_SECONDS: float = 0.30",
    "var boost_pose_grace_remaining: float = 0.0",
    "boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS",
    "boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)",
    "or combat_state != CombatState.IDLE:",
    "boost_pose_grace_remaining = 0.0",
    "show_boost_pose: bool",
    "movement_boost_active or boost_pose_grace_remaining > 0.0",
    "show_moving_pose: bool",
    "show_boost_pose and gesture_active",
    'rig.call("set_moving", show_moving_pose, show_boost_pose, local_run_direction)',
    "var boost_speed_target: float = MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0",
    "movement_boost_active and running",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const RUN_CONTROL_RADIUS: float = 112.0",
):
    assert token in main,token
assert "func set_moving(moving: bool, boosting: bool = false" in rig
assert "if moving and boosting:\n        _set_boost_motion_direction(local_direction)" in rig
assert "if local_direction.length_squared() < 0.000001:\n        return" in rig
assert "func _draw_analog_controller(" in ui
# Separate visual BOOST timer from the actual physics-speed multiplier.
class Pose:
    def __init__(self):
        self.hold=0.0
    def update(self,dt,real_boost,held=True,action=False,has_direction=True):
        if not held or action:
            self.hold=0.0
        elif real_boost:
            self.hold=0.30
        else:
            self.hold=max(0.0,self.hold-dt)
        visual_boost=real_boost or self.hold>0.0
        visual_moving=has_direction or (visual_boost and held)
        return "BOOST" if visual_moving and visual_boost else ("RUN" if visual_moving else "WAIT")
m=Pose()
assert m.update(.016,True)=="BOOST"
# Real BOOST drops on inward drag; visual remains BOOST while RUN continues.
for _ in range(15):assert m.update(.016,False)=="BOOST"
# Neutral thumb crossing cannot play WAIT; restoring another direction stays BOOST.
assert m.update(.016,False,has_direction=False)=="BOOST"
assert m.update(.016,True)=="BOOST"
# A sustained return to RUN expires the grace and selects RUN.
for _ in range(20):ans=m.update(.016,False)
assert ans=="RUN" and math.isclose(m.hold,0.0)
# Dropping touch or beginning any action immediately allows WAIT and action clips.
assert m.update(.016,True,held=False,has_direction=False)=="WAIT"
m.update(.016,True)
assert m.update(.016,False,action=True)=="RUN"
print("v159 BOOST-to-RUN visual grace / neutral crossing / action interruption: PASS")
print("Godot engine and Android touchscreen: NOT TESTED")
,project,re.M)==["SERA v159"]
for token in (
    "const BOOST_POSE_GRACE_SECONDS: float = 0.30",
    "var boost_pose_grace_remaining: float = 0.0",
    "boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS",
    "boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)",
    "or combat_state != CombatState.IDLE:",
    "boost_pose_grace_remaining = 0.0",
    "show_boost_pose: bool",
    "movement_boost_active or boost_pose_grace_remaining > 0.0",
    "show_moving_pose: bool",
    "show_boost_pose and gesture_active",
    'rig.call("set_moving", show_moving_pose, show_boost_pose, local_run_direction)',
    "var boost_speed_target: float = MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0",
    "movement_boost_active and running",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const RUN_CONTROL_RADIUS: float = 112.0",
):
    assert token in main,token
assert "func set_moving(moving: bool, boosting: bool = false" in rig
assert "if moving and boosting:\n        _set_boost_motion_direction(local_direction)" in rig
assert "if local_direction.length_squared() < 0.000001:\n        return" in rig
assert "func _draw_analog_controller(" in ui
# Separate visual BOOST timer from the actual physics-speed multiplier.
class Pose:
    def __init__(self):
        self.hold=0.0
    def update(self,dt,real_boost,held=True,action=False,has_direction=True):
        if not held or action:
            self.hold=0.0
        elif real_boost:
            self.hold=0.30
        else:
            self.hold=max(0.0,self.hold-dt)
        visual_boost=real_boost or self.hold>0.0
        visual_moving=has_direction or (visual_boost and held)
        return "BOOST" if visual_moving and visual_boost else ("RUN" if visual_moving else "WAIT")
m=Pose()
assert m.update(.016,True)=="BOOST"
# Real BOOST drops on inward drag; visual remains BOOST while RUN continues.
for _ in range(15):assert m.update(.016,False)=="BOOST"
# Neutral thumb crossing cannot play WAIT; restoring another direction stays BOOST.
assert m.update(.016,False,has_direction=False)=="BOOST"
assert m.update(.016,True)=="BOOST"
# A sustained return to RUN expires the grace and selects RUN.
for _ in range(20):ans=m.update(.016,False)
assert ans=="RUN" and math.isclose(m.hold,0.0)
# Dropping touch or beginning any action immediately allows WAIT and action clips.
assert m.update(.016,True,held=False,has_direction=False)=="WAIT"
m.update(.016,True)
assert m.update(.016,False,action=True)=="RUN"
print("v159 BOOST-to-RUN visual grace / neutral crossing / action interruption: PASS")
print("Godot engine and Android touchscreen: NOT TESTED")

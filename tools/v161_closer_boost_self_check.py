#!/usr/bin/env python3
"""v161: closer BOOST entry with preserved 15% radial hysteresis and aligned shell."""
from pathlib import Path
import re
import math
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',project,re.M)==["SERA v161"]
for token in (
    "const DRAG_RADIUS: float = 168.0",
    "const BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.95",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const BOOST_POSE_GRACE_SECONDS: float = 0.30",
    "const RUN_CONTROL_RADIUS: float = 112.0",
    "var finger_distance: float = pointer_location.distance_to(pointer_origin)",
    "if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:",
    "elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:",
):
    assert token in main,token
for token in (
    "const CONTROLLER_RUN_RADIUS: float = 112.0",
    "const CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.10",
    "const BOOST_SHELL_RADIUS_RATIO: float = 1.19",
    "const BOOST_CHEVRON_INNER_RATIO: float = 1.25",
    "const BOOST_CHEVRON_OUTER_RATIO: float = 1.35",
    "boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO",
    "func _draw_boost_outer_shell(accent: Color) -> void:",
    "for segment in range(8):",
    "boost_base_radius * BOOST_CHEVRON_OUTER_RATIO - label_height - 16.0",
):
    assert token in ui,token
run=112.0
start=168*1.10
exit_=168*0.95
shell=168*1.19
arrows_min=168*1.25
arrows_max=168*1.35
assert math.isclose(start,184.8)
assert math.isclose(exit_,159.6)
assert math.isclose(start-exit_,25.2)
assert run < exit_ < start < shell < arrows_min < arrows_max
assert math.isclose(shell,199.92)
assert math.isclose(arrows_min,210.0)
assert math.isclose(arrows_max,226.8)
class Boost:
    def __init__(self): self.active=False; self.elapsed=0.
    def tick(self,d,dt):
        if self.active:
            if d<exit_:
                self.active=False
                self.elapsed=0.
        elif d>=start:
            self.elapsed+=dt
            if self.elapsed>=.10: self.active=True
        else: self.elapsed=0.
        return self.active
b=Boost()
for _ in range(10): assert not b.tick(184.79,0.016)
for _ in range(6): assert not b.tick(184.8,0.016)
assert b.tick(184.8,0.016)
for _ in range(20): assert b.tick(160.0,0.016)
assert not b.tick(159.59,0.016)
for _ in range(20): assert not b.tick(180,0.016)
assert not b.tick(184.8,.05)
assert b.tick(184.8,.05)
print("v161 closer BOOST threshold, hysteresis and shell: STATIC + NUMERIC PASS")
print("Godot and Android runtime: NOT TESTED")

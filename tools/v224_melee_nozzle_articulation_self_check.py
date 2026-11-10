#!/usr/bin/env python3
"""SERA v224: melee nozzle articulation stays close to the authored hardware."""
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
fx = read("scripts/back_thruster_fx.gd")
project = read("project.godot")
model = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
motion = json.loads(read("assets/sera_source.json"))
assert int(re.search(r'config/name="SERA v(\\d+)"', project).group(1)) >= 224
assert "const MELEE_YAW_LIMIT_RADIANS: float = PI * 20.0 / 180.0" in fx
assert "const MELEE_PITCH_DOWN_LIMIT_RADIANS: float = PI * 35.0 / 180.0" in fx
assert "const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0" in fx
assert "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0" in fx
section = fx.split("func set_exhaust(", 1)[1]
clamp = """    if enabled and melee_sustain:
        yaw = clampf(yaw, -MELEE_YAW_LIMIT_RADIANS, MELEE_YAW_LIMIT_RADIANS)
        pitch = clampf(pitch, -PITCH_UP_LIMIT_RADIANS, MELEE_PITCH_DOWN_LIMIT_RADIANS)
"""
assert clamp in section
assert section.index(clamp) < section.index("steering_yaw = lerp_angle")
assert section.index(clamp) > section.index("pitch = lerpf(pitch, PITCH_DOWN_LIMIT_RADIANS, backstroke)")
assert "if enabled and world_exhaust_direction.length_squared() > 0.000001:" in section
assert "if enabled and left_sector_world.length_squared() > 0.000001:" in section
assert "if enabled and melee_sustain:\n        _avoid_melee_body_penetration" in section
assert "_update_ribbon_trail(enabled, delta)" in section
assert "var sustain_target: float = 1.0 if melee_sustain else 0.0" in section
assert 'const BURST_RISE_SECONDS: float = 0.05' in fx
assert 'const EXHAUST_RADIAL_SIDES: int = 10' in fx

# The authored second swing starts with >40 degree Torso yaw and >20 degree
# Chest yaw: root-relative aiming previously demanded extreme countersteer.
uid_by_name = {g["name"]: g["uuid"] for g in motion["groups"]}
melee2 = next(a for a in motion["animations"] if a["name"] == "Melee2")
def start_yaw(name):
    frames = [k for k in melee2["animators"][uid_by_name[name]]["keyframes"]
              if k["channel"] == "rotation"]
    frame = min(frames, key=lambda x: abs(float(x["time"])))
    return float(frame["data_points"][0]["y"])
assert start_yaw("Torso") > 40
assert start_yaw("Chest") > 20

# For both Blockbench nozzle hinge positions, every allowed yaw/down-pitch
# aims the nozzle away from the Chest by more than v222's minimum 0.55 dot.
group = {g["name"]: g for g in model["groups"]}
chest = group["Chest"]["origin"]
def normalized(v):
    mag = math.sqrt(sum(x*x for x in v))
    return [x/mag for x in v]
minimum = 1.0
for side in ("L", "R"):
    origin = group["Thruster_" + side]["origin"]
    outward = normalized([origin[i] - chest[i] for i in range(3)])
    for yaw_deg in range(-20, 21):
        for pitch_deg in range(-1, 36):
            y, p = math.radians(yaw_deg), math.radians(pitch_deg)
            axis = [math.sin(y) * math.cos(p), -math.sin(p),
                    math.cos(y) * math.cos(p)]
            dot = sum(outward[i]*axis[i] for i in range(3))
            minimum = min(minimum, dot)
            assert dot >= .55, (side, yaw_deg, pitch_deg, dot)
assert minimum > .58
print("PASS v224: authored Melee2 yaw cannot drive physical nozzles beyond 20/35 degrees")
print("PASS: both nozzle cones remain outside v222 torso clearance; BOOST/STEP ranges unchanged")
print("Godot and Android rendered appearance not tested")

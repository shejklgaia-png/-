#!/usr/bin/env python3
"""SERA v208: signed asymmetric rear-nozzle articulation limits."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
fx = (root / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version is not None and int(version.group(1)) >= 208

for line in (
    'const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0',
    'const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0',
    'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0',
    'nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)',
    '+ 2.0 * maxf(-local_dir.z, 0.0) + 0.02)',
    '-YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS',
    '-PITCH_UP_LIMIT_RADIANS, PITCH_DOWN_LIMIT_RADIANS',
    'steering_yaw = lerp_angle(steering_yaw, yaw, ease)',
    'steering_pitch = lerp_angle(steering_pitch, pitch, ease)',
):
    assert line in fx, line

# +X rotation of local +Z points downward; signed asymmetric clamp matters.
yaw_cap = math.radians(80)
up_cap = math.radians(1)
down_cap = math.radians(90)
def limits(x: float, y: float, z: float) -> tuple[float, float]:
    rear = max(z, 0.0) + 2.0 * max(-z, 0.0) + 0.02
    yaw = max(-yaw_cap, min(yaw_cap, math.atan2(x, rear)))
    pitch = max(-up_cap, min(down_cap, -math.atan2(y, math.hypot(x, z))))
    return yaw, pitch

def close(a: float, b: float) -> bool:
    return math.isclose(a, b, abs_tol=1e-9)

assert close(limits(1, 0, 0)[0], yaw_cap)
assert close(limits(-1, 0, 0)[0], -yaw_cap)
assert close(limits(0, -1, 0)[1], down_cap)
assert close(limits(0, 1, 0)[1], -up_cap)
assert close(limits(0, 0, 1)[1], 0)
assert close(limits(0, 0, -1)[0], 0)
assert abs(limits(0.01, 0, -1)[0]) < math.radians(1)
assert abs(limits(-0.01, 0, -1)[0]) < math.radians(1)

for x in (-1, -.25, 0, .25, 1):
    for y in (-1, -.25, 0, .25, 1):
        for z in (-1, -.25, 0, .25, 1):
            yaw, pitch = limits(x, y, z)
            assert -yaw_cap <= yaw <= yaw_cap
            assert -up_cap <= pitch <= down_cap
print("SERA v208 asymmetric 80/90/1 back-thruster limits passed")

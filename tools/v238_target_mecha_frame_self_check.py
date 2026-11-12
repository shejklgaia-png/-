#!/usr/bin/env python3
"""SERA v238: 5-part target uses mirrored perimeter-mounted mechanical frames."""
from __future__ import annotations

from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
code = (root / "scripts/target_parts.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
ver = re.search(r'^config/name="SERA v(\d+)"$', project, re.MULTILINE)
assert ver and int(ver.group(1)) >= 238
assert (root / "README_v238_ja.md").is_file()

# Mesh builders preserve their own materials and do not alter the original core.
for key in ("func _build_head_frame(", "func _build_leg_frame(",
            '"NeckMount"', '"SensorHousing"', '"SideRailL"', '"SideRailR"',
            '"UpperCrossmember"', '"LowerCrossmember"', '"Visor"',
            '"FracturedHead"', '"SideMount"', '"HipJoint"', '"Outrigger"',
            '"UpperStrut"', '"KneeHinge"', '"LowerStrut"', '"Piston"',
            '"OuterPlate"', '"HeelBrace"', '"Foot"'):
    assert key in code, key
assert "_build_head_frame(pivot, shell, accent, frame, dark)" in code
assert "_build_leg_frame(pivot, side, fore_aft, shell, accent, frame, dark)" in code
assert "var side: float = signf(center.x)" in code
assert "var fore_aft: float = signf(center.z)" in code
assert "render_priority" not in code and "TRANSPARENCY_ALPHA" not in code
assert 'target_box.size = cube.size' in main
assert 'const TARGET_BODY_HALF_DEPTH: float = 1.70' in main
assert 'TARGET_HALF_SIZE * 2.0, TARGET_HALF_SIZE * 2.0, TARGET_BODY_HALF_DEPTH * 2.0' in main
assert 'target_parts = TARGET_PARTS_SCRIPT.new()' in main
assert 'marker.add_child(target_parts)' in main

# Current v239 rectangular layout: X +/-1.23 outside the +/-1.0 side
# walls, four legs near +/-1.27 Z on the elongated body; unchanged HP specs.
expected = {
    "head": ((0., -.44, 1.85), (1.48, .82, .96), (0.,-.03,.37),
             (100.,.20,.10,"change")),
    "leg_fl": ((-1.23,-.53,1.27), (2.24,2.00,1.36), (-.78,-.27,.52),
              (100.,.12,.00,"remain")),
    "leg_fr": ((1.23,-.53,1.27), (2.24,2.00,1.36), (.78,-.27,.52),
              (100.,.12,.00,"remain")),
    "leg_rl": ((-1.23,-.53,-1.27), (2.24,2.00,1.36), (-.78,-.27,-.52),
              (100.,.16,.12,"remain")),
    "leg_rr": ((1.23,-.53,-1.27), (2.24,2.00,1.36), (.78,-.27,-.52),
              (100.,.16,.12,"remain")),
}
def floats(xs: str) -> tuple[float, float, float]:
    v = tuple(float(x.strip()) for x in xs.split(","))
    assert len(v) == 3
    return v

pattern = re.compile(
    r'_add_part\("(head|leg_(?:fl|fr|rl|rr))", "[^"]+",'
    r' Vector3\(([^)]+)\),\s*Vector3\(([^)]+)\),'
    r' Vector3\(([^)]+)\),\s*([\d.]+), ([\d.]+),'
    r' ([\d.]+), "(\w+)", Color\("([a-f\d]+)"\)\)')
matches = pattern.findall(code)
assert len(matches) == 5, matches
for id, location, dimensions, aim, hp, defense, break_def, mode, color in matches:
    loc, dim, lock, stats = expected[id]
    for actual, want in zip(floats(location), loc):
        assert math.isclose(actual, want, abs_tol=1e-8)
    for actual, want in zip(floats(dimensions), dim):
        assert math.isclose(actual, want, abs_tol=1e-8)
    for actual, want in zip(floats(aim), lock):
        assert math.isclose(actual, want, abs_tol=1e-8)
    assert (float(hp),float(defense),float(break_def),mode) == stats
    assert color

for left,right in (("leg_fl","leg_fr"), ("leg_rl","leg_rr")):
    l, r = expected[left], expected[right]
    assert math.isclose(l[0][0], -r[0][0])
    assert l[0][1:] == r[0][1:]
    assert l[1] == r[1] and l[3] == r[3]
    assert l[2][0] == -r[2][0] and l[2][1:] == r[2][1:]
for front,rear in (("leg_fl","leg_rl"), ("leg_fr","leg_rr")):
    assert math.isclose(expected[front][0][2], -expected[rear][0][2])

# The legs are side-mounted and each AABB encloses the mirrored geometry.
# Check AABB bounds for support, exterior foot, hip and toe. At rest the
# sole is grounded on the training grid (target center Y=1.53).
target_base_height = 1.53
side = 1.
pivot = expected["leg_fr"][0]
half = tuple(v/2 for v in expected["leg_fr"][1])
parts = [
    (-.24, .83, 0., .90,.34,.78),  # side mount
    (-.02, .76, 0., .64,.48,.62),  # hip
    (.22, .63, 0., .95,.34,.52),  # arm outrigger
    (.42, .59, 0., .78,.54,.74),  # shoulder
    (.45, .30, 0., .46,1.02,.46), # upper
    (.49,-.24, 0., .60,.44,.55),  # knee
    (.50,-.55, 0., .38,.74,.38),  # lower
    (.48,-.52,.20,.16,.66,.15),  # piston
    (.73,-.02, 0., .25,1.08,.60), # outer plate
    (.70,-.48,.12,.44,.70,.52),  # forearm
    (.72,-.35,.42,.48,.82,.45),  # arm tip
    (.50,-.81,-.14,.48,.22,.48), # heel
    (.58,-.91,.18,.84,.18,.84),  # broad foot
]
for x,y,z,sx,sy,sz in parts:
    assert abs(x)+sx/2 <= half[0]+1e-8
    assert abs(y)+sy/2 <= half[1]+1e-8
    assert abs(z)+sz/2 <= half[2]+1e-8
assert pivot[0] - .24 - .90/2 < 1.0   # enlarged mount overlaps core
assert pivot[0] + .58 + .84/2 > 2.0  # outer foot is noticeably wider
foot_bottom = target_base_height + pivot[1] - .91 - .18/2
assert math.isclose(foot_bottom, 0.0, abs_tol=1e-8)

# The low front head protrudes beyond the long rectangular body and is mounted to its face.
head = expected["head"]
assert head[0][2] - head[1][2]/2 < 1.70
assert head[0][2] + head[1][2]/2 > 1.70
assert math.isclose(target_base_height + head[0][1], 1.09)
assert math.isclose(head[0][0],0.0)
# Reticle targets must remain inside their respective outer body bounds.
for loc, dim, aim, stats in expected.values():
    assert all(abs(a) <= d/2+1e-8 for a,d in zip(aim,dim))

# Break/removal and aiming are unchanged from v237.
for term in ('pivot.visible = true', 'fracture.visible = true',
             'part["rest_shell"] = Color("4c555d")',
             'func reset_parts() -> void:', 'func select_front_part(',
             'func get_visible_part_ids(',
             'func apply_part_hit('):
    assert term in code, term

print("PASS v238-v240: mirrored broad side-mounted frame and front-mounted low head")
print("PASS v238: five geometry AABBs, core overlap, feet at ground, lock offsets")
print("PASS v238: v237 part durability, appearance change and selection preserved")
print("Godot/Android 3D rendering and real collision not verified")

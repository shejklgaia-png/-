#!/usr/bin/env python3
"""SERA v240: enlarged box-only arm/leg frames; bounds, lock and silhouette."""
from __future__ import annotations
from pathlib import Path
import ast
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
parts=read("scripts/target_parts.gd")
main=read("scripts/main.gd")
project=read("project.godot")
assert 'config/name="SERA v240"' in project
assert (ROOT/"README_v240_ja.md").exists()
assert "const TARGET_BODY_HALF_DEPTH: float = 1.70" in main
assert "const TARGET_FRAME_HALF_WIDTH: float = 2.35" in main
assert "const TARGET_FRAME_HALF_HEIGHT: float = 1.53" in main
assert "const TARGET_FRAME_HALF_DEPTH: float = 2.35" in main

# Parse ONLY simple numeric expressions in the 3D frame builder; no eval.
def number(expr: str, side: int, fore_aft: int) -> float:
    def go(node):
        if isinstance(node, ast.Expression): return go(node.body)
        if isinstance(node, ast.Constant) and type(node.value) in (float,int): return float(node.value)
        if isinstance(node, ast.Name) and node.id in ("side","fore_aft"):
            return float({"side":side,"fore_aft":fore_aft}[node.id])
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub): return -go(node.operand)
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Mult): return go(node.left)*go(node.right)
        raise AssertionError(f"unsupported dimension expression: {expr}")
    return go(ast.parse(expr.strip(),mode="eval"))

builder=parts.split("func _build_leg_frame(",1)[1].split("func _add_part(",1)[0]
pat=re.compile(r'_make_box\(pivot, "([^"]+)", Vector3\(([^)]+)\),\s*Vector3\(([^)]+)\),\s*\w+\)')
matches=pat.findall(builder)
names=[m[0] for m in matches]
assert len(matches)==13, names
assert len(set(names))==len(names)
for n in ("SideMount","HipJoint","Outrigger","ShoulderArmor","UpperStrut",
          "KneeHinge","LowerStrut","Piston","OuterPlate","ForearmGuard",
          "ArmTip","HeelBrace","Foot"):
    assert n in names,n
assert 'var fore_aft: float = signf(center.z)' in parts
assert '_build_leg_frame(pivot, side, fore_aft, shell, accent, frame, dark)' in parts
assert "BoxMesh.new()" in parts
assert not any(k in parts for k in ("SphereMesh","CylinderMesh","CapsuleMesh","render_priority"))

old_width,old_depth=1.38,1.02
expected_size=(2.24,2.00,1.36)
assert expected_size[0]>old_width*1.6 and expected_size[2]>old_depth*1.3
for side in (-1,1):
    for fore in (-1,1):
        located={}
        extremes=[[float("inf"),-float("inf")] for i in range(3)]
        for name,center_text,size_text in matches:
            pos=tuple(number(v,side,fore) for v in center_text.split(","))
            size=tuple(number(v,side,fore) for v in size_text.split(","))
            assert all(d>0 for d in size)
            located[name]=(pos,size)
            for a in range(3):
                lower=pos[a]-size[a]/2
                upper=pos[a]+size[a]/2
                extremes[a][0]=min(extremes[a][0],lower)
                extremes[a][1]=max(extremes[a][1],upper)
                assert lower >= -expected_size[a]/2-1e-7,(name,a,lower)
                assert upper <= expected_size[a]/2+1e-7,(name,a,upper)
        assert math.isclose(extremes[1][0],-1.0)
        assert math.isclose(extremes[1][1], 1.0)
        # Wider shoulder and arm tip really exist as tangible rectangular surfaces.
        assert located["ShoulderArmor"][1][0]>=.78
        assert located["ArmTip"][1][1]>=.80
        assert located["Foot"][1][0]>=.84
        # Camera half-width encompasses each mirrored part including feet.
        farthest_x=1.23+max(abs(extremes[0][0]),abs(extremes[0][1]))
        assert farthest_x < 2.35
        assert 1.23-.24-.90/2 < 1.0 # core-frame connection overlaps
        foot_position,foot_size=located["Foot"]
        assert math.isclose(1.53-.53+foot_position[1]-foot_size[1]/2,0.0,abs_tol=1e-8)
        # The auto-lock offset sits *on* the protruding armored ArmTip box.
        aim=(side*.78,-.27,fore*.52)
        tip,tip_size=located["ArmTip"]
        assert all(abs(aim[a]-tip[a])<=tip_size[a]/2+1e-8 for a in range(3))

# All 5 HP containers are present, with two mirrored pairs of enlarged limbs.
for id,x,z,aim_x,aim_z in (
    ("leg_fl",-1.23,1.27,-.78,.52),("leg_fr",1.23,1.27,.78,.52),
    ("leg_rl",-1.23,-1.27,-.78,-.52),("leg_rr",1.23,-1.27,.78,-.52)):
    match=re.search(rf'_add_part\("{id}", "[^"]+", Vector3\(([^)]+)\),\s*Vector3\(([^)]+)\), Vector3\(([^)]+)\),',parts)
    assert match,id
    center,size,lock=(tuple(float(v.strip()) for v in s.split(",")) for s in match.groups())
    assert center == (x,-.53,z)
    assert size == expected_size
    assert lock == (aim_x,-.27,aim_z)
assert parts.count("    _add_part(")==5
assert "func apply_part_hit(" in parts and "func select_front_part(" in parts
assert 'pivot.visible = false' in parts and 'fracture.visible = true' in parts
assert 'const CORE_HP_SHARE: float = 0.50' in parts
assert 'const EACH_PART_HP_SHARE: float = 0.10' in parts
print("PASS v240: 13 rectangular meshes per four mirrored limbs, thicker shoulders/feet")
print("PASS v240: actual model fully inside widened part hit AABBs, 2m height, grounded")
print("PASS v240: arm-tip lock points, 2.35m camera width, unchanged 5-part durability")
print("Godot runtime and Android melee/render not exercised")

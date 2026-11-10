#!/usr/bin/env python3
"""SERA v226: centralized, extensible transparent-rendering contract checks.

Runs without Godot. With BASE_SHA/HEAD_SHA checks new spatial shader contracts.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")

policy = read("scripts/render_order_policy.gd")
project = read("project.godot")
docs = read("docs/RENDER_PIPELINE_POLICY_ja.md")
agent = read("AGENTS.md")
script_agent = read("scripts/AGENTS.md")
model_guide = read("docs/MODEL_PART_WORKFLOW_ja.md")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 226

priorities = {
    name: int(num)
    for name, num in re.findall(
        r"(?m)^const ([A-Z][A-Z0-9_]+): int = (-?\d+)\s*(?:#.*)?$", policy
    )
}
expected = {
    "AFTERIMAGE": -20,
    "SLASH_VOLUME": 100,
    "SLASH_SURFACE": 105,
    "SLASH_PARTICLES": 110,
    "CHARACTER_FOREGROUND": 126,
    "DEPTH_TESTED_EMISSIVE": 127,
}
assert priorities == expected, (priorities, expected)
assert sorted(priorities.values()) == list(priorities.values())
assert min(priorities.values()) >= -128 and max(priorities.values()) <= 127
for name in expected:
    assert name in docs
assert "RENDER_POLICY_ID: SERA_RENDER_CONTRACT_V1" in docs
assert "docs/RENDER_PIPELINE_POLICY_ja.md" in agent
assert "docs/RENDER_PIPELINE_POLICY_ja.md" in script_agent
assert "docs/RENDER_PIPELINE_POLICY_ja.md" in model_guide

# Every explicit 3D priority assignment must use the policy, except the
# established sword-material helper which receives a named priority at ALL
# of its call sites. No unreviewed priority integer or ad-hoc layer variable.
owners = {
    "scripts/sera_rig.gd": ("AFTERIMAGE", "CHARACTER_FOREGROUND"),
    "scripts/sword_trail.gd": ("SLASH_VOLUME", "SLASH_SURFACE", "SLASH_PARTICLES"),
    "scripts/back_thruster_fx.gd": ("DEPTH_TESTED_EMISSIVE",),
}
for file, roles in owners.items():
    source = read(file)
    assert 'const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")' in source
    for role in roles:
        assert f"RENDER_ORDER.{role}" in source, (file, role)

rig = read("scripts/sera_rig.gd")
sword = read("scripts/sword_trail.gd")
fx = read("scripts/back_thruster_fx.gd")
assert "_afterimage_material.render_priority = RENDER_ORDER.AFTERIMAGE" in rig
assert "_foreground_mat.render_priority = RENDER_ORDER.CHARACTER_FOREGROUND" in rig
for role in ("SLASH_VOLUME", "SLASH_SURFACE", "SLASH_PARTICLES"):
    assert f"_make_material(RENDER_ORDER.{role}," in sword
assert "ribbon_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert "material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert "mat.render_priority = priority" in sword

assign = re.compile(r"(?m)^[ \t]*[A-Za-z_][A-Za-z_0-9]*\.render_priority[ \t]*=[ \t]*([^\n#]+)")
all_assignments = 0
for path in sorted((ROOT / "scripts").rglob("*.gd")):
    source = path.read_text(encoding="utf-8")
    for match in assign.finditer(source):
        expr = match.group(1).strip()
        all_assignments += 1
        if expr == "priority":
            assert path.name == "sword_trail.gd", (path, expr)
            continue
        reference = re.fullmatch(r"RENDER_ORDER\.([A-Z][A-Z_0-9]*)", expr)
        assert reference is not None, (path.relative_to(ROOT), expr)
        assert reference.group(1) in priorities, (path, expr)
        assert 'const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")' in source
assert all_assignments >= 6, all_assignments

# Materials and shaders are separate concerns: render_priority cannot
# substitute for opaque depth testing. Check every declared shader contract.
tag = re.compile(r"// RENDER_POLICY: ([A-Z][A-Z_0-9]*); depth_test=(on|off)")
required_shaders = {
    "back_thruster.gdshader": ("DEPTH_TESTED_EMISSIVE", "on"),
    "back_thruster_trail.gdshader": ("DEPTH_TESTED_EMISSIVE", "on"),
    "sera_foreground.gdshader": ("CHARACTER_FOREGROUND", "off"),
}
for path in sorted((ROOT / "shaders").rglob("*.gdshader")):
    source = path.read_text(encoding="utf-8")
    match = tag.search(source)
    if path.name in required_shaders:
        assert match is not None, path
        assert match.groups() == required_shaders[path.name], path
    if match is None:
        continue  # Older unmodified shaders may not have opted in yet.
    role, depth = match.groups()
    assert role in priorities, path
    assert "shader_type spatial;" in source, path
    assert ("depth_test_disabled" in source) == (depth == "off"), path
    assert "render_mode" in source, path

# New spatial alpha/blended shaders must declare their depth contract, even
# if the author forgot to set any priority. This catches future omissions
# rather than checking only the current thruster materials.
base, head = os.environ.get("BASE_SHA"), os.environ.get("HEAD_SHA")
if base and head:
    diff = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=A", base, head, "--", "shaders"],
        cwd=ROOT, text=True, check=True, capture_output=True,
    )
    for rel_path in filter(None, diff.stdout.splitlines()):
        path = ROOT / rel_path
        if path.suffix != ".gdshader" or not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        if "shader_type spatial;" not in source:
            continue
        if ("ALPHA =" in source or "blend_add" in source or
                "depth_test_disabled" in source):
            assert tag.search(source), (
                f"{rel_path}: new transparent shader lacks RENDER_POLICY contract"
            )

print("PASS v226: six transparent layer roles centrally defined and ordered")
print(f"PASS: {all_assignments} runtime priority assignments use the contract")
print("PASS: declared shader depth contracts and new transparent shader guard")
print("Godot parsing, Android depth/sorting, and actual motion visibility remain unverified")

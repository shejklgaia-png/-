#!/usr/bin/env python3
"""Version-neutral repository checks; not a substitute for Godot/Android runtime."""
from __future__ import annotations

import base64
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
checks = 0


def verify(name: str, condition: bool) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(name)
        print(f"FAIL: {name}")


verify("project.godot is at Git repository root", (ROOT / "project.godot").is_file())
verify("main scene exists", (ROOT / "scenes/main.tscn").is_file())
verify("main script exists", (ROOT / "scripts/main.gd").is_file())
verify("Sera rig script exists", (ROOT / "scripts/sera_rig.gd").is_file())
verify("Godot source model exists", (ROOT / "assets/sera_source.json").is_file())
verify("embedded model script exists", (ROOT / "assets/sera_data.gd").is_file())
verify("Codex AGENTS instructions exist", (ROOT / "AGENTS.md").is_file())
verify("Git cache exclusions exist", (ROOT / ".gitignore").is_file())

project = (ROOT / "project.godot").read_text(encoding="utf-8")
verify("startup scene path configured", 'run/main_scene="res://scenes/launch_menu.tscn"' in project)
verify("startup scene exists", (ROOT / "scenes/launch_menu.tscn").is_file())
verify("startup script exists", (ROOT / "scripts/launch_menu.gd").is_file())
verify("command nexus scene exists", (ROOT / "scenes/command_nexus.tscn").is_file())
verify("command nexus script exists", (ROOT / "scripts/command_nexus.gd").is_file())

src = (ROOT / "assets/sera_source.json").read_bytes()
try:
    model = json.loads(src)
except (ValueError, UnicodeDecodeError) as exc:
    print(f"FAIL: invalid Sera JSON: {exc}")
    sys.exit(1)
# New equipment pivots and meshes may be appended without replacing A's 22 bones.
# The v276 asset regression separately verifies exact Katana additions.
verify("model retains 22 A bones", len([
    g for g in model.get("groups", []) if not g.get("name", "").startswith("Katana")
]) == 22)
verify("model retains base 25 meshes", len(model.get("elements", [])) >= 25)
anims = {a.get("name") for a in model.get("animations", [])}
for clip in ("Wait_motion", "run_front_original", "Step_R", "Step_L", "Backstep", "Guard", "Melee2", "Melee3"):
    verify(f"required animation exists: {clip}", clip in anims)
verify("Guard has exactly one clip", sum(a.get("name") == "Guard" for a in model.get("animations", [])) == 1)

embedded = (ROOT / "assets/sera_data.gd").read_text(encoding="utf-8")
parts = re.findall(r'^\s+"([A-Za-z0-9+/=]+)",?$', embedded, re.MULTILINE)
try:
    decoded = base64.b64decode("".join(parts), validate=True) if parts else b""
except ValueError:
    decoded = b""
verify("embedded Godot model equals source JSON bytes", bool(parts) and decoded == src)

# Only inspect explicit resource strings, not dynamic paths produced by runtime code.
references: set[tuple[str, str]] = set()
for ext in ("*.gd", "*.tscn", "*.tres", "*.gdshader", "*.godot"):
    for file in ROOT.rglob(ext):
        if ".godot" in file.parts:
            continue
        data = file.read_text(encoding="utf-8")
        for path in re.findall(r"[\"'](res://[^\"'\r\n]+)[\"']", data):
            if any(s in path for s in ("%", "{", "}", "$")):
                continue  # constructed at runtime
            references.add((str(file.relative_to(ROOT)), path))
for owner, uri in sorted(references):
    target = ROOT / uri[len("res://"):]
    verify(f"resource path exists: {owner} -> {uri}", target.is_file())

print(f"Repository static checks: {checks - len(failures)}/{checks} passed; {len(references)} explicit resource paths inspected")
if failures:
    print("Note: checks are static only, and cannot validate engine parsing or Android gameplay.")
    raise SystemExit(1)
print("Godot/Android runtime NOT tested by this script.")

#!/usr/bin/env python3
"""v103 regression check: training-target body is red before and after hit flash."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")

checks = {
    "target base albedo red": 'cube_mat.albedo_color = Color("e53935")' in main,
    "target restored to red after hit flash": (
        'target_material.albedo_color = Color("e53935").lerp(Color("632535"), ratio * 0.78)' in main
    ),
    "target base red emission": 'cube_mat.emission = Color("a92724")' in main,
    "target restored red emission": (
        'target_material.emission = Color("a92724").lerp(Color("6b1727"), ratio)' in main
    ),
    "old cyan tones absent": all(s not in main for s in ('39bdd1', '23879a')),
    "v103 project display name": 'config/name="SERA v103 | Red target"' in project,
}
for label, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {label}")
if not all(checks.values()):
    raise SystemExit(1)
print(f"v103 target-red static check: {sum(checks.values())}/{len(checks)} passed")

#!/usr/bin/env python3
"""Dependency-free checks for the SERA code locator (does not touch runtime)."""
from pathlib import Path

from sera_code_map import ROOT, extract_symbols, find_symbols, version_from_text

sample = """# func ignored():
func _ready() -> void:
    pass
static func compute_delta(x: float) -> float:
    return x
const RUN_RADIUS: float = 70.0
# const INVALID = 0
"""
names = extract_symbols(sample)
assert [(x["name"], x["line"]) for x in names] == [
    ("_ready", 2), ("compute_delta", 4)
]
all_symbols = extract_symbols(sample, include_constants=True)
assert [(x["kind"], x["name"], x["line"]) for x in all_symbols] == [
    ("function", "_ready", 2),
    ("function", "compute_delta", 4),
    ("constant", "RUN_RADIUS", 6),
]
assert version_from_text('config/name="SERA v244"\n') == 244
try:
    version_from_text('config/name="something else"')
except ValueError:
    pass
else:
    raise AssertionError("Invalid project name must be rejected")
assert (ROOT / "project.godot").is_file()
assert version_from_text((ROOT / "project.godot").read_text(encoding="utf-8")) >= 1
hits = find_symbols("camera")
assert any(item["path"] == "scripts/main.gd" for item in hits), hits
assert any(item["name"].startswith("_camera") or "camera" in item["name"]
           for item in hits)
assert all(item["kind"] == "function" for item in hits)
assert any(item["name"] == "DRAG_RADIUS"
           for item in find_symbols("DRAG_RADIUS", include_constants=True))
print("PASS: SERA symbol index parser, version parser, live source search")

#!/usr/bin/env python3
from sera_function_index import ROOT, ranges_for_source, build_index
sample = "extends Node\nfunc first() -> void:\n    second()\nfunc second() -> void:\n    pass\n"
assert ranges_for_source(sample) == [
    {"name": "first", "start_line": 2, "end_line": 3},
    {"name": "second", "start_line": 4, "end_line": 5}]
report = build_index("camera", "scripts/main.gd")
assert report["game_version"] >= 316
assert any(x["name"] == "_stable_shoulder_camera_yaw" for x in report["results"])
assert all(x["end_line"] >= x["start_line"] > 0 for x in report["results"])
camera = (ROOT / "scripts/sera_camera_math.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
for name in ("desired_follow_focus", "advance_follow_focus", "stable_shoulder_yaw"):
    assert f"static func {name}(" in camera
    assert f"CAMERA_MATH.{name}(" in main
assert 'const CAMERA_MATH = preload("res://scripts/sera_camera_math.gd")' in main
print("SERA_FUNCTION_INDEX_AND_CAMERA_MATH_PASS")

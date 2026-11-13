#!/usr/bin/env python3
"""Main input/movement split preserves method contracts and no shared mutable state."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
m = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
i = (ROOT / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
v = (ROOT / "scripts/sera_movement_math.gd").read_text(encoding="utf-8")
for token in (
    'const INPUT_GESTURES = preload("res://scripts/sera_input_gestures.gd")',
    'const MOVEMENT_MATH = preload("res://scripts/sera_movement_math.gd")',
    "func _analog_stick_direction(pos: Vector2) -> Vector2:",
    "func _classify_side_flick(displacement: Vector2, seconds: float) -> int:",
    "func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:",
    "func _classify_combo_kick_flick(displacement: Vector2, seconds: float) -> Vector2:",
    "func _combo_kick_side_for_flick(flick: Vector2) -> int:",
    "func _screen_drag_to_ground(screen_drag: Vector2) -> Vector3:",
    "func _step_local_pose_direction(world_direction: Vector3) -> Vector2:",
    "func _is_upward_jump_flick(displacement: Vector2, seconds: float) -> bool:",
):
    assert token in m, token
for n in ("analog_stick_direction", "side_flick", "step_flick",
          "combo_kick_flick", "combo_kick_side", "upward_jump_flick", "controller_contains"):
    assert f"static func {n}(" in i
    assert f"INPUT_GESTURES.{n}(" in m
for n in ("screen_drag_to_ground", "step_local_pose_direction"):
    assert f"static func {n}(" in v
    assert f"MOVEMENT_MATH.{n}(" in m
for text in (i, v):
    assert "extends RefCounted" in text
    assert "get_tree()" not in text and "get_viewport()" not in text
    assert "user://" not in text and "FileAccess" not in text
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in i
assert "var has_lock: bool = (target_hp > 0" in m
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in m
assert "return STEP_SIDE_DISTANCE" in m
print("SERA_V317_SPLIT_INPUT_STATIC_PASS")

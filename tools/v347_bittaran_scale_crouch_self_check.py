#!/usr/bin/env python3
"""Bittaran v347: 2x uniformly scaled combat target and crouched, correctly scaled IK."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text(encoding="utf-8")
battle = read("scripts/bittaran_battle.gd")
ik = read("scripts/bittaran_foot_ik.gd")
ai = read("scripts/bittaran_ai.gd")
assert 'const BOSS_WORLD_SCALE: float = 2.0' in battle
assert 'target.scale = Vector3.ONE * BOSS_WORLD_SCALE' in battle
assert 'const BODY_CROUCH_WORLD_METERS: float = 0.34' in ik
assert 'const STANCE_TUCK_METERS: float = 0.42' in ik
assert 'const STEP_TRIGGER_METERS: float = 0.76' in ik
assert 'const STEP_DURATION_SECONDS: float = 0.58' in ik
assert 'const STEP_HEIGHT_METERS: float = 0.34' in ik
assert 'const STEP_FORWARD_LEAD_METERS: float = 0.364' in ik
assert 'const STEP_APPROACH_TRIGGER_METERS: float = 0.988' in ik
assert 'var foot_world_scale: Vector3 = foot.global_basis.get_scale()' in ik
assert 'Basis(desired_rotation).scaled(foot_world_scale)' in ik
assert '.scaled(original_scale)' in ik
assert 'const STOP_DISTANCE_METERS: float = 7.8' in ai
assert 'const RESUME_DISTANCE_METERS: float = 8.6' in ai
print("PASS v347 2x combat target, crouch, tucked knees, scale-safe foot IK")

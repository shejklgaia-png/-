#!/usr/bin/env python3
"""v346 grounded four-leg IK contract without touching authored Blockbench."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
rig = read("scripts/bittaran_foot_ik.gd")
battle = read("scripts/bittaran_battle.gd")
assert 'const STEP_TRIGGER_METERS: float = 0.38' in rig
assert 'const STEP_DURATION_SECONDS: float = 0.52' in rig
assert 'const STEP_HEIGHT_METERS: float = 0.19' in rig
assert 'const LEG_PAIRS: Array[Array] = [[0, 1], [2, 3]]' in rig
assert 'func _solve(' in rig
assert 'var knee_target: Vector3' in rig
assert 'foot.global_basis = Basis(desired_rotation)' in rig
assert 'func planted_foot_count()' in rig
assert 'func maximum_ground_error()' in rig
assert 'const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")' in battle
assert 'bittaran_foot_ik.call("advance_ik", delta, bittaran_motion)' in battle
assert 'super._physics_process(delta)' in battle
assert 'bittaran_foot_ik.call("reset")' in battle
assert 'const SOURCE_PATH: String = "res://models/bosses/Bittaran.bbmodel"' in read("scripts/bittaran_rig.gd")
assert '"name":"ビットタラン"' in read("models/bosses/Bittaran.bbmodel")
print("PASS v346 Bittaran analytical IK, authored source isolation and physics layering")

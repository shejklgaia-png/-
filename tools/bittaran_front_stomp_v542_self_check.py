#!/usr/bin/env python3
"""SERA v542 front-only STOMP enlargement: source and invariant contract."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
attacks = (root / "scripts/bittaran_attacks.gd").read_text(encoding="utf-8")
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for key, value in {
    "STOMP_RANGE_METERS": "3.00",  # retained rear behavior
    "FRONT_STOMP_RANGE_METERS": "3.70",
    "KICK_MIN_RANGE_METERS": "3.10",
    "KICK_RANGE_METERS": "6.30",
    "KICK_HALF_ANGLE_DEGREES": "60.0",
    "SWEEP_RANGE_METERS": "7.10",
}.items():
    assert re.search(
        rf"^const {key}: float = {re.escape(value)}\b",
        attacks, re.M,
    ), f"missing accepted distance {key}"
for key, value in {
    "STOMP_FOLLOW_WIDTH_MULTIPLIER": "1.50",
    "FRONT_STOMP_FOLLOW_WIDTH_MULTIPLIER": "1.80",
}.items():
    assert re.search(
        rf"^const {key}: float = {re.escape(value)}\b",
        battle, re.M,
    ), f"wrong follow volume {key}"
assert 'if attack_kind == "stomp":' in attacks
assert 'if id.begins_with("leg_f")' in attacks
assert "distance <= FRONT_STOMP_RANGE_METERS" in attacks
assert "distance <= STOMP_RANGE_METERS" in attacks
assert "foot_box.get_center() - size * 0.5" in battle
assert "foot_box.size.y, STOMP_FOLLOW_MIN_HEIGHT_METERS" in battle
assert 'leg_id.begins_with("leg_f")' in battle
assert "FRONT_STOMP_FOLLOW_WIDTH_MULTIPLIER" in battle
assert 'if moving and stomp_follow_apex_passed and not stomp_follow_landed:' in battle
assert "bittaran_attacks.set(\"hit_consumed\", true)" in battle
assert 'const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]' in attacks
for item in [
    "py tools/bittaran_front_stomp_v542_self_check.py",
    "gd tools/bittaran_front_stomp_v542_runtime_check.gd",
    "gd tools/bittaran_stomp_follow_runtime_check.gd",
    "gd tools/bittaran_attack_distance_priority_runtime_check.gd",
    "gd tools/bittaran_kick_selection_v541_runtime_check.gd",
]:
    assert item in manifest
print("PASS bittaran_front_stomp_v542_self_check")

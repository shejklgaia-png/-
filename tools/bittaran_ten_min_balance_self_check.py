#!/usr/bin/env python3
"""Independent approved-value contract for the ~10-minute Bittaran encounter."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

balance = source("scripts/bittaran_balance.gd")
parts = source("scripts/bittaran_parts.gd")
battle = source("scripts/bittaran_battle.gd")
main = source("scripts/main.gd")
stats = source("scripts/sera_part_stats.gd")
manifest = source("tools/sera_ci_manifest.txt")
expected = {
    "BOSS_MAX_HP": "2550",
    "FRONT_LEG_INTEGRITY": "720.0",
    "REAR_LEG_INTEGRITY": "620.0",
    "HEAD_INTEGRITY": "150.0",
    "LEG_HP_MULTIPLIER": "0.75",
    "HEAD_HP_MULTIPLIER": "2.50",
    "BODY_HP_MULTIPLIER": "1.0",
    "STOMP_DAMAGE": "30.0",
    "KICK_DAMAGE": "22.0",
    "SWEEP_DAMAGE": "28.0",
    "BELLY_DAMAGE_MULTIPLIER": "0.28",
    "RAILGUN_DAMAGE_MULTIPLIER": "0.45",
}
for constant, value in expected.items():
    assert re.search(r"^const " + constant + r":\s*\w+\s*=\s*" + value + r"\b", balance, re.M), constant
assert 'const BALANCE = preload("res://scripts/bittaran_balance.gd")' in parts
assert 'const BALANCE = preload("res://scripts/bittaran_balance.gd")' in battle
assert 'func _target_health_cap() -> int:' in main
assert "func _target_health_cap() -> int:" in battle
assert "func _body_exposed() -> bool:" in parts
assert 'int(parts.call("broken_leg_count"))' not in battle  # avoid fake local state
assert '"max_hp"' in stats and '"hp": 160.0' in stats
assert '"hp": 40.0' in stats and '"hp": 208.0' in stats
assert "gd tools/bittaran_ten_min_balance_runtime_check.gd" in manifest
assert "py tools/bittaran_ten_min_balance_self_check.py" in manifest
print("BITTARAN_10MIN_BALANCE_STATIC_PASS: approved encounter, source wiring and registered runtime")

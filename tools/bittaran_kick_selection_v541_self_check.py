#!/usr/bin/env python3
"""Independent SERA v541 Bittaran KICK selection-only contract."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "scripts/bittaran_attacks.gd").read_text(encoding="utf-8")
tests = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
expected = {
    "STOMP_RANGE_METERS": "3.00",
    "KICK_MIN_RANGE_METERS": "3.10",
    "KICK_RANGE_METERS": "6.30",
    "KICK_HALF_ANGLE_DEGREES": "60.0",
    "SWEEP_MIN_RANGE_METERS": "2.70",
    "SWEEP_RANGE_METERS": "7.10",
    "SWEEP_HALF_ANGLE_DEGREES": "115.0",
    "REAR_SWEEP_HALF_ANGLE_DEGREES": "165.0",
    "KICK_EXTENSION_START_KEY_SECONDS": "0.25",
    "KICK_EXTENSION_END_KEY_SECONDS": "0.75",
    "SOURCE_HIT_DELAY_SECONDS": "0.10",
}
for key, value in expected.items():
    assert re.search(
        rf'^const\s+{key}:\s*float\s*=\s*{re.escape(value)}\b',
        source, re.MULTILINE
    ), f"incorrect independent expected value: {key}={value}"
assert 'const ATTACK_KINDS: Array[String] = ["stomp", "kick", "sweep"]' in source
assert 'id.begins_with("leg_f")' in source
assert 'player_position.x - foot_position.x' in source
assert 'player_position.z - foot_position.z' in source
assert 'angle_degrees <= KICK_HALF_ANGLE_DEGREES' in source
assert 'distance >= KICK_MIN_RANGE_METERS' in source
assert 'distance <= KICK_RANGE_METERS' in source
assert 'if candidate != last_kind:' in source  # preserve attack alternation
for test in (
    "py tools/bittaran_kick_selection_v541_self_check.py",
    "gd tools/bittaran_kick_selection_v541_runtime_check.gd",
    "gd tools/bittaran_attack_distance_priority_runtime_check.gd",
    "gd tools/bittaran_keyframe_hit_sector_runtime_check.gd",
):
    assert test in tests, f"CI registration missing: {test}"
print("PASS bittaran_kick_selection_v541_self_check: expanded front kick, preserved hit and alternation contracts")

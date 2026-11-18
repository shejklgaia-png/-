#!/usr/bin/env python3
"""v456: the 4-sweep VFX curves must match the shipped Blockbench model."""
from pathlib import Path
import hashlib
import json
import math
import re

root = Path(__file__).resolve().parents[1]
source = (root / "models/bosses/Bittaran.bbmodel").read_bytes()
actual_git_blob_sha = hashlib.sha1(
    f"blob {len(source)}\0".encode("ascii") + source).hexdigest()
text = (root / "scripts/bittaran_sweep_fx_baked_data.gd").read_text("utf-8")
claimed_sha = re.search(
    r'const SOURCE_BBMODEL_BLOB_SHA: String = "([0-9a-f]{40})"', text)
assert claimed_sha is not None, "No tracked source BBMODEL revision"
assert claimed_sha.group(1) == actual_git_blob_sha, (
    "Source Bittaran.bbmodel was updated; regenerate real IK FX paths")
match = re.search(
    r'const TRACKS: Dictionary = (\{.*?\})\n\nstatic func', text, re.S)
assert match is not None, "Generated 4-leg FX data missing"
tracks = json.loads(match.group(1))
assert set(tracks) == {"leg_fl", "leg_fr", "leg_rl", "leg_rr"}
for leg, rows in tracks.items():
    begin = 0.25 if leg.startswith("leg_r") else 0.75
    end = begin + 0.5
    assert len(rows) == 13, (leg, "curve sample count")
    for idx, values in enumerate(rows):
        assert len(values) == 3 and all(math.isfinite(v) for v in values)
        expected = begin + 0.5 * idx / 12
        assert abs(values[0] - expected) < 0.000002, (leg, idx)
        if idx:
            distance = math.dist(values[1:], rows[idx-1][1:])
            assert distance < 1.0, (leg, idx, "implausible toe jump", distance)
    assert math.dist(rows[0][1:], rows[-1][1:]) > 1.0, leg
print("PASS SERA v456 frozen actual source+IK 4-leg sweep FX curves")

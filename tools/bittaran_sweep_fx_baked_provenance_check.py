#!/usr/bin/env python3
"""v456: the 4-sweep VFX curves must match the shipped Blockbench model."""
from pathlib import Path
import hashlib
import json
import math
import re

root = Path(__file__).resolve().parents[1]
# The authored L/R front/rear DOWN clips are appended AFTER all
# previously baked attack/sweep clips. Reconstruct the prior byte-for-byte
# master by removing ONLY those four appended objects. No preexisting mesh,
# keyframe, or attack timing may change without invalidating the frozen FX.
# This does not loosen SWEEP provenance; it ignores only new DOWN clips.
source = (root / "models/bosses/Bittaran.bbmodel").read_text("utf-8")
decoded = json.loads(source)
author_down_names = ["前脚ダウン_L", "前脚ダウン_R",
                     "後足ダウン_L", "後足ダウン_R"]
assert [a["name"] for a in decoded["animations"][-4:]] == author_down_names
marker = '"animations":['
start = source.index(marker) + len(marker)
decoder = json.JSONDecoder()
cursor = start
for i in range(len(decoded["animations"]) - 4):
    _, cursor = decoder.raw_decode(source, cursor)
    if i + 1 < len(decoded["animations"]) - 4:
        assert source[cursor] == ","
        cursor += 1
original_end = cursor
for name in author_down_names:
    assert source[cursor] == ","
    cursor += 1
    clip, cursor = decoder.raw_decode(source, cursor)
    assert clip["name"] == name
assert source[cursor] == "]"
original_source = (source[:original_end] + source[cursor:]).encode("utf-8")
actual_git_blob_sha = hashlib.sha1(
    f"blob {len(original_source)}\0".encode("ascii") + original_source).hexdigest()
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

#!/usr/bin/env python3
"""SERA v275: user-authored back kick must match original and embedded data."""
import base64
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source_bytes = (root / "assets/sera_source.json").read_bytes()
source = json.loads(source_bytes)
author = json.loads((root / "models/storage/SERA_BOOSTER_allテスト (9) (2).bbmodel").read_text(encoding="utf-8"))
clips = [a for a in source["animations"] if a["name"] == "Kick_b"]
assert len(clips) == 1
original = next(a for a in author["animations"] if a["name"] == "Kick_b")
assert clips[0] == original, "authored keys were altered"
ids = {group["uuid"] for group in source["groups"]}
keyed = {uid for uid, a in original["animators"].items() if a.get("keyframes")}
assert len(keyed) == 16 and keyed <= ids, "bone mapping is incomplete"
assert abs(original["length"] - 0.79167) < 0.0001
embedded = (root / "assets/sera_data.gd").read_text(encoding="utf-8")
parts = re.findall(r'^\s+"([A-Za-z0-9+/=]+)",?$', embedded, re.MULTILINE)
assert base64.b64decode("".join(parts), validate=True) == source_bytes
match = re.search(r'^config/name="SERA v(\\d+)"
print("PASS v275: exact authored Kick_b, 16 bones, embedded resource parity")
, (root / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
assert match and int(match.group(1)) >= 275
print("PASS v275: exact authored Kick_b, 16 bones, embedded resource parity")

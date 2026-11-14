#!/usr/bin/env python3
"""Embed the canonical Bittaran Blockbench JSON for Android export."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "models/bosses/Bittaran.bbmodel"
payload = source.read_text(encoding="utf-8")
model = json.loads(payload)
assert model["name"] == "ビットタラン"
assert len(model["groups"]) == 14
target = root / "assets/bittaran_data.gd"
target.parent.mkdir(parents=True, exist_ok=True)
result = (
    "extends RefCounted\n"
    "# Generated fallback for Android from models/bosses/Bittaran.bbmodel.\n"
    "# Update alongside the editable boss source; do not edit this JSON independently.\n"
    "const MODEL_JSON: String = " + json.dumps(payload, ensure_ascii=False) + "\n\n"
    "static func get_json() -> String:\n"
    "    return MODEL_JSON\n"
)
target.write_text(result, encoding="utf-8")
print("BUILT: assets/bittaran_data.gd")

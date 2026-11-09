#!/usr/bin/env python3
"""Rebuild v195 D from latest normalized author, preserving ALL proportions.

Usage (from repo root):
  python3 tools/rebuild_lower_body_d_from_author.py
  python3 tools/rebuild_lower_body_d_data.py
  python3 tools/rebuild_equipment_data.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTHOR = ROOT / "models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel"
READY = ROOT / "models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel"
COMBINED = ROOT / "models/SERA_BOOSTER_allテスト.bbmodel"

# Uniform scale rather than independently squeezing each body part into A's
# per-segment bounding box; this is the previously observed visual regression.
SOURCE_TO_A_SCALE = 0.36
SOURCE_SOLE_Y = 0.2


def serialize(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def transformed(n: float) -> float:
    return round(n * SOURCE_TO_A_SCALE, 8)


def main() -> None:
    source = json.loads(AUTHOR.read_text(encoding="utf-8"))
    ready = json.loads(READY.read_text(encoding="utf-8"))
    combined = json.loads(COMBINED.read_text(encoding="utf-8"))
    by_name = {e["name"]: e for e in source["elements"]}
    target_by_id = {e["uuid"]: e for e in combined["elements"]}
    assert len(by_name) == len(ready["elements"]) == 12

    for part in ready["elements"]:
        name = part["name"]
        assert name.startswith("LegD_"), name
        src = by_name[name.replace("LegD_", "LegC_", 1)]
        assert set(src["vertices"]) == set(part["vertices"]), name
        assert src["faces"] == part["faces"], name
        part["origin"] = [transformed(n - (SOURCE_SOLE_Y if i == 1 else 0.0))
                          for i, n in enumerate(src["origin"])]
        part["vertices"] = {
            uid: [transformed(v) for v in xyz]
            for uid, xyz in src["vertices"].items()
        }
        part["faces"] = src["faces"]
        part["color"] = src["color"]
        part["rotation"] = src.get("rotation", [0, 0, 0])
        target = target_by_id[part["uuid"]]
        target.update(part)

    serialize(READY, ready)
    serialize(COMBINED, combined)
    print("Updated 12 D meshes at uniform scale 0.36 (source sole y=0.2 -> 0)")
    print("A/B, HEAD C, bird C, all animations and group pivots unchanged")


if __name__ == "__main__":
    main()

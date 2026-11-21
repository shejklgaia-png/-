#!/usr/bin/env python3
"""Validate native per-part icon registry, source provenance and PNG headers."""
import hashlib
import json
import re
import struct
from pathlib import Path

try:
    from .read_sera_icon_png import read_png_metadata
except ImportError:
    from read_sera_icon_png import read_png_metadata

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scripts/sera_prototype_catalog.gd"
TARGET = ROOT / "assets/ui/sera_equipment_icons"
PATTERN = re.compile(
    r'^\s*"([A-Z]{1,3}[0-9]{2,3})": \{"name": "([^"]+)", "slot": "([^"]+)",\s*'
    r'"rig_set": "([^"]+)", "source_model": "([^"]+)"', re.M
)
EXPECTED = {
    "head": {"A", "B", "C", "D"}, "torso": {"A", "B"},
    "arms": {"A", "B"}, "legs": {"A", "B", "C", "D"},
    "booster": {"A", "B"}, "weapon_r": {"A", "B", "K"},
    "weapon_l": {"A", "B"},
}


def catalog_entries():
    entries = PATTERN.findall(CATALOG.read_text(encoding="utf-8"))
    found = {}
    for id_, name, slot, rig_set, source in entries:
        if id_ in found:
            raise AssertionError(f"duplicate equipment blueprint {id_}")
        found[id_] = dict(name=name, slot=slot, rig_set=rig_set,
                          source_model=source)
    assert len(found) == 19, f"Expected nineteen real equipment variants, found {len(found)}"
    for slot, variants in EXPECTED.items():
        actual = {e["rig_set"] for e in found.values() if e["slot"] == slot}
        assert actual == variants, (slot, actual, variants)
    assert found["H02"]["name"] == "アイリス"
    for old in ["H01", "H02", "T01", "A01", "L01", "B01", "WR01", "WL01"]:
        assert old in found, f"Existing save blueprint {old} must retain its UID"
    return found


def verify_icons():
    entries = catalog_entries()
    records = {}
    for id_, entry in entries.items():
        source = ROOT / entry["source_model"]
        assert source.is_file(), f"{id_}: canonical model missing: {source}"
        path = TARGET / (id_ + ".png")
        assert path.is_file(), f"{id_}: native snapshot missing"
        data = path.read_bytes()
        assert data.startswith(b"\x89PNG\r\n\x1a\n"), f"{id_}: invalid PNG"
        width, height, depth, color, _, _, _ = struct.unpack_from(">IIBBBBB", data, 16)
        assert (width, height, depth, color) == (512, 512, 8, 6), (
            id_, width, height, depth, color)
        metadata = read_png_metadata(path)
        assert metadata["equipment"] == {
            "blueprint_id": id_, "slot": entry["slot"],
            "rig_set": entry["rig_set"],
        }, f"{id_}: icon equipment provenance mismatch"
        assert metadata["source"]["repository_path"] == entry["source_model"], (
            id_, "wrong model source")
        assert metadata["source"]["fingerprint"] == hashlib.sha256(source.read_bytes()).hexdigest(), (
            id_, "stale source fingerprint")
        assert metadata["render"]["image"]["background"] == "transparent", (
            id_, "background must be applied only by the shared game UI")
        records[id_] = {**entry, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                        "png_sha256": hashlib.sha256(data).hexdigest(),
                        "capture": "SERA native Godot 4.7.2 GL Compatibility"}
    actual = {p.stem for p in TARGET.glob("*.png")}
    assert actual == set(entries), f"Orphan or missing native icon PNGs: {actual ^ set(entries)}"
    (TARGET / "manifest.json").write_text(json.dumps({
        "format": "SERA_NATIVE_EQUIPMENT_ICONS_V1",
        "count": len(records), "width": 512, "height": 512, "transparent": True,
        "items": records,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("SERA_NATIVE_EQUIPMENT_REGISTRY_PASS", len(records))


if __name__ == "__main__":
    verify_icons()

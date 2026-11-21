#!/usr/bin/env python3
"""Add standard cross-chat SERA model provenance to each native PNG capture.

No image synthesis/recompression: tEXt is inserted after IHDR while the
original Godot framebuffer IDAT and its CRC remain byte-for-byte unchanged.
"""
from __future__ import annotations
import hashlib
import json
import struct
import zlib
from pathlib import Path

try:
    from .validate_all_icons import ROOT, TARGET, catalog_entries
    from .read_sera_icon_png import read_png_metadata
except ImportError:
    from validate_all_icons import ROOT, TARGET, catalog_entries
    from read_sera_icon_png import read_png_metadata

# One approved H02 preset supplies the exact camera/scale to all 19 icons.
# Other blueprint IDs retain their own original model and material sources.
PRESET_PATH = ROOT / "assets/ui/sera_icon_presets/H02.json"
SHARED_PRESET = json.loads(PRESET_PATH.read_text(encoding="utf-8"))
PRESET_RENDER = SHARED_PRESET["render"]
PRESET_ANGLES = PRESET_RENDER["model_rotation_deg"]
OBLIQUE_POSE = tuple(float(PRESET_ANGLES[axis]) for axis in ("x", "y", "z"))
CAMERA_AUTO_FIT = float(PRESET_RENDER["auto_fit"])
ANGLES = {slot: OBLIQUE_POSE for slot in (
    "head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l")}
KEY = b"SERA_ICON_MANIFEST_V1"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def annotate_one(id_: str, entry: dict) -> dict:
    path = TARGET / (id_ + ".png")
    source_path = entry["source_model"]
    model_path = ROOT / source_path
    model_bytes = model_path.read_bytes()
    model = json.loads(model_bytes)
    sha = hashlib.sha256(model_bytes).hexdigest()
    angles = OBLIQUE_POSE
    record = {
        "format": "SERA_ICON_PNG_V1",
        "source": {
            "filename": model_path.name,
            "repository_path": source_path,
            "name": model.get("name", model_path.stem),
            "fingerprint": sha,
            "fingerprint_algorithm": "SHA-256",
            "element_count": len(model.get("elements", [])),
        },
        "equipment": {
            "blueprint_id": id_, "slot": entry["slot"],
            "rig_set": entry["rig_set"],
        },
        "render": {
            "engine": PRESET_RENDER["engine"],
            "camera": "orthographic_front",
            "model_rotation_deg": dict(zip(("x", "y", "z"), angles)),
            "auto_fit": CAMERA_AUTO_FIT,
            "model_scale": PRESET_RENDER["model_scale"],
            "pan_clip": PRESET_RENDER["pan_clip"],
            "outline": PRESET_RENDER["outline"],
            "image": PRESET_RENDER["image"],
            "mesh_transform": "Installed SeraRig MeshInstance3D global transforms",
            "texture_source": "Original in-game SeraRig mesh/material",
        },
        "capture_backend": "Godot GL Compatibility native SubViewport",
        "materials": "SeraRig original mesh material_override",
        "outline": "scripts/sera_view_edges.gd + shaders/sera_view_edges.gdshader",
        "lighting": "scripts/main.gd::_build_world",
    }
    # Every captured part uses the exact camera, framing, and outline preset.
    png = path.read_bytes()
    if not png.startswith(PNG_SIGNATURE) or png[12:16] != b"IHDR":
        raise ValueError(f"{id_}: invalid Godot capture PNG")
    w, h, depth, color, _, _, _ = struct.unpack(">IIBBBBB", png[16:29])
    if (w, h, depth, color) != (512, 512, 8, 6):
        raise ValueError(f"{id_}: native screenshot is not RGBA 512")
    payload = KEY + b"\x00" + json.dumps(
        record, ensure_ascii=True, separators=(",", ":")).encode("ascii")
    ihdr_end = 8 + 12 + struct.unpack(">I", png[8:12])[0]
    if png[ihdr_end + 4:ihdr_end + 8] == b"tEXt":
        raise ValueError(f"{id_}: screenshot already carries metadata")
    path.write_bytes(png[:ihdr_end] + _chunk(b"tEXt", payload) + png[ihdr_end:])
    actual = read_png_metadata(path)
    if actual != record:
        raise ValueError(f"{id_}: cross-chat metadata failed roundtrip")
    return record


def annotate_all() -> None:
    records = catalog_entries()
    for id_, entry in records.items():
        annotate_one(id_, entry)
    print("SERA_NATIVE_EQUIPMENT_METADATA_PASS parts=", len(records))


if __name__ == "__main__":
    annotate_all()

#!/usr/bin/env python3
"""Attach standard SERA equipment provenance to actual Godot framebuffer PNG.

Adds a PNG tEXt chunk; pixels, zlib/IDAT bytes and their CRCs stay unchanged.
This is the same metadata contract accepted by another chat's icon importer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY = "SERA_ICON_MANIFEST_V1"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def tag_png(png_path: Path, preset_path: Path) -> None:
    preset = json.loads(preset_path.read_text(encoding="utf-8"))
    source = preset["source"]
    authored = ROOT / source["repository_path"]
    if hashlib.sha256(authored.read_bytes()).hexdigest() != source["fingerprint"]:
        raise ValueError("Native capture preset does not match canonical Blockbench source")
    if preset["equipment"] != {"blueprint_id": "H02", "slot": "head", "rig_set": "D"}:
        raise ValueError("Native capture requires matching H02 HEAD D identity")
    png = png_path.read_bytes()
    if not png.startswith(PNG_SIGNATURE) or png[12:16] != b"IHDR":
        raise ValueError("Not a valid PNG screenshot")
    w, h = struct.unpack(">II", png[16:24])
    if (w, h) != (512, 512):
        raise ValueError("Godot output must be exactly 512x512")

    identity = {
        "format": "SERA_ICON_PNG_V1",
        "source": preset["source"],
        "equipment": preset["equipment"],
        "render": preset["render"],
        "capture_backend": "Godot GL Compatibility native SubViewport",
        "materials": "SeraRig original mesh material_override",
        "outline": "scripts/sera_view_edges.gd + shaders/sera_view_edges.gdshader",
        "lighting": "scripts/main.gd::_build_world",
    }
    payload = (KEY + "\0" + json.dumps(identity, ensure_ascii=True,
                   separators=(",", ":"))).encode("ascii")
    # PNG IHDR must remain the first chunk. Put provenance right after it.
    ihdr_end = 8 + 12 + struct.unpack(">I", png[8:12])[0]
    if png[ihdr_end:ihdr_end+8].endswith(b"tEXt"):
        # No overwrite of already annotated portrait without explicit action.
        raise ValueError("Screenshot already has a tEXt chunk; review before replacing")
    png_path.write_bytes(png[:ihdr_end] + _chunk(b"tEXt", payload) + png[ihdr_end:])
    print("SERA_GODOT_NATIVE_ICON_METADATA_PASS", png_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--png", required=True, type=Path)
    parser.add_argument("--preset", type=Path,
                        default=ROOT / "assets/ui/sera_icon_presets/H02.json")
    args = parser.parse_args()
    tag_png(args.png, args.preset)

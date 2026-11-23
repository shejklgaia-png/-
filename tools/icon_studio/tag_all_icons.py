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
    from .read_sera_icon_png import read_png_metadata
except ImportError:
    from read_sera_icon_png import read_png_metadata

# Production asset registration reads only the live equipment catalog and
# existing icon manifest. It must not depend on CI/test utilities.
ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets/ui/sera_equipment_icons"
MANIFEST_PATH = TARGET / "manifest.json"
CATALOG_PATH = ROOT / "scripts/sera_prototype_catalog.gd"


def catalog_entries() -> dict:
    import re

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    order_match = re.search(r"(?m)^const ORDER = (\[[^\n]+\])", CATALOG_PATH.read_text(encoding="utf-8"))
    if order_match is None:
        raise ValueError("Live equipment catalog order not found")
    order = json.loads(order_match.group(1))
    items = manifest.get("items", {})
    if set(order) != set(items):
        raise ValueError("Native icon manifest and live equipment catalog differ")
    return {blueprint: items[blueprint] for blueprint in order}

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
# Each image is an independent Godot framebuffer capture at the final UI size.
# Widths here must match CAPTURE_PROFILES in sera_all_native_capture.gd.
CAPTURE_PROFILES = {
    "full": {"pixels": 512, "inner": 1.0, "outer": 4.0,
             "convex": 3.0, "seam": 2.0},
    "warehouse": {"pixels": 82, "inner": 1.0, "outer": 1.25,
                  "convex": 0.75, "seam": 0.75},
    "craft": {"pixels": 96, "inner": 1.0, "outer": 1.5,
              "convex": 1.0, "seam": 1.0},
}


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def annotate_one(id_: str, entry: dict, profile_name: str = "full") -> dict:
    profile = CAPTURE_PROFILES[profile_name]
    pixels = int(profile["pixels"])
    path = (TARGET / (id_ + ".png") if profile_name == "full"
            else TARGET / profile_name / (id_ + ".png"))
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
            "profile": profile_name,
            "engine": PRESET_RENDER["engine"],
            "camera": "orthographic_front",
            "model_rotation_deg": dict(zip(("x", "y", "z"), angles)),
            "auto_fit": CAMERA_AUTO_FIT,
            "model_scale": PRESET_RENDER["model_scale"],
            "pan_clip": PRESET_RENDER["pan_clip"],
            # Camera rotation remains the approved H02 preset; the offline
            # ink widths are a dedicated override for the generated PNGs.
            "outline": {
                "enabled": True,
                "color": "#17212F",
                "silhouette_inner_px": profile["inner"],
                "silhouette_outer_px": profile["outer"],
                "convex_px": profile["convex"],
                "mesh_contact_px": profile["seam"],
                "crease_degrees": 80,
                "rendered_at_px": pixels,
            },
            "image": {**PRESET_RENDER["image"], "width": pixels,
                      "height": pixels},
            "mesh_transform": "Installed SeraRig MeshInstance3D global transforms",
            "texture_source": "Original in-game SeraRig mesh/material",
            "pixel_reconstruction": {
                "supersample": 4,
                "id_reduce": "3x3 visible mesh ID vote",
                "contours": "integer pixel silhouette/contact at final resolution",
                "alpha": "binary, transparent outside",
            },
        },
        "capture_backend": "Godot GL Compatibility native SubViewport",
        "materials": "SeraRig original mesh material_override",
        "outline": "NEXUS RGB ID + shaders/sera_icon_capture_visible_id_ink.gdshader + scripts/sera_base_facility_crease_geometry.gd + shaders/sera_icon_capture_convex_ink.gdshader",
        "lighting": "scripts/main.gd::_build_world",
    }
    # Every captured part uses the exact camera, framing, and outline preset.
    png = path.read_bytes()
    if not png.startswith(PNG_SIGNATURE) or png[12:16] != b"IHDR":
        raise ValueError(f"{id_}: invalid Godot capture PNG")
    w, h, depth, color, _, _, _ = struct.unpack(">IIBBBBB", png[16:29])
    if (w, h, depth, color) != (pixels, pixels, 8, 6):
        raise ValueError(
            f"{id_}/{profile_name}: native screenshot is not RGBA {pixels}")
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
    # Run only after the actual Godot native batch capture has generated the
    # transparent PNG files. Refresh hashes from those files, never from mocks.
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    records = catalog_entries()
    for id_, entry in records.items():
        provenance = annotate_one(id_, entry)
        manifest["items"][id_]["source_sha256"] = provenance["source"]["fingerprint"]
        manifest["items"][id_]["png_sha256"] = hashlib.sha256(
            (TARGET / (id_ + ".png")).read_bytes()
        ).hexdigest()
        manifest["items"][id_]["capture"] = (
            "SERA Godot GL Compatibility / 4x sampled shading + final-pixel RGB ID and convex reconstruction")
        variants = {}
        for profile_name in ("warehouse", "craft"):
            profile = CAPTURE_PROFILES[profile_name]
            annotate_one(id_, entry, profile_name)
            png_path = TARGET / profile_name / (id_ + ".png")
            variants[profile_name] = {
                "path": "assets/ui/sera_equipment_icons/"
                        + profile_name + "/" + id_ + ".png",
                "size": int(profile["pixels"]),
                "png_sha256": hashlib.sha256(png_path.read_bytes()).hexdigest(),
                "outline": {key: profile[key] for key in (
                    "inner", "outer", "convex", "seam")},
            }
        manifest["items"][id_]["variants"] = variants
    manifest["count"] = len(records)
    manifest["display_profiles"] = {
        key: value for key, value in CAPTURE_PROFILES.items()}
    manifest["capture_preset"] = "assets/ui/sera_icon_presets/H02.json"
    manifest["outline_pipeline"] = (
        "ICON ONLY: silhouette inner 1px outer 4px; convex corners 3px; mesh seams 2px")
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    print("SERA_NATIVE_EQUIPMENT_METADATA_UPDATED parts=", len(records), "images=", len(records) * len(CAPTURE_PROFILES))


if __name__ == "__main__":
    annotate_all()

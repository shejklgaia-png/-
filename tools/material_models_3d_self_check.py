#!/usr/bin/env python3
"""SERA: all 12 real, importable, low-poly PBR glTF resource models."""
import base64
import hashlib
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = (ROOT / "scripts/sera_base_materials.gd").read_text("utf-8")
ICONS = (ROOT / "scripts/sera_item_icons.gd").read_text("utf-8")
EXPECTED = [f"{family}_{tier}" for family in ("scrap", "alloy", "electronics", "organic")
            for tier in ("low", "mid", "high")]
FOLDER = ROOT / "models/materials"
assert FOLDER.is_dir(), "missing material 3D model directory"
actual = sorted(p.stem for p in FOLDER.glob("*.gltf"))
assert actual == sorted(EXPECTED), (actual, EXPECTED)
assert 'const FAMILY_IDS = ["scrap", "alloy", "electronics", "organic"]' in CATALOG
assert 'const TIERS = ["low", "mid", "high"]' in CATALOG
assert "const MATERIAL_INDICES = {" in ICONS
geometry_fingerprints = []
for material_id in EXPECTED:
    assert f'"{material_id}":' in CATALOG
    assert f'"{material_id}":' in ICONS
    doc = json.loads((FOLDER / (material_id + ".gltf")).read_text("utf-8"))
    assert doc["asset"]["version"] == "2.0"
    assert doc["extras"]["material_id"] == material_id
    assert len(doc["materials"]) >= 3, material_id
    assert len(doc["meshes"]) == 1 and len(doc["scenes"]) == 1
    assert doc["scene"] == 0 and doc["scenes"][0]["nodes"]
    assert doc["meshes"][0]["primitives"]
    buffers = doc["buffers"]
    assert len(buffers) == 1
    uri = buffers[0]["uri"]
    assert uri.startswith("data:application/octet-stream;base64,")
    blob = base64.b64decode(uri.split(",", 1)[1], validate=True)
    assert len(blob) == buffers[0]["byteLength"]
    assert len(blob) % 4 == 0
    for view in doc["bufferViews"]:
        assert view["buffer"] == 0
        assert view["byteOffset"] % 4 == 0
        assert view["byteOffset"] + view["byteLength"] <= len(blob)
    triangle_count = 0
    seen = set()
    for prim in doc["meshes"][0]["primitives"]:
        assert prim["mode"] == 4
        assert "POSITION" in prim["attributes"] and "NORMAL" in prim["attributes"]
        assert prim["material"] < len(doc["materials"])
        pos = doc["accessors"][prim["attributes"]["POSITION"]]
        normal = doc["accessors"][prim["attributes"]["NORMAL"]]
        ix = doc["accessors"][prim["indices"]]
        assert pos["type"] == normal["type"] == "VEC3"
        assert pos["componentType"] == normal["componentType"] == 5126
        assert ix["componentType"] == 5123 and ix["type"] == "SCALAR"
        assert pos["count"] == normal["count"] and pos["count"] > 0
        assert ix["count"] % 3 == 0
        assert all(math.isfinite(v) and abs(v) <= 1.6 for v in pos["min"] + pos["max"])
        assert all(lo < hi for lo, hi in zip(pos["min"], pos["max"]))
        assert ix["count"] >= 3
        vi = doc["bufferViews"][ix["bufferView"]]
        ids = struct.unpack_from("<" + "H" * ix["count"], blob, vi["byteOffset"])
        assert max(ids) < pos["count"], material_id
        seen.add(prim["material"])
        triangle_count += ix["count"] // 3
    assert triangle_count >= 80, (material_id, triangle_count)
    assert len(seen) >= 3
    for mat in doc["materials"]:
        pbr = mat["pbrMetallicRoughness"]
        assert 0 <= pbr["metallicFactor"] <= 1
        assert 0.25 <= pbr["roughnessFactor"] <= 1
        assert len(pbr["baseColorFactor"]) == 4
    geometry_fingerprints.append(hashlib.sha256(blob).hexdigest())
assert len(set(geometry_fingerprints)) == len(EXPECTED), "duplicate 3D models"
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text("utf-8")
assert "py tools/material_models_3d_self_check.py" in manifest
assert "gd tools/material_models_3d_runtime_check.gd" in manifest
print("SERA_MATERIAL_MODELS_3D_STATIC_PASS: 12 distinct importable meshes")

#!/usr/bin/env python3
"""Camera-eye HEAD D: source, Android snapshot, topology and selectable rig."""
from __future__ import annotations

import base64
import json
import struct
import zlib
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


SOURCE = "models/storage/カメラアイ頭部.bbmodel"
model = json.loads(read(SOURCE))
manifest = json.loads(read("models/manifest.json"))
assert manifest["parts"]["head_camera_eye"] == SOURCE
assert model["name"] == "カメラアイ頭部"
assert len(model["elements"]) == 6
assert len(model["textures"]) == 1
assert model["textures"][0]["width"] == 16
assert model["textures"][0]["height"] == 16
assert model["textures"][0]["source"].startswith("data:image/png;base64,")

# HEAD D authored light-grey armour is baked into the 16x16 PNG, not tinted
# by a NEXUS-only override. Check every source pixel using stdlib only.
def png_rgba_pixels(data: bytes) -> list[tuple[int, int, int, int]]:
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    offset = 8
    idat = bytearray()
    width = height = None
    while offset < len(data):
        count = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + count]
        offset += count + 12
        if kind == b"IHDR":
            width, height, depth, mode = struct.unpack_from(">IIBB", payload)
            assert (width, height, depth, mode) == (16, 16, 8, 6)
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            break
    stride = 16 * 4
    unpacked = zlib.decompress(idat)
    pixels = []
    prior = bytearray(stride)
    for row_index in range(16):
        pos = row_index * (stride + 1)
        filtering = unpacked[pos]
        scan = bytearray(unpacked[pos + 1:pos + 1 + stride])
        assert filtering in (0, 1, 2, 3, 4)
        for i in range(stride):
            a = scan[i - 4] if i >= 4 else 0
            b = prior[i]
            c = prior[i - 4] if i >= 4 else 0
            if filtering == 1:
                predict = a
            elif filtering == 2:
                predict = b
            elif filtering == 3:
                predict = (a + b) // 2
            elif filtering == 4:
                p = a + b - c
                distances = (abs(p - a), abs(p - b), abs(p - c))
                predict = (a, b, c)[distances.index(min(distances))]
            else:
                predict = 0
            scan[i] = (scan[i] + predict) & 255
        pixels.extend(tuple(scan[i:i + 4]) for i in range(0, stride, 4))
        prior = scan
    return pixels


author_png = base64.b64decode(model["textures"][0]["source"].split(",", 1)[1])
assert Counter(png_rgba_pixels(author_png)) == {
    (184, 190, 196, 255): 146,  # #B8BEC4 light grey armour (was brown)
    (53, 54, 55, 255): 30,     # dark frame, unchanged
    (93, 95, 96, 255): 30,     # medium grey metal, unchanged
    (43, 141, 173, 255): 50,   # cyan lens, unchanged
}


ids = [mesh["uuid"] for mesh in model["elements"]]
assert len(set(ids)) == len(ids)
assert set(model["outliner"]) == set(ids)
for element in model["elements"]:
    assert element["type"] == "mesh"
    assert element["vertices"] and element["faces"]
    for face in element["faces"].values():
        verts = face["vertices"]
        assert 3 <= len(verts) <= 4
        assert len(set(verts)) == len(verts)
        assert face["texture"] == 0
        assert all(v in element["vertices"] and v in face["uv"] for v in verts)

housing = next(e for e in model["elements"] if e["name"] == "beveled_cuboid")
edges = {}
for face in housing["faces"].values():
    vertices = face["vertices"]
    for idx, a in enumerate(vertices):
        b = vertices[(idx + 1) % len(vertices)]
        edges.setdefault(tuple(sorted((a, b))), []).append((a, b))
assert len(housing["faces"]) == 36
assert len(edges) == 70
assert all(len(sides) == 2 and sides[0] == tuple(reversed(sides[1]))
           for sides in edges.values())

packed_lines = [
    json.loads(line.strip()[:-1])
    for line in read("assets/sera_camera_eye_head_data.gd").splitlines()
    if line.startswith('    "') and line.endswith('",')
]
assert packed_lines, "Android embedded camera-eye snapshot missing"
assert "".join(packed_lines) == read(SOURCE), "Embedded and authored source differ"

equipment = read("scripts/sera_equipment.gd")
assert 'const CAMERA_EYE_HEAD_SOURCE: String = "res://' + SOURCE + '"' in equipment
assert 'const CAMERA_EYE_HEAD_EMBEDDED = preload("res://assets/sera_camera_eye_head_data.gd")' in equipment
assert 'func _install_camera_eye_head() -> void:' in equipment
assert '_install_head_c()\n    _install_camera_eye_head()' in equipment
assert 'rig.get_node_or_null("Waist/Torso/Chest/Neck/Head")' in equipment
assert '_add_mesh("D", "head", piece)' in equipment
assert 'piece.material_override = material' in equipment
assert "Marshalls.base64_to_raw(" in equipment
assert '_apply_part_visibility()' in equipment
assert 'for set_id in available.keys():' in equipment

nexus = read("scripts/command_nexus.gd")
assert 'func _default_part_name(slot: String, model: String) -> String:' in nexus
assert 'str(spec.get("name", id))' in nexus
assert 'button.text = _default_part_name(slot, selected_model)' in nexus
assert 'variant_label = "CAMERA EYE"' not in nexus
build = read("tools/sera_model_build.py")
assert '"rebuild_camera_eye_head_data.py": ("assets/sera_camera_eye_head_data.gd",)' in build
manifest_ci = read("tools/sera_ci_manifest.txt")
assert "py tools/camera_eye_head_self_check.py" in manifest_ci
print("PASS: authored camera eye geometry, UVs, atlas, HEAD D and export snapshot")
print("Android/Godot rendering and animation playback remain separate runtime checks")

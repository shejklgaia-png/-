#!/usr/bin/env python3
"""HEAD D アイリス: approved screenshot settings and completed LAB intake."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
model_path = "models/storage/カメラアイ頭部.bbmodel"
model_bytes = (ROOT/model_path).read_bytes()
expected_sha256 = "e79a33f57e7873f313f1a803488202206d36b8785d4d5bf2951bec316ae90bff"
assert hashlib.sha256(model_bytes).hexdigest() == expected_sha256, "Edited model differs from user-confirmed preset"
model = json.loads(model_bytes)
assert len(model["elements"]) == 6
assert model["name"] == "カメラアイ頭部"
preset = json.loads((ROOT/"assets/ui/sera_icon_presets/H02.json").read_text(encoding="utf-8"))
assert preset["format"] == "SERA_ICON_PRESET_V1" and preset["version"] == 1
assert preset["source"]["repository_path"] == model_path
assert preset["source"]["fingerprint"] == expected_sha256
assert preset["equipment"] == {"blueprint_id":"H02","slot":"head","rig_set":"D"}
r = preset["render"]
assert r["engine"] == "SERA Icon Studio WebGL" and r["camera"] == "orthographic_front"
assert r["model_rotation_deg"] == {"x":-17.95108886718749,"y":152.8089099121089,"z":-5}
assert r["model_scale"] == 1.0311868961757298
assert r["pan_clip"] == {"x":-0.10036383734809033,"y":-0.052272971159492435}
assert r["auto_fit"] == 0.82
assert r["outline"] == {"enabled":True,"stroke_px_at_512":3,"crease_degrees":80,"color":"#17212F"}
assert r["image"] == {"width":512,"height":512,"background":"transparent","ui_frame_baked":False}
catalog = (ROOT/"scripts/sera_prototype_catalog.gd").read_text(encoding="utf-8")
assert '"H01", "H02"' in catalog
assert '"H02": {"name": "アイリス", "slot": "head",' in catalog
assert '"rig_set": "D"' in catalog
stats = (ROOT/"scripts/sera_part_stats.gd").read_text(encoding="utf-8")
assert '"D": {"hp": 20.0, "defense": 0.16, "lock_range": 24.0, "tracking": 1.0}' in stats
equipping = (ROOT/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert '_add_mesh("D", "head", piece)' in equipping
save = (ROOT/"scripts/sera_save.gd").read_text(encoding="utf-8")
for needle in ('func craft_prototype(', 'func equip_prototype(', 'Affixes.roll_five()', 'HANGER_LIMIT',
               'updated["equipped_crafted"] = equipped',
               'gear[slot] = rig_set', 'updated["craft_serials"] = serials'):
    assert needle in save, needle
facility = (ROOT/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
for needle in ('for bp in PrototypeCatalog.ORDER:', 'IconAtlas.equipment_icon', 'SeraSave.craft_prototype('):
    assert needle in facility
icon_source = (ROOT/"scripts/sera_item_icons.gd").read_text(encoding="utf-8")
assert 'CustomEquipmentIcons.ICON_PNG_BASE64' in icon_source
# The user sent a camera preset, not exported bitmap bytes. Final PNG import
# must remain explicit; no fake image, no existing blueprint overwritten.
manifest = (ROOT/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'py tools/iris_h02_craft_self_check.py' in manifest
assert 'gd tools/iris_h02_craft_runtime_check.gd' in manifest
# Real model portrait is baked, not a fabricated/empty tile. Verify all PNG
# chunks, Adler32 data and the embedded camera/blueprint identity.
import base64
import re
import struct
import zlib
registry = (ROOT/"assets/ui/sera_custom_equipment_icons.gd").read_text(encoding="utf-8")
icon = re.search(r'"H02"\s*:\s*"([A-Za-z0-9+/=]+)"', registry)
assert icon, "H02 has no approved render in shared game icon registry"
raw = base64.b64decode(icon.group(1), validate=True)
assert raw.startswith(b"\x89PNG\r\n\x1a\n")
offset = 8
palette_count = None
alpha = None
payload = b""
message = None
while offset < len(raw):
    length = struct.unpack(">I", raw[offset:offset+4])[0]
    typ = raw[offset+4:offset+8]
    val = raw[offset+8:offset+8+length]
    got_crc = struct.unpack(">I", raw[offset+8+length:offset+12+length])[0]
    assert zlib.crc32(typ+val)&0xffffffff == got_crc
    offset += 12+length
    if typ == b"IHDR":
        w,h,depth,col,_,_,_ = struct.unpack(">IIBBBBB", val)
        assert (w,h,depth,col)==(512,512,8,3)
    elif typ == b"PLTE":
        palette_count = len(val)//3
    elif typ == b"tRNS":
        alpha = val
    elif typ == b"tEXt" and val.startswith(b"SERA_ICON_MANIFEST_V1\0"):
        message = json.loads(val.split(b"\0",1)[1].decode("ascii"))
    elif typ == b"IDAT":
        payload += val
    elif typ == b"IEND":
        break
assert palette_count and alpha and alpha[0]==0
assert message and message["source"]["fingerprint"] == expected_sha256
assert message["equipment"] == {"blueprint_id":"H02","slot":"head","rig_set":"D"}
assert message["render"] == preset["render"]
scanlines = zlib.decompress(payload)
assert len(scanlines) == 512*513
assert all(scanlines[y*513]==0 for y in range(512))
color_pixels = sum(px != 0 for y in range(512) for px in scanlines[y*513+1:(y+1)*513])
ink_pixels = sum(px == 1 for y in range(512) for px in scanlines[y*513+1:(y+1)*513])
assert 30000 < color_pixels < 180000, color_pixels
assert ink_pixels > 300, ink_pixels
assert all(px < palette_count for px in scanlines)
assert 'static var _custom_equipment_icon_cache: Dictionary = {}' in icon_source
assert 'ImageTexture.create_from_image(bitmap)' in icon_source

print("SERA_IRIS_H02_CRAFT_AND_PRESET_STATIC_PASS")

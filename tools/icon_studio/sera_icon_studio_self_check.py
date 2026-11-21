#!/usr/bin/env python3
"""SERA Icon Studio static/source-integrity checks (zero external packages)."""
from __future__ import annotations
import base64
import hashlib
import json
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from struct import pack
from zlib import crc32

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_sera_icon_studio import build, TEMPLATE  # noqa: E402
from read_sera_icon_png import read_png_metadata, SIGNATURE, KEY  # noqa: E402

assert TEMPLATE.is_file()
template = TEMPLATE.read_text(encoding='utf-8')
for required in ['function loadEmbedded()', 'loadEmbedded().catch', 'async function annotatePng(',
                 'SERA_ICON_MANIFEST_V1', 'id="sera-model-bundle"',
                 'repository_path:activeBundle?.source_path', 'navigator.clipboard?.writeText',
                 'function pngCrc32(', "$('downloadPng').addEventListener"]:
    assert required in template, required

source = ROOT / 'models/storage/カメラアイ頭部.bbmodel'
raw = source.read_bytes()
html = build(source, 'models/storage/カメラアイ頭部.bbmodel', 'head', 'D', 'H02')
header = html.split('id="sera-model-bundle">', 1)[1].split('</script>', 1)[0]
pkg = json.loads(header)
assert pkg['source_path'] == 'models/storage/カメラアイ頭部.bbmodel'
assert pkg['sha256'] == hashlib.sha256(raw).hexdigest()
assert base64.b64decode(pkg['bbmodel_base64']) == raw
assert pkg['slot'] == 'head' and pkg['rig_set'] == 'D'
assert html.count('SERA_MODEL_BUNDLE_V1') >= 1
assert 'fetch(' not in template, 'Original model must work entirely offline'
packaged = ROOT / 'tools/icon_studio/dist/SERA_Icon_Studio_IRIS.html'
assert packaged.read_text(encoding='utf-8') == html, 'Checked-in IRIS HTML is stale; regenerate with build_sera_icon_studio.py'

# Validate the interchange schema without requiring WebGL or headless Chrome.
fixture = {
    'format': 'SERA_ICON_PNG_V1',
    'source': {'repository_path': pkg['source_path'], 'fingerprint': pkg['sha256']},
    'equipment': {'blueprint_id': 'H02', 'slot': 'head', 'rig_set': 'D'},
    'render': {'model_rotation_deg': {'x': -18, 'y': 160, 'z': 0}},
}
message = KEY + b'\x00' + json.dumps(fixture,ensure_ascii=True).encode('ascii')
def chunk(kind: bytes, payload: bytes) -> bytes:
    return pack('>I', len(payload)) + kind + payload + pack('>I', crc32(kind + payload))
mini_png = (SIGNATURE + chunk(b'IHDR', pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
    + chunk(b'tEXt',message) + chunk(b'IEND', b''))
with TemporaryDirectory() as temp:
    path = Path(temp)/'icon.png'
    path.write_bytes(mini_png)
    assert read_png_metadata(path) == fixture
# Godot must use approved PNGs from one cached shared registry; legacy icon
# atlas remains the fallback until a user actually supplies a final PNG.
loader = (ROOT / 'scripts/sera_item_icons.gd').read_text(encoding='utf-8')
registry = (ROOT / 'assets/ui/sera_custom_equipment_icons.gd').read_text(encoding='utf-8')
catalog = (ROOT / 'scripts/sera_prototype_catalog.gd').read_text(encoding='utf-8')
assert 'const CustomEquipmentIcons = preload("res://assets/ui/sera_custom_equipment_icons.gd")' in loader
assert 'static var _custom_equipment_icon_cache: Dictionary = {}' in loader
assert 'ImageTexture.create_from_image(bitmap)' in loader
assert 'return _frame(int(EQUIPMENT_INDICES[blueprint_id]))' in loader
assert 'const ICON_PNG_BASE64 = {}' in registry, 'No final approved portraits yet'
assert '"H02":' not in catalog, 'IRIS creation/catalog registration belongs to next implementation'
assert (ROOT / 'tools/icon_studio/install_sera_equipment_icon.py').is_file()
assert 'py tools/icon_studio/sera_icon_studio_self_check.py' in (ROOT/'tools/sera_ci_manifest.txt').read_text(encoding='utf-8')
print('PASS: SERA Icon Studio original-model embedding + cross-chat PNG metadata contracts')
#!/usr/bin/env python3
"""Register a SERA Icon Studio PNG for the matching Godot equipment blueprint.

Converts an approved PNG into an embedded GDScript base64 atlas override; the
runtime decodes it once per blueprint and reuses one Texture2D. This allows
GitHub text-file updates without uploading binary .png assets.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import re
import struct
from pathlib import Path
from read_sera_icon_png import read_png_metadata

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/ui/sera_custom_equipment_icons.gd'


def pack_icon(png_path: Path, blueprint: str, output: Path = OUT,
              source_path: str = '') -> dict:
    if not re.fullmatch(r'[A-Z]{1,3}[0-9]{2,3}', blueprint):
        raise ValueError('Invalid blueprint ID; expected e.g. H02 or WR02')
    prototype = (ROOT/'scripts/sera_prototype_catalog.gd').read_text(encoding='utf-8')
    record = re.search(r'^\s*"'+re.escape(blueprint)+r'"\s*:\s*\{([^}]*)\}',prototype,re.M|re.S)
    if record is None:
        raise ValueError(f'Blueprint {blueprint} is not registered in LAB catalog')
    data = png_path.read_bytes()
    if len(data) < 33 or not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('Invalid PNG')
    width,height,depth,color,_,_,_ = struct.unpack_from('>IIBBBBB',data,16)
    if (width,height)!=(512,512) or depth!=8 or color!=6:
        raise ValueError('Icon must be transparent RGBA 512x512 PNG')
    meta = read_png_metadata(png_path)
    identity = meta['equipment']; source = meta['source']
    slot_match = re.search(r'"slot"\s*:\s*"([^"]+)"',record.group(1))
    rig_match = re.search(r'"rig_set"\s*:\s*"([^"]+)"',record.group(1))
    if not slot_match or not rig_match or (
        identity.get('slot') != slot_match.group(1) or identity.get('rig_set') != rig_match.group(1)
    ):
        raise ValueError('PNG slot/rig set does not match the LAB blueprint')
    if identity.get('blueprint_id') != blueprint:
        raise ValueError('PNG metadata blueprint differs from selected blueprint')
    if source_path and source.get('repository_path') != source_path:
        raise ValueError('PNG metadata source differs from expected source')
    canonical = ROOT/source['repository_path']
    if not canonical.is_file() or hashlib.sha256(canonical.read_bytes()).hexdigest()!=source['fingerprint']:
        raise ValueError('PNG source model hash does not match canonical .bbmodel')
    if not output.is_file():
        raise ValueError('Existing shared custom icon registry missing')
    original = output.read_text(encoding='utf-8')
    match = re.search(r'(?m)^const ICON_PNG_BASE64 = (\{[^\n]*\})$',original)
    if not match:
        raise ValueError('Custom icon registry has unexpected structure')
    entries = json.loads(match.group(1))
    entries[blueprint] = base64.b64encode(data).decode('ascii')
    updated = original[:match.start(1)] + json.dumps(entries,sort_keys=True,separators=(',',':')) + original[match.end(1):]
    output.write_text(updated,encoding='utf-8')
    return {'blueprint':blueprint,'source':source['repository_path'],'sha256':source['fingerprint'],'bytes':len(data),'output':output.as_posix()}


def main() -> None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('png',type=Path)
    p.add_argument('--blueprint',required=True)
    p.add_argument('--source-path',default='')
    p.add_argument('--output',type=Path,default=OUT)
    args=p.parse_args()
    print(json.dumps(pack_icon(args.png,args.blueprint,args.output,args.source_path),ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
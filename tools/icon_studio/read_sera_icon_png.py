#!/usr/bin/env python3
"""Read metadata from a SERA Icon Studio PNG supplied in any chat.

PNG is a standard RGBA icon plus a tEXt chunk named SERA_ICON_MANIFEST_V1.
Returns the original model path/SHA, equipment blueprint/slot/rig set, and
portrait transform. Metadata may be stripped when images are re-encoded;
use the original exported .png file, not a screenshot, for best results.
"""
from __future__ import annotations
import argparse
import json
import struct
import zlib
from pathlib import Path

SIGNATURE = b'\x89PNG\r\n\x1a\n'
KEY = b'SERA_ICON_MANIFEST_V1'


def read_png_metadata(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 33 or not data.startswith(SIGNATURE):
        raise ValueError('Not a valid PNG')
    index = len(SIGNATURE)
    result = None
    while index + 12 <= len(data):
        size = struct.unpack_from('>I', data, index)[0]
        end = index + 12 + size
        if end > len(data):
            raise ValueError('Truncated PNG chunk')
        chunk_type = data[index + 4:index + 8]
        payload = data[index + 8:index + 8 + size]
        expected = struct.unpack_from('>I', data, index + 8 + size)[0]
        actual = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        if expected != actual:
            raise ValueError('Bad PNG chunk CRC')
        if chunk_type == b'tEXt' and payload.startswith(KEY + b'\x00'):
            result = json.loads(payload[len(KEY) + 1:].decode('ascii'))
            if result.get('format') != 'SERA_ICON_PNG_V1':
                raise ValueError('SERA metadata has unexpected schema')
            source = result.get('source', {})
            path_value = source.get('repository_path', '')
            if not path_value.startswith('models/') or '..' in path_value or not path_value.endswith('.bbmodel'):
                raise ValueError('Missing/unsafe canonical Blockbench source path')
            if not source.get('fingerprint'):
                raise ValueError('Missing source fingerprint')
            equipment = result.get('equipment', {})
            if not equipment.get('slot') or not equipment.get('rig_set'):
                raise ValueError('Missing equipment identity')
            if not result.get('render', {}).get('model_rotation_deg'):
                raise ValueError('Missing icon capture settings')
            return result
        index = end
        if chunk_type == b'IEND':
            break
    raise ValueError('SERA_ICON_MANIFEST_V1 not found; supply the original exported PNG, not a screenshot')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('png', type=Path)
    args = parser.parse_args()
    print(json.dumps(read_png_metadata(args.png), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
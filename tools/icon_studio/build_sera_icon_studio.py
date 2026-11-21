#!/usr/bin/env python3
"""Package a canonical SERA Blockbench model into a no-network icon editor HTML.

Usage:
  python3 tools/build_sera_icon_studio.py \\
    --model models/storage/カメラアイ頭部.bbmodel --slot head --rig-set D \\
    --blueprint H02 --output /mnt/data/SERA_Icon_Studio_IRIS.html

The output is self-contained. The original model and texture are embedded without
modifying source bytes. This tool never requires the user to select a model.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / 'SERA_Icon_Studio.template.html'
MARKER = '__SERA_MODEL_BUNDLE_JSON__'


def build(model_path: Path, source_path: str, slot: str, rig_set: str,
          blueprint: str = '') -> str:
    raw = model_path.read_bytes()
    parsed = json.loads(raw.decode('utf-8'))
    if not isinstance(parsed.get('elements'), list) or not parsed['elements']:
        raise ValueError('Blockbench model has no mesh elements')
    if not isinstance(parsed.get('textures'), list) or not parsed['textures']:
        raise ValueError('Blockbench model has no textures')
    if not source_path.startswith('models/') or not source_path.endswith('.bbmodel'):
        raise ValueError('source_path must be a SERA canonical models/*.bbmodel repo path')
    if not slot or not rig_set:
        raise ValueError('slot and rig_set must identify an actual SERA equipment mapping')
    template = TEMPLATE.read_text(encoding='utf-8')
    if template.count(MARKER) != 2:  # once in JS fallback comparison, once in HTML data tag
        raise RuntimeError('Icon Studio template marker count has changed')
    bundle = {
        'format': 'SERA_MODEL_BUNDLE_V1',
        'source_path': source_path,
        'source_name': parsed.get('name', model_path.stem),
        'sha256': hashlib.sha256(raw).hexdigest(),
        'slot': slot,
        'rig_set': rig_set,
        'blueprint_id': blueprint,
        'bbmodel_base64': base64.b64encode(raw).decode('ascii'),
    }
    html_json = json.dumps(bundle, ensure_ascii=False, separators=(',', ':'))
    # Data itself is only base64/ASCII, so cannot inject a closing script tag.
    return template.replace(f'>{MARKER}</script>', f'>{html_json}</script>')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--model', required=True, type=Path)
    p.add_argument('--source-path', help='GitHub repo path; defaults to --model as given')
    p.add_argument('--slot', required=True)
    p.add_argument('--rig-set', required=True)
    p.add_argument('--blueprint', default='')
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    source_path = args.source_path or args.model.as_posix()
    if source_path.startswith('/'):
        raise SystemExit('--source-path is required if --model is an absolute path')
    out = build(args.model, source_path, args.slot, args.rig_set, args.blueprint)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(out, encoding='utf-8')
    print(f'PACKAGED: {args.output} / {len(out.encode("utf-8"))} bytes, original model preserved')


if __name__ == '__main__':
    main()
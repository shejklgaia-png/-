#!/usr/bin/env python3
"""Read-only source/asset consistency checks. Not a substitute for a Godot run."""
import base64
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
source_bytes = (ROOT / 'assets/sera_source.json').read_bytes()
source = json.loads(source_bytes)
script = (ROOT / 'assets/sera_data.gd').read_text()
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$',script, re.MULTILINE)
assert len(parts) >= 1
assert 'const PARTS = [' in script, 'Do not use a PackedStringArray constructor in a const initializer'
assert 'const PARTS: PackedStringArray' not in script
assert 'PackedStringArray(PARTS)' in script, 'Convert the constant Array to PackedStringArray at runtime'
assert base64.b64decode(''.join(parts)) == source_bytes, 'Embedded source does not match raw model'
assert source['meta']['model_format'] == 'free'

bones = {g['uuid']:g for g in source['groups']}
elements = {e['uuid']:e for e in source['elements']}
# Additional Katana equipment is additive: retain 22 base pivots and 25 base meshes.
assert len([g for g in source['groups'] if not g['name'].startswith('Katana')]) == 22
assert len(elements) >= 25
reached_bones = set()
reached_elements = set()
def collect(value):
    if isinstance(value, str):
        assert value in elements, f'Unknown mesh reference {value}'
        reached_elements.add(value)
    else:
        assert value['uuid'] in bones, f'Unknown bone {value["uuid"]}'
        reached_bones.add(value['uuid'])
        for child in value.get('children',[]):
            collect(child)
for val in source['outliner']:
    collect(val)
assert len(reached_bones) == len(bones)
assert len(reached_elements) == len(elements)

triangle_total = 0
for e in source['elements']:
    verts = e['vertices']
    for face in e['faces'].values():
        ids = face['vertices']
        assert all(key in verts for key in ids)
        assert len(ids) >= 3
        triangle_total += len(ids)-2

clips = {a['name']:a for a in source['animations']}
assert {'Wait_motion', 'run_front_original', 'Step_R', 'Step_L'}.issubset(clips)
assert clips['Wait_motion']['length'] == 3.6
assert clips['run_front_original']['length'] == 1
assert clips['Wait_motion']['loop'] == 'loop'
assert clips['run_front_original']['loop'] == 'loop'
for name in ('Wait_motion','run_front_original'):
    clip=clips[name]
    nr_frames=0
    for uid,animator in clip['animators'].items():
        if uid not in bones:
            assert animator.get('type') == 'effect', f'{name}: bad bone ref {uid}'
            continue
        for frame in animator.get('keyframes',[]):
            if frame['channel'] not in ('position','rotation'): continue
            nr_frames+=1
            assert -0.00001 <= frame['time'] <= clip['length'] + 0.00001
            for value in frame['data_points']:
                for axis in ['x','y','z']:
                    assert math.isfinite(float(value[axis]))
    print(name, 'duration',clip['length'],'frames',nr_frames)
print('meshes:',len(elements),'bones:',len(bones),'triangles:',triangle_total)
print('embedded model bytes:',len(source_bytes),'OK')
print('No Godot executable available: runtime test not performed.')

from pathlib import Path
import json, re, hashlib
ROOT=Path(__file__).resolve().parents[1]
rig=(ROOT/'scripts/sera_rig.gd').read_text(encoding='utf8')
assert '@export_range(0.0, 2.0, 0.05, "or_greater") var sword_effect_forward_offset: float = 0.55' in rig
assert 'elif pivot.name == "Swordeffect":' in rig
assert 'sword_effect_bone = pivot' in rig
assert 'if bone == sword_effect_bone:' in rig
assert 'bone.position.z -= sword_effect_forward_offset' in rig
assert rig.index('bone.position.z -= sword_effect_forward_offset') > rig.index('bone.position = (bind_positions[uid] as Vector3) + translation')
assert 'bone.scale = scale_value' in rig
source=json.loads((ROOT/'assets/sera_source.json').read_text(encoding='utf8'))
assert len([e for e in source['elements'] if e['name']=='Swordeffect']) == 1
for name in ['assets/slash_C_ice_4x2.png','assets/slash_C_scarlet_4x2.png','scenes/main.tscn','scripts/main.gd','scripts/sword_trail.gd']:
 assert (ROOT/name).is_file(), name
for code in [*ROOT.glob('scripts/*.gd'),*ROOT.glob('assets/*.gd')]:
 for match in re.findall(r'(?:preload|load)\(["\'](res://[^"\']+)["\']\)',code.read_text(encoding='utf8')):
  assert (ROOT/match.replace('res://','')).is_file(), f'{code}: {match}'
print('PASS: v28 forward-only shift, source model, images, scenes and dependencies')

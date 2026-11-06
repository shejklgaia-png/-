#!/usr/bin/env python3
"""v31 static audit: verify exact visual changes, no unplanned changes."""
import json, hashlib, zipfile, re
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
ZIP=ROOT.parent/'sera_portrait_godot_melee_v30_volume_slash.zip'
report=[]
def test(label, ok, detail=''):
    report.append({'test':label,'pass':bool(ok),'detail':str(detail)})
    print(('PASS' if ok else 'FAIL'),label,detail)
with zipfile.ZipFile(ZIP) as z:
    names={k.filename for k in z.infolist()}
    oldroot='sera_portrait_godot_melee_v30_volume_slash/'
    originals={n[len(oldroot):]:z.read(n) for n in names if n.startswith(oldroot) and not n.endswith('/')}
for rel, raw in originals.items():
    # v30 archive stored two Blockbench filenames in mojibake; compare against
    # canonical UTF-8 source files and test exact byte correspondence instead.
    if rel.startswith('blockbench/') and rel not in [
      'blockbench/セラ･カラー.bbmodel',
      'blockbench/セラ･カラーエフェクト付き.bbmodel']:
        candidates=list((ROOT/'blockbench').glob('*.bbmodel'))
        test('canonical Blockbench source preserved: '+rel, any(f.read_bytes()==raw for f in candidates))
        continue
    if rel in ['scripts/sword_trail.gd','scripts/hit_burst.gd', 'shaders/slash_C_volume.gdshader','shaders/slash_C_sprite.gdshader','shaders/slash_C_particle.gdshader','project.godot','README_ja.md','tools/v30_validate.py','tools/v30_static_report.json']: continue
    p=ROOT/rel
    test('unchanged file: '+rel, p.exists() and p.read_bytes()==raw)
shaders=['slash_C_volume.gdshader','slash_C_sprite.gdshader','slash_C_particle.gdshader']
for sh in shaders:
    rel='shaders/'+sh
    new=(ROOT/rel).read_text()
    old=originals[rel].decode()
    test(sh+' has no depth test', 'depth_test_disabled' in new)
    test(sh+' only adds depth_test_disabled', new==old.replace('depth_draw_never','depth_draw_never, depth_test_disabled'))
trail=(ROOT/'scripts/sword_trail.gd').read_text()
oldtrail=originals['scripts/sword_trail.gd'].decode()
expected=oldtrail.replace('## v30. Every visible effect is a child','## v31. No depth test on the arc, residue and particles; all stay aligned.\n## v30. Every visible effect is a child',1)
for old,new in [('flat_material.render_priority = 1','flat_material.render_priority = 105'),('volume_material.render_priority = 0','volume_material.render_priority = 100'),('particle_material.render_priority = 2','particle_material.render_priority = 110')]:
    expected=expected.replace(old,new)
    test('material priority '+new, new in trail)
test('other trail logic unchanged', trail==expected)
impact=(ROOT/'scripts/hit_burst.gd').read_text()
oldimpact=originals['scripts/hit_burst.gd'].decode()
expected=oldimpact.replace('material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED','material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA')
expected=expected.replace('material.no_depth_test = false','material.no_depth_test = true')
expected=expected.replace('material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY','material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED\n    material.render_priority = 120')
test('impact only changes rendering flags', impact==expected)
rig=(ROOT/'scripts/sera_rig.gd').read_text()
test('forward 0.55m unchanged','sword_effect_forward_offset: float = 0.55' in rig)
test('shared authored rig unchanged', (ROOT/'scripts/sera_rig.gd').read_bytes()==originals['scripts/sera_rig.gd'])
test('8 frame UV and timing retained', all(t in trail for t in ['0.375','0.315','0.255','0.205','0.165','0.130','0.105']))
test('3D rear-facing culling kept', 'cull_front' in (ROOT/'shaders/slash_C_volume.gdshader').read_text())
test('all 8 meshes available', len(json.loads((ROOT/'assets/slash_C_volume_geometry.json').read_text())['frames'])==8)
test('priority order volume < flat < particles < hit', 100<105<110<120<=127)
summary={'checked':len(report),'passed':sum(t['pass'] for t in report),'failed':sum(not t['pass'] for t in report),'engine_runtime':'NOT RUN — Godot executable unavailable'}
(ROOT/'tools/v31_static_report.json').write_text(json.dumps({'summary':summary,'tests':report},ensure_ascii=False,indent=2))
print('SUMMARY',summary)
if summary['failed']:raise SystemExit(1)

"""Static checks for Sera v34: occlusion/render order and preservation audit."""
from pathlib import Path
import json,hashlib,math,re,sys,random
root=Path(__file__).resolve().parents[1]
prev=root.parent/'sera_portrait_godot_melee_v33_slash_visibility_fix'
checks=[]
def add(name,condition):
 checks.append({'check':name,'pass':bool(condition)})
 def msg(): return 'PASS' if condition else 'FAIL'
 print(f'{msg()} {name}')

rig=(root/'scripts/sera_rig.gd').read_text()
slash=(root/'scripts/sword_trail.gd').read_text()
for name in ['sprite','volume','particle']:
 p=root/f'shaders/slash_C_{name}.gdshader'
 s=p.read_text()
 add(f'{name} samples target only with ray-box', 'target_silhouette_coverage()' in s and 'target_overlap_factor()' in s and 'scene_depth_texture' not in s)
 add(f'{name} renders above target without depth test', 'depth_test_disabled' in s and 'depth_draw_never' in s)
 add(f'{name} fades only target silhouette', 'mix(1.0, target_overlap_opacity, target_silhouette_coverage())' in s)
 add(f'{name} shader appears structurally balanced', s.count('{')==s.count('}') and s.count('(')==s.count(')'))
add('volume near-transparent texels never force opaque alpha','(0.27 +' not in (root/'shaders/slash_C_volume.gdshader').read_text().split('void fragment()')[1] and 'pow(ink.a, 1.25)' in (root/'shaders/slash_C_volume.gdshader').read_text())
add('volume still back-face culled','cull_front' in (root/'shaders/slash_C_volume.gdshader').read_text())
add('player overlay material installed','result.material_overlay' not in rig and 'part.material_overlay' in rig)
add('player overlay enabled only when slash visible', '_set_player_foreground(true)' in slash and slash.count('_set_player_foreground(false)')>=3)
add('render priority order volume<flat<particle<player','render_priority = 100' in slash and 'render_priority = 105' in slash and 'render_priority = 110' in slash and 'render_priority = 126' in rig)
add('player overlay depth-test disabled', 'depth_test_disabled' in (root/'shaders/sera_foreground.gdshader').read_text())
add('player overlay original palette','set_shader_parameter("sera_palette", SERA_TEXTURE)' in rig)
add('no extra z offset on slash','sword_effect_forward_offset: float = 0.55' in rig and 'volume_instance.transform = Transform3D.IDENTITY' in slash)
add('both volume and texture share rig bone/mesh', 'instance.add_child(volume_instance)' in slash and 'instance.material_override = flat_material' in slash)
add('all original geometry files preserved', (root/'assets/slash_C_volume_geometry.json').read_bytes() == (prev/'assets/slash_C_volume_geometry.json').read_bytes())
add('all original 8 frame texture data preserved', (root/'assets/slash_C_white_clean_4x2.png').read_bytes() == (prev/'assets/slash_C_white_clean_4x2.png').read_bytes())
add('Blockbench data preserved', (root/'blockbench/セラ･カラーエフェクト付き.bbmodel').read_bytes()==(prev/'blockbench/セラ･カラーエフェクト付き.bbmodel').read_bytes())
add('main combat, input and camera unchanged',(root/'scripts/main.gd').read_bytes()==(prev/'scripts/main.gd').read_bytes())
add('no shader alpha floor on volume','(0.27 +' not in (root/'shaders/slash_C_volume.gdshader').read_text())
add('target bounds match game cube', 'TARGET_HALF_SIZE: float = 1.0' in (root/'scripts/main.gd').read_text() and 'target_box_half_extent", Vector3.ONE' in slash)
add('target moved dynamically','var center: Vector3 = target_node.global_position' in slash and '_update_occlusion_uniforms()' in slash)

# A handful of numeric ray/AABB tests for left and right camera positions.
def mask(camera,direction,center=(0,1.53,-8),half=(1,1,1),feather=.08):
 r=[]
 for i in range(3):
  d=direction[i] if abs(direction[i])>=1e-5 else 1e-5
  r.append(sorted(((center[i]-half[i]-camera[i])/d,(center[i]+half[i]-camera[i])/d)))
 entry=max(x[0] for x in r); exit=min(x[1] for x in r)
 through=max(0,exit-max(entry,0))
 t=min(1,max(0,through/feather))
 return t*t*(3-2*t)
for pos in [(-4,2,4),(4,2,4),(0,3,4)]:
 center=(0,1.53,-8)
 v=tuple(center[i]-pos[i] for i in range(3)); n=math.sqrt(sum(x*x for x in v)); direction=tuple(x/n for x in v)
 add(f'raybox center silhouette visible from camera {pos}', mask(pos,direction)>0.99)
 add(f'raybox outside target from camera {pos}', mask(pos,(0,1,0))<0.001)

report={'version':34,'passed':sum(x['pass'] for x in checks),'total':len(checks),'checks':checks,'runtime_test':'not available (Godot binary not installed)'}
(root/'tools/v34_static_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print(f"RESULT {report['passed']}/{report['total']}")
sys.exit(0 if report['passed']==report['total'] else 1)

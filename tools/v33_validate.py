from pathlib import Path
import json
from PIL import Image
base=Path(__file__).resolve().parents[1]
checks={}
rig=(base/'scripts/sera_rig.gd').read_text()
fx=(base/'scripts/sword_trail.gd').read_text()
main=(base/'scripts/main.gd').read_text()
geo=json.loads((base/'assets/slash_C_volume_geometry.json').read_text())
checks['offset_0_55_not_doubled']=('sword_effect_forward_offset: float = 0.55' in rig and 'sword_effect_forward_offset' not in fx)
checks['authored_swordeffect_used']='get_sword_effect_mesh' in fx
checks['8_animation_frames']='frame_meshes[frame]' in fx and len(geo['frames'])==8
checks['original_uv_basis']='(u-0.5)*1.04' in fx and '(v-0.5)*1.04' in fx
checks['full_brightness']='flat_layer_opacity: float = 1.00' in fx
checks['default_target_foreground']='target_occluded_visibility: float = 1.0' in fx
checks['player_occlusion_enabled']='debug_disable_occlusion: bool = false' in fx
checks['independent_sparks']='spark' in fx and 'particle_rate: int = 54' in fx
checks['geometry_valid']=True
checks['finite_smooth_height']=True
for fr in geo['frames']:
    ps=fr['points']; ts=fr['triangles']
    if not ps or not ts or not all(0<=i<len(ps) for t in ts for i in t): checks['geometry_valid']=False
    if not all(0<=p[0]<=1 and 0<=p[1]<=1 and 0<=p[2]<=0.065 for p in ps): checks['finite_smooth_height']=False
img=Image.open(base/'assets/slash_C_white_clean_4x2.png')
checks['uv_atlas']=(img.mode=='RGBA' and img.size==(2048,1024))
checks['target_shader_surface_filter']=True
checks['shader_brace_balance']=True
checks['shader_occlusion_switch']=True
for name in ['slash_C_sprite.gdshader','slash_C_volume.gdshader','slash_C_particle.gdshader']:
    s=(base/'shaders'/name).read_text()
    if 'float surface_distance = abs(max(outside.x' not in s:checks['target_shader_surface_filter']=False
    if s.count('{')!=s.count('}') or '\\n' in s: checks['shader_brace_balance']=False
    if 'uniform bool occlusion_enabled = true;' not in s:checks['shader_occlusion_switch']=False
print('v33 validation')
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
print('RESULT',sum(checks.values()),'/',len(checks),'STATIC CHECKS; Godot runtime unavailable')
assert all(checks.values())

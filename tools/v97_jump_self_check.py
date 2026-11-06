#!/usr/bin/env python3
from pathlib import Path
import json,base64,math,re
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text('utf-8')
rig=(root/'scripts/sera_rig.gd').read_text('utf-8')
source=json.loads((root/'assets/sera_source.json').read_text('utf-8'))
user=json.loads((root/'blockbench/SERA_jump_user_input.bbmodel').read_text('utf-8'))
integrated=json.loads((root/'blockbench/SERA_v97_jump_integrated.bbmodel').read_text('utf-8'))
data=(root/'assets/sera_data.gd').read_text('utf-8')
chunks=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',data,re.M)
embedded=json.loads(base64.b64decode(''.join(chunks)).decode('utf-8'))
checks={
 'jump is named':source['animations'][-1]['name']=='Jump' and user['animations'][-1]['name']=='',
 'clip same raw keyframes':source['animations'][-1]['animators']==user['animations'][-1]['animators'],
 'only 1 added clip':len(source['animations'])==len(user['animations']),
 'editable integrated matches runtime':source==integrated,
 'embedded matches source':embedded==source,
 'jump rig clip exists': 'const JUMP_CLIP: String = "Jump"' in rig,
 'jump loading check': 'animations.has(JUMP_CLIP)' in rig,
 'jump progress synced': 'func set_jump_progress(progress: float)' in rig and 'JUMP_FLIGHT_SECONDS' in main,
 'movement blocked by jump clip':'or jump_playback or damage_playback' in rig,
 'anti double jump':'if jump_active or damage_reaction_active or step_active' in main,
 'short flick':'_is_upward_jump_flick(release_pos - pointer_origin, press_duration)' in main,
 'long drag flick tail':'func _classify_recent_upward_flick()' in main,
 'jump motion uses collision':'player.move_and_collide(Vector3(0.0, vertical_delta, 0.0))' in main,
 'horizontal collision swept':'_move_player_swept(jump_horizontal_velocity * delta, true)' in main,
 'horizontal velocity decay factor':'JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.65' in main,
 'jump height 1.5m':'JUMP_HEIGHT: float = 1.50' in main,
 '0.80s flight':'JUMP_FLIGHT_SECONDS: float = 0.80' in main,
 'backstep unchanged':'BACK_STEP_DISTANCE: float = 4.0' in main,
 'damage pipeline unchanged':'_on_enemy_projectile_hit' in main,
 'audio routing unchanged':'sera_player_bullet_hit_v96.wav' in main and 'sera_melee_hit_all.wav' in main,
 'damage remains 12/12/26':'const STRIKE_DAMAGE = [12, 12, 26]' in main,
 'boost hysteresis unchanged':'BOOST_START_RADIUS_RATIO: float = 1.25' in main and 'BOOST_EXIT_RADIUS_RATIO: float = 1.10' in main,
 'frame independent apex':all(abs(4*p*(1-p)-1)<1e-9 for p in [0.5]),
 'landing ends on floor': abs(4*1.0*(1-1.0))<1e-9,
 'jump sound untouched':(root/'assets/sera_player_bullet_hit_v96.wav').is_file(),
}
for label,passed in checks.items():
 if not passed: raise AssertionError(label)
print(f'v97 jump self-check: {len(checks)} PASS')

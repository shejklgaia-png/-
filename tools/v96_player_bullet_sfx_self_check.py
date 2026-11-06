#!/usr/bin/env python3
"""v96: static checks; does not run Godot/Android."""
from pathlib import Path
import wave,re,hashlib
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text('utf-8')
project=(root/'project.godot').read_text('utf-8')
with wave.open(str(root/'assets/sera_player_bullet_hit_v96.wav'),'rb') as w:
    audio=(w.getframerate()==48000 and w.getnchannels()==2 and w.getsampwidth()==2 and w.getcomptype()=='NONE' and .9<w.getnframes()/w.getframerate()<1.2)
checks={
    'v96 version': 'SERA v96 | Player bullet hit SFX' in project,
    'bullet sound loading': main.count('player_bullet_hit_audio.stream = load("res://assets/sera_player_bullet_hit_v96.wav")')==1,
    'old bullet sound not loading': 'load("res://assets/sera_bullet_hit_short.wav")' not in main,
    'old bullet sound preserved': (root/'assets/sera_bullet_hit_short.wav').is_file(),
    'melee sound unchanged': main.count('load("res://assets/sera_melee_hit_all.wav")')==2,
    'area sound unchanged': 'player_hit_audio.stream = load("res://assets/metal_damage_hit.wav")' in main,
    'bullet volume': 'player_bullet_hit_audio.volume_db = -5.0' in main,
    'bullet polyphony': 'player_bullet_hit_audio.max_polyphony = 3' in main,
    'attack type distinguishes bullet/area': 'player_bullet_hit_audio if is_bullet else player_hit_audio' in main,
    'damage only when hit': '_on_enemy_projectile_hit' in main and 'enemy_shooter.connect("projectile_hit", Callable(self, "_on_enemy_projectile_hit"))' in main,
    'signal matches attack route': 'signal projectile_hit(world_position: Vector3, travel_direction: Vector3, is_bullet: bool)' in (root/'scripts/enemy_shooter.gd').read_text('utf-8'),
    'melee damage unchanged': 'const STRIKE_DAMAGE = [12, 12, 26]' in main,
    '4m backstep preserved': 'const BACK_STEP_DISTANCE: float = 4.0' in main,
    'WAV audio format/duration': audio,
    'original mp3 preserved': (root/'assets/sera_player_bullet_hit_v96_source.mp3').is_file(),
}
for k,v in checks.items():
    if not v: raise AssertionError(k)
print('v96 assertions',len(checks),'PASS')

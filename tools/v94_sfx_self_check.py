#!/usr/bin/env python3
"""v94 attack-specific SFX static assertions (does NOT run Godot)."""
from pathlib import Path
import hashlib
import re
import wave
r = Path(__file__).resolve().parents[1]
main = (r/'scripts/main.gd').read_text(encoding='utf-8')
shooter = (r/'scripts/enemy_shooter.gd').read_text(encoding='utf-8')
prj = (r/'project.godot').read_text(encoding='utf-8')
checks = {}
checks['v94 title'] = 'SERA v94 | Attack-specific impact SFX' in prj
checks['4 independent audio nodes'] = all(f'{k} = AudioStreamPlayer.new()' in main for k in ('hit_audio','melee_finisher_audio','player_bullet_hit_audio','player_hit_audio'))
checks['all exact WAV paths'] = all(f'load("res://assets/{name}")' in main for name in ('sera_bullet_hit_short.wav','sera_melee1_short.wav','sera_melee2_long.wav','metal_damage_hit.wav'))
checks['original metal source remains'] = (r/'assets/metal_damage_hit_source.mp3').is_file()
checks['no random pitch'] = 'hit_audio.pitch_scale = randf_range(' not in main
checks['3 combo damage values unchanged'] = 'const STRIKE_DAMAGE = [12, 12, 26]' in main
checks['4m backstep unchanged'] = 'const BACK_STEP_DISTANCE: float = 4.0' in main
checks['melee stage audio selector'] = 'melee_finisher_audio if strike_index == 2 else hit_audio' in main
hit_section = re.search(r'func _register_strike_hit\(.*?(?=\nfunc )', main, re.S).group()
checks['sound only in confirmed melee hit function'] = hit_section.count('strike_sound.play()') == 1 and hit_section.index('strike_did_hit = true') < hit_section.index('strike_sound.play()')
checks['no sound in _start_strike'] = 'play()' not in re.search(r'func _start_strike\(.*?(?=\nfunc )', main, re.S).group()
checks['hit reaction still called'] = '_begin_damage_reaction(incoming_direction)' in main
checks['bullet/area sfx selection'] = 'player_bullet_hit_audio if is_bullet else player_hit_audio' in main
checks['signal declares type'] = 'signal projectile_hit(world_position: Vector3, travel_direction: Vector3, is_bullet: bool)' in shooter
checks['bullet captured at spawn'] = '_on_projectile_hit").bind(true)' in shooter
checks['area captured at spawn'] = '_on_projectile_hit").bind(false)' in shooter
checks['kind forwarded exactly'] = 'projectile_hit.emit(world_position, travel_direction, is_bullet)' in shooter
checks['kind received by main'] = 'is_bullet: bool) -> void:' in main
checks['retained v93 metal audio'] = 'player_hit_audio.stream = load("res://assets/metal_damage_hit.wav")' in main
checks['enemy attack debug retained'] = (r/'scripts/enemy_debug_ui.gd').exists()
for name, duration in [('sera_bullet_hit_short.wav',0.36),('sera_melee1_short.wav',0.68),('sera_melee2_long.wav',1.54)]:
    p = r/'assets'/name
    with wave.open(str(p),'rb') as w:
        checks[name + ' encoding'] = w.getnchannels()==2 and w.getsampwidth()==2 and w.getframerate()==48000
        checks[name + ' duration'] = abs(w.getnframes()/w.getframerate()-duration)<0.0001
    checks[name + ' file not empty'] = p.stat().st_size>1000
for k,v in checks.items():
    assert v, f'FAIL: {k}'
print('v94 SFX static tests:',len(checks),'PASS')

#!/usr/bin/env python3
"""SERA v95 sound-only regression checks. Does not launch Godot."""
from pathlib import Path
import wave, hashlib, re
r=Path(__file__).resolve().parents[1]
m=(r/'scripts/main.gd').read_text(encoding='utf-8')
project=(r/'project.godot').read_text(encoding='utf-8')
checks={
 'version': 'SERA v95 | Unified melee hit sound' in project,
 'stage1 and stage2 stream': 'hit_audio.stream = load("res://assets/sera_melee_hit_all.wav")' in m,
 'stage3 stream': 'melee_finisher_audio.stream = load("res://assets/sera_melee_hit_all.wav")' in m,
 'both streams use same asset': m.count('load("res://assets/sera_melee_hit_all.wav")')==2,
 'old melee sounds not loaded': all(('load("res://assets/'+n+'")') not in m for n in ('sera_melee1_short.wav','sera_melee2_long.wav')),
 'old melee assets retained': all((r/'assets'/n).is_file() for n in ('sera_melee1_short.wav','sera_melee2_long.wav')),
 'source retained': (r/'assets/sera_melee_hit_all_source.mp3').is_file(),
 'damage unchanged': 'const STRIKE_DAMAGE = [12, 12, 26]' in m,
 'stage selection unchanged': 'melee_finisher_audio if strike_index == 2 else hit_audio' in m,
 'bullet SFX unchanged': 'player_bullet_hit_audio.stream = load("res://assets/sera_bullet_hit_short.wav")' in m,
 'area SFX unchanged': 'player_hit_audio.stream = load("res://assets/metal_damage_hit.wav")' in m,
 'backstep preserved': 'const BACK_STEP_DISTANCE: float = 4.0' in m,
 'no random melee pitch': 'hit_audio.pitch_scale' not in m and 'melee_finisher_audio.pitch_scale' not in m,
 'volume retained': m.count('    hit_audio.volume_db = -5.0') == 1 and m.count('    melee_finisher_audio.volume_db = -5.0') == 1,
 'polyphony retained': '    hit_audio.max_polyphony = 4' in m and '    melee_finisher_audio.max_polyphony = 3' in m,
}
section=re.search(r'func _register_strike_hit\(.*?(?=\nfunc )',m,re.S).group()
checks['only confirmed melee hits trigger playback']=(section.index('strike_did_hit = true')<section.index('strike_sound.play()') and section.count('strike_sound.play()')==1)
checks['no hit sound in strike input']='.play()' not in re.search(r'func _start_strike\(.*?(?=\nfunc )',m,re.S).group()
with wave.open(str(r/'assets/sera_melee_hit_all.wav'),'rb') as w:
 checks['WAV 48kHz stereo PCM16']=(w.getframerate()==48000 and w.getnchannels()==2 and w.getsampwidth()==2 and w.getcomptype()=='NONE')
 checks['new WAV duration']=(0.75 < w.getnframes()/w.getframerate() < 0.95)
for key,passed in checks.items():
 assert passed, key
print('v95 sound routing static assertions:',len(checks),'PASS')

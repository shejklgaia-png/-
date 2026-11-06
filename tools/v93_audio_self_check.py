#!/usr/bin/env python3
"""v93 audio wiring smoke test; static only, NOT Godot runtime verification."""
from pathlib import Path
import wave, re
r = Path(__file__).resolve().parents[1]
main=(r/'scripts/main.gd').read_text(encoding='utf8')
checks={
    'v93 project': 'SERA v93 | Metal damage impact SFX' in (r/'project.godot').read_text(),
    'enemy hit stream uses attached WAV': 'var shared_damage_stream: AudioStream = load("res://assets/metal_damage_hit.wav")' in main,
    'enemy audio player is present': 'hit_audio = AudioStreamPlayer.new()' in main,
    'player audio player is present': 'player_hit_audio = AudioStreamPlayer.new()' in main,
    'both share the same stream': main.count('stream = shared_damage_stream') == 2,
    'player hit plays sound': re.search(r'func _on_enemy_projectile_hit\(.*?(?=\nfunc )', main, re.S).group().count('player_hit_audio.play()')==1,
    'target strike plays sound': re.search(r'func _register_strike_hit\(.*?(?=\nfunc )', main, re.S).group().count('hit_audio.play()')==1,
    'pitch unchanged': 'randf_range(0.94, 1.08)' not in main,
    'old synthesized hit not referenced': 'res://assets/sword_impact.wav' not in main,
    'old synthesized file preserved': (r/'assets/sword_impact.wav').exists(),
    'original mp3 retained': (r/'assets/metal_damage_hit_source.mp3').is_file(),
    'damage reaction remains called': '_begin_damage_reaction(incoming_direction)' in main,
    '4m backstep unchanged': 'const BACK_STEP_DISTANCE: float = 4.0' in main,
    'triple combo unchanged': 'const STRIKE_DAMAGE = [12, 12, 26]' in main,
    'attack debug ui unchanged': (r/'scripts/enemy_debug_ui.gd').exists(),
}
with wave.open(str(r/'assets/metal_damage_hit.wav')) as wav:
    checks['audio PCM 44.1k stereo']=(wav.getframerate()==44100 and wav.getnchannels()==2 and wav.getsampwidth()==2)
    checks['audio 1.46s']=(1.35<wav.getnframes()/wav.getframerate()<1.55)
for k,v in checks.items():
    assert v,k
print(f'v93 audio static self-check: {len(checks)} PASS')

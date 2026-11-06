#!/usr/bin/env python3
"""v104 audio assets and stage wiring. Run from a complete project root."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
AUDIO = {
    "intro": ("sera_training_v08_intro.ogg", "052db14343f4ee335ab5c31c7863f11abbcc3c0df1e2be8fc0708b43bb3592be"),
    "loop": ("sera_training_v08_loop.ogg", "1166c2e053860369c231d8e8abe135d748e00932962d092d4c1d853f0f03fa63"),
}

for name, (filename, expected_hash) in AUDIO.items():
    path = ROOT / "BGM" / filename
    assert path.is_file(), f"Missing v104 {name} audio: {path}"
    data = path.read_bytes()
    assert data[:4] == b"OggS", f"Invalid Ogg capture pattern: {filename}"
    assert b"vorbis" in data[:4096], f"Not an Ogg Vorbis file: {filename}"
    assert hashlib.sha256(data).hexdigest() == expected_hash, f"Audio contents differ: {filename}"

scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
script = (ROOT / "scripts/stage_bgm.gd").read_text(encoding="utf-8")
assert 'script = ExtResource("1_main")' in scene, "Original gameplay root lost"
assert '[node name="StageBGM" type="Node" parent="."]' in scene, "BGM controller not attached"
assert 'res://scripts/stage_bgm.gd' in scene
assert 'intro_stream.loop = false' in script
assert 'loop_stream.loop = true' in script
assert 'intro_player.finished.connect(_on_intro_finished)' in script
assert 'loop_player.play()' in script
assert "res://BGM/sera_training_v08_intro.ogg" in script
assert "res://BGM/sera_training_v08_loop.ogg" in script
print("v104 stage BGM static checks: OK (files, SHA-256, scene and loop wiring)")
print("Godot runtime / Xperia 1 V sound playback: NOT tested")

#!/usr/bin/env python3
"""v105 targeted regression test (not a Godot or Android audio run)."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "intro": ("052db14343f4ee335ab5c31c7863f11abbcc3c0df1e2be8fc0708b43bb3592be", 127882),
    "loop": ("1166c2e053860369c231d8e8abe135d748e00932962d092d4c1d853f0f03fa63", 1303820),
}

for role, (sha, size) in EXPECTED.items():
    p = ROOT / "BGM" / f"sera_training_v08_{role}.ogg"
    b = p.read_bytes()
    assert len(b) == size, f"{role} size mismatch"
    assert b[:4] == b"OggS" and b"vorbis" in b[:4096], f"{role} is not Ogg Vorbis"
    assert hashlib.sha256(b).hexdigest() == sha, f"{role} hash mismatch"

src = (ROOT / "scripts/stage_bgm.gd").read_text(encoding="utf-8")
scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
assert src.count("AudioStreamOggVorbis.load_from_file(") == 2
assert "ResourceLoader.exists(" not in src
assert 'call_deferred("_start_bgm")' in src
assert "intro_stream.loop = false" in src
assert "loop_stream.loop = true" in src
assert "intro_player.finished.connect(_on_intro_finished)" in src
assert "intro_player.play()" in src
assert "loop_player.play()" in src
assert "res://BGM/sera_training_v08_intro.ogg" in src
assert "res://BGM/sera_training_v08_loop.ogg" in src
assert '[node name="StageBGM" type="Node" parent="."]' in scene
assert 'script = ExtResource("2_stage_bgm")' in scene
assert 'script = ExtResource("1_main")' in scene
print("v105 BGM static regression: PASS (OGG bytes, file paths, controller, intro/loop, scene)")
print("Godot runtime and Android audio: NOT tested by this script")

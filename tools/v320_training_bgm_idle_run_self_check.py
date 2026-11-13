#!/usr/bin/env python3
"""v320: verify provided-song loop integration and direct idle->RUN."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
bgm = (ROOT / "scripts/stage_bgm.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v320"' in project
assert 'res://BGM/dennou_sector_seamless.ogg' in bgm
assert 'SECTOR_LOOP_OFFSET_SECONDS: float = 18.46153846' in bgm
assert "sector_stream.loop = true" in bgm
assert "sector_stream.loop_offset = SECTOR_LOOP_OFFSET_SECONDS" in bgm
assert "if FileAccess.file_exists(SECTOR_PATH):" in bgm
assert "AudioStreamOggVorbis.load_from_file(SECTOR_PATH)" in bgm
assert "AudioStreamOggVorbis.load_from_file(INTRO_PATH)" in bgm
assert "AudioStreamOggVorbis.load_from_file(LOOP_PATH)" in bgm
assert "idle_to_run_landing_elapsed" not in rig
assert "IDLE_TO_RUN_LANDING_" not in rig
assert re.search(r"elif not freeze_attack_pose.*?clip_time \+= delta \* playback_rate", rig, re.S)
# When the separately delivered Ogg is installed, verify its signature.
music = ROOT / "BGM" / "dennou_sector_seamless.ogg"
if music.exists():
    content = music.read_bytes()
    assert content.startswith(b"OggS") and b"vorbis" in content[:4096]
    assert 2000000 < len(content) < 9000000
print("SERA_V320_TRAINING_BGM_IDLE_RUN_STATIC_PASS")

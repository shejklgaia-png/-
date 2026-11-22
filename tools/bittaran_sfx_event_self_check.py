#!/usr/bin/env python3
"""SERA Bittaran: creator-provided cue data and event routing are present."""
from pathlib import Path
import base64
import re

root = Path(__file__).resolve().parents[1]
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
ik = (root / "scripts/bittaran_foot_ik.gd").read_text(encoding="utf-8")
data = (root / "assets/bittaran_sfx_data.gd").read_text(encoding="utf-8")
expected = ("FOOTSTEP", "ARM", "COLLAPSE", "PUNCH")
for key in expected:
    match = re.search(r'const\s+' + key + r':\s*String\s*=\s*"([A-Za-z0-9+/=]+)"', data)
    assert match, "missing embedded creator sound: " + key
    raw = base64.b64decode(match.group(1), validate=True)
    assert len(raw) > 4000 and raw.startswith(b"OggS"), "not an Ogg stream: " + key
for line in (
    'const DOWN_FRONT_FX_SOURCE_SECONDS: float = 1.75',
    'const DOWN_REAR_FX_SOURCE_SECONDS: float = 0.75',
    'func body_fall_fx_source_seconds() -> float:',
    'authored_down_motion_time() < body_fall_fx_source_seconds()',
):
    assert line in ik, "down FX timing absent: " + line
# The original 1.75s DOWN hold/return clock must not move with dust.
assert 'const DOWN_CONTACT_SOURCE_SECONDS: float = 1.75' in ik
for kind in ("footstep", "arm", "collapse", "punch"):
    assert '_play_bittaran_sound("' + kind + '")' in battle, "not routed: " + kind
# v544: lower only walking footstep -5 -> -13dB, with two
# simultaneous diagonal feet but no four-voice pileup. Preserve attack SE.
assert '"footstep": -13.0, "arm": 4.0' in battle
assert 'channel.max_polyphony = 2' in battle
assert "bittaran_bgm.volume_db = -8.0" in battle
assert "func _tick_bittaran_attack_sfx() -> void:" in battle
assert "fall_vertical_shake_strength" in battle
assert 'Marshalls.base64_to_raw' in battle
print("PASS bittaran_sfx_event_self_check")

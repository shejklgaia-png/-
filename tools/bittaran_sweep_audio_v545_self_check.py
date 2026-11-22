#!/usr/bin/env python3
"""v545 Bittaran: user's actual loop source, 1x hit-window playback, 3s fade."""
from pathlib import Path
import base64, re

root = Path(__file__).resolve().parents[1]
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
attacks = (root / "scripts/bittaran_attacks.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
source = (root / "assets/bittaran_sweep_loop_data.gd").read_text(encoding="utf-8")
match = re.search(r'const SWEEP_MP3: String = "([A-Za-z0-9+/=]+)"', source)
assert match, "real uploaded sweep loop data missing"
data = base64.b64decode(match.group(1), validate=True)
assert len(data) > 5000 and (data.startswith(b"ID3") or data[0] == 0xff), (
    "not a real MP3 recording"
)
for line in (
    "const BITTARAN_SWEEP_LOOP_FADE_SECONDS: float = 3.0",
    "const BITTARAN_SWEEP_LOOP_VOLUME_DB: float = 2.0",
    "AudioStreamMP3.load_from_buffer",
    "stream.loop = true",
    "player.pitch_scale = 1.0",
    "func _tick_bittaran_sweep_loop_audio(delta: float) -> void:",
    "var hit_active: bool = _sweep_hit_window_active()",
    "linear_to_db(ratio)",
    "_tick_bittaran_sweep_loop_audio(delta)",
    "_reset_bittaran_sweep_loop_audio()",
):
    assert line in battle, f"missing sweep audio contract: {line}"
# Keep original authored four-leg hit windows. Do not extend the collider
# merely to make the sound persist during the fade.
for line in (
    "const SWEEP_FRONT_HIT_START_SECONDS: float = 0.67",
    "const SWEEP_FRONT_HIT_END_SECONDS: float = 1.38",
    "const SWEEP_REAR_HIT_START_SECONDS: float = 0.17",
    "const SWEEP_REAR_HIT_END_SECONDS: float = 0.63",
):
    assert line in attacks, f"author clip window moved: {line}"
assert "bool(bittaran_attack_frame.get(\"hit_window\", false))" in battle
assert '"footstep": -13.0, "arm": 4.0' in battle
for name in (
    "py tools/bittaran_sweep_audio_v545_self_check.py",
    "gd tools/bittaran_sweep_audio_v545_runtime_check.gd",
    "gd tools/bittaran_sfx_event_runtime_check.gd",
    "gd tools/bittaran_camera_shake_runtime_check.gd",
):
    assert name in manifest, f"missing registered regression: {name}"
print("PASS BITTARAN_SWEEP_AUDIO_V545 source+hitkeys+3s-fade+volume")

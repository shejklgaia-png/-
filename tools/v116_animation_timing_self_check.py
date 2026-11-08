#!/usr/bin/env python3
"""v116: BOOST direction response/crossfade and 25% faster RUN playback."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
ui = (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8")

def constant(src: str, key: str) -> float:
    match = re.search(r"const " + re.escape(key) + r": float = ([0-9.]+)", src)
    assert match is not None, key
    return float(match.group(1))

assert 'config/name="SERA v116 - BOOST Response and RUN Tempo"' in project
assert constant(rig, "RUN_ANIMATION_SPEED") == 1.875
assert math.isclose(constant(rig, "RUN_ANIMATION_SPEED") / 1.5, 1.25)
assert constant(rig, "BOOST_DIRECTION_BLEND_SECONDS") == 0.06
assert constant(rig, "BOOST_STATE_BLEND_SECONDS") == 0.08
assert constant(rig, "BLEND_SECONDS") == 0.16

# Playback time factor applies to every RUN clip, and not BOOST or combat.
assert 'const RUN_CLIPS = [RUN_CLIP, RUN_BACK_CLIP, RUN_RIGHT_CLIP, RUN_LEFT_CLIP]' in rig
assert "clip_time += delta * (RUN_ANIMATION_SPEED if current_clip in RUN_CLIPS else 1.0)" in rig
assert "var pose: Dictionary = _blended_run_pose(str(uid), t)" in rig
assert "var source_name: String = RUN_CLIP if i == 0 else RUN_BACK_CLIP" in rig
assert "const RUN_HEAD_SWAY_RETENTION: float = 0.35" in rig
assert "const RUN_ROOT_TURN_SPEED_DEGREES: float = 450.0" in rig
assert "const RUN_MODE_BLEND_SECONDS: float = 0.18" in rig

# Shorter crossfade is selected only on transitions to/from locomotion BOOST.
assert "var fade_seconds: float = BLEND_SECONDS" in rig
assert "if wanted == BOOST_CLIP or current_clip == BOOST_CLIP:" in rig
assert "fade_seconds = BOOST_STATE_BLEND_SECONDS" in rig
assert "_switch_clip(wanted, fade_seconds)" in rig
assert "if wanted == current_clip or not animations.has(wanted):" in rig
assert "_switch_clip(GUARD_CLIP, 0.095)" in rig
assert "_switch_clip(STEP_RIGHT_CLIP if side > 0 else STEP_LEFT_CLIP, 0.055)" in rig

# Direction response still uses shortest angular difference and same four pose sources.
assert "var angle_delta: float = wrapf(target_angle - current_angle, -PI, PI)" in rig
assert "var boost_alpha: float = 1.0 - exp(-maxf(delta, 0.0) / BOOST_DIRECTION_BLEND_SECONDS)" in rig
assert "boost_direction_smoothed = Vector2(sin(smoothed_angle), cos(smoothed_angle))" in rig
assert 'const BOOST_CLIPS = [BOOST_CLIP, BOOST_BACK_CLIP, BOOST_RIGHT_CLIP, BOOST_LEFT_CLIP]' in rig
assert "fore_aft_rotation.slerp(lateral_rotation, lateral_weight).normalized()" in rig

# No change to movement speed, BOOST activation/exit or controller display.
assert constant(main, "MOVE_SPEED") == 3.25
assert constant(main, "MOVEMENT_BOOST_MULTIPLIER") == 1.5
assert constant(main, "BOOST_START_RADIUS_RATIO") == 1.25
assert constant(main, "BOOST_EXIT_RADIUS_RATIO") == 1.10
assert constant(main, "BOOST_CONFIRM_SECONDS") == 0.10
assert constant(main, "BOOST_ACCELERATION_SECONDS") == 0.15
assert constant(ui, "CONTROLLER_BOOST_KNOB_RADIUS_RATIO") == 1.48

# Numeric check of the exponential angle response, independent of Godot runtime.
for fps in (30, 60, 120, 144):
    delta = 1.0 / fps
    old_alpha = 1.0 - math.exp(-delta / 0.12)
    new_alpha = 1.0 - math.exp(-delta / 0.06)
    assert 0 < old_alpha < new_alpha < 1
    for old_angle, target in ((0.0, math.pi / 2), (0.0, math.pi),
                              (-math.pi / 2, math.pi / 2), (math.pi / 3, -math.pi / 2)):
        signed_delta = (target - old_angle + math.pi) % (2 * math.pi) - math.pi
        updated = old_angle + signed_delta * new_alpha
        assert abs(updated - old_angle) <= math.pi * new_alpha + 1e-12
assert abs((1.0 / 1.875) / (1.0 / 1.5) - 0.8) < 1e-12
print("v116 RUN 1.25x playback and quicker BOOST transitions: PASS")

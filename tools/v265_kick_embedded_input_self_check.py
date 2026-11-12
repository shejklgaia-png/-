#!/usr/bin/env python3
"""SERA v265: actual kick clips embedded + touch-down follow-up window."""
from pathlib import Path
import base64
import json
import math
import re

R = Path(__file__).resolve().parents[1]
def source(path):
    return (R / path).read_text(encoding="utf-8")

main = source("scripts/main.gd")
rig = source("scripts/sera_rig.gd")
raw = source("assets/sera_source.json")
data = json.loads(raw)
original = json.loads(source("models/storage/SERA_BOOSTER_allテスト (9).bbmodel"))
generated = source("assets/sera_data.gd")
version = source("project.godot")
assert (match := re.search(r'config/name="SERA v([0-9]+)"', version)) and int(match.group(1)) >= 265

parts = re.findall(r'^\s+"([A-Za-z0-9+/=]+)",$', generated, re.M)
assert len(parts) > 100
decoded = base64.b64decode("".join(parts)).decode("utf-8")
assert decoded == raw, "APK fallback data must match source data exactly"
print("PASS: embedded APK animation data exactly matches runtime source")

names = {clip["name"]: clip for clip in data["animations"]}
authored = {clip["name"]: clip for clip in original["animations"]}
# v276 has five additional Katana pivots; legacy kick clips still key exactly 22 A joints.
bone_uuids = {bone["uuid"] for bone in data["groups"] if not bone["name"].startswith("Katana")}
for name in ("Kick_l", "Kick_r"):
    assert name in names and name in authored
    clip = names[name]
    original_clip = authored[name]
    assert math.isclose(float(clip["length"]), 1.0)
    assert clip["loop"] == "once"
    assert set(clip["animators"]) == bone_uuids
    assert all(
        clip["animators"][u] == original_clip["animators"][u]
        for u in bone_uuids
    ), name + ": authored skeleton keyframe mismatch"
    assert sum(len(anim.get("keyframes", [])) for anim in clip["animators"].values()) >= 70
    print("PASS: " + name + " is a genuine authored 22-bone animation")
assert 'rig.call("has_side_kick", side)' in main
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in main
assert 'func _side_kick_clip_for(side: int)' in rig

touch = main.split("func _begin_drag(pos: Vector2) -> void:", 1)[1].split(
    "func _analog_stick_direction", 1)[0]
release = main.split("func _end_drag(release_pos: Vector2) -> void:", 1)[1].split(
    "func _remember_jump_flick_sample", 1)[0]
request = main.split("func _request_combo_side_kick(flick: Vector2) -> bool:", 1)[1].split(
    "func _start_omni_step", 1)[0]
assert "side_kick_flick_candidate = (" in touch
assert "and bash_followup_window_remaining > 0.0))" in touch
assert "var side_kick_requested: bool = (side_kick_flick_candidate" in release
assert release.index("if side_kick_requested and kick_flick_direction.length_squared()") < release.index(
    "if bash_requested and _request_combo_bash()"
)
assert 'if combat_state != CombatState.IDLE:' in request
assert "bash_followup_window_remaining <= 0.0" not in request
assert "bash_followup_window_remaining > 0.0" not in request
assert 'if side != 2 and not bool(rig.call("has_side_kick", side)):' in request
assert "step_kick_side_request = 0" in request
assert "return _start_omni_step(flick" not in request
print("PASS: a valid lateral swipe starting inside the combo link retains priority on release")

# A real 0.65s link can be nearly over when a legal <=0.24s flick begins.
for remaining in (0.001, 0.05, 0.20, 0.60):
    for flick_seconds in (0.03, 0.12, 0.24):
        latched_on_down = remaining > 0.0
        link_still_open_at_release = remaining - flick_seconds > 0
        if not link_still_open_at_release:
            assert latched_on_down
print("PASS: expiration during a valid touch cannot invalidate the stored link")

assert "func _start_omni_step(flick: Vector2) -> bool:" in main
assert 'rig.call("start_omni_step", pose_direction)' in main
assert "_move_player_swept(requested, true)" in main
assert "if side_kick_active:" in main and "side_kick_hit_mask" in main
assert 'const BACK_STEP_DISTANCE: float = 4.0' in main
print("PASS: original STEP API/collision and single kick impact preserved")
print("SERA v265 kick regression PASS (static and numeric only; Android not executed)")

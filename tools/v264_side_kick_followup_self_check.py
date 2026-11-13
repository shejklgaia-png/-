#!/usr/bin/env python3
"""SERA v264: guarded post-Melee3 lateral kick integration static regression."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import json
from sera_active_contracts import load_active_specs, main_float_constant

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
version = (ROOT / "project.godot").read_text(encoding="utf-8")
readme = (ROOT / "docs/history/release_notes/README_v264_ja.md").read_text(encoding="utf-8")
flick = (ROOT / "scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
source = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
author_file = ROOT / "models/storage/SERA_BOOSTER_allテスト (9).bbmodel"
author = json.loads(author_file.read_text(encoding="utf-8")) if author_file.exists() else None


def require(message: str, condition: bool) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


import re
require("game version is at least v264",
        bool((m := re.search(r'config/name="SERA v([0-9]+)"', version))
            and int(m.group(1)) >= 264))
require("versioned change notes exist", "3段完走後" in readme)
require("post-finisher and third-strike gesture windows",
        "side_kick_flick_candidate = (" in main
        and "combat_state == CombatState.STRIKE_TRACK" in main
        and "and bash_followup_window_remaining > 0.0))" in main)
require("post-finisher side flick takes priority over Bash",
        main.index("if side_kick_requested and kick_flick_direction.length_squared()")
        < main.index("if bash_requested and _request_combo_bash():"))
require("kick and step share the same start implementation",
        "func _start_omni_step(flick: Vector2) -> bool:" in main
        and "step_kick_side_request = side" in main)
require("single EN charge in shared STEP entry",
        main.count("func _start_omni_step(") == 1
        and "_spend_energy(15.0 * float(part_stats.get" in main)
require("kick sectors rotate with projected SERA facing",
        "func _combo_kick_side_for_flick(flick: Vector2) -> int:" in main
        and "return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)" in main
        and "flick, actor_screen_forward)" in SERA_INPUT
        and "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in main
        and "return 1" in SERA_INPUT
        and "return -1" in SERA_INPUT)
require("physics uses same swept STEP, not new teleport",
        "if side_kick_active:" in main and "side_kick_hit_mask" in main
        and "_move_player_swept(requested, true)" in main)
require("per-extension kick hits are each armed once",
        "side_kick_did_hit = true" in main
        and "func _register_side_kick_hit()" in main)
require("other directions retain normal step but lateral kick input is exclusive",
        'if side != 2 and not bool(rig.call("has_side_kick", side)):' in main
        and "if _start_omni_step(flick_direction):" in main
        and "_combo_kick_side_for_flick(kick_flick_direction) != 0" in main)
require("kick clip imports do not replace model or old animations",
        "func _merge_authored_side_kick_clips()" in rig
        and "if animations.has(name):" in rig
        and '_build_animations({"animations": kick_clips})' in rig)
require("invalid or zero-length clip does not enable kick",
        'float(clip.get("length", 0.0)) <= 0.01' in rig
        and 'if not (channels.get(channel, []) as Array).is_empty():' in rig)
require("kick animation time synchronized with step",
        'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in main
        and "playback_rate = side_kick_playback_scale" in rig)
require("kick state cleaned at STEP finish",
        "side_kick_active = false" in main
        and 'side_kick_clip_name = ""' in rig)
require("Bash and manual movement logic retained",
        "func _request_combo_bash()" in main
        and "func screen_step_direction" in flick)
spec = load_active_specs()
step_spec, kick_spec = spec["ordinary_step"], spec["side_kick"]
require("ordinary STEP and combo kick match the approved active specification",
        all(main_float_constant(main, name) == step_spec["distance_m"]
            for name in ("STEP_MIN_ARC_LENGTH", "STEP_MAX_ARC_LENGTH"))
        and main_float_constant(main, "STEP_SPEED") == step_spec["speed_mps"]
        and main_float_constant(main, "SIDE_KICK_STEP_SPEED") == kick_spec["speed_mps"]
        and main_float_constant(main, "SIDE_KICK_BOOST_DISTANCE") == kick_spec["distance_m"])

def matching_kicks(doc):
    return [a.get("name", "") for a in doc.get("animations", [])
            if any(word in a.get("name", "").lower()
                   for word in ("kick", "キック", "蹴"))]

source_clips = matching_kicks(source)
author_clips = matching_kicks(author) if author is not None else []
print(f"INFO: runtime source kick clips: {source_clips}")
print(f"INFO: newly synced Blockbench kick clips: {author_clips}")
if author is not None:
    require("uploaded Kick_l and Kick_r available",
            "Kick_l" in author_clips and "Kick_r" in author_clips)
    known = {g["uuid"] for g in source.get("groups", [])}
    for side in ("Kick_l", "Kick_r"):
        clip = next(x for x in author["animations"] if x["name"] == side)
        relevant = {uid: frames for uid, frames in clip["animators"].items()
                    if uid in known}
        require(f"{side} has keyframed runtime skeleton tracks",
                float(clip.get("length", 0.0)) > 0.01
                and len(relevant) >= 20
                and any(frames.get("keyframes") for frames in relevant.values()))
else:
    print("INFO: source file absent from feature branch; incoming main sync"
          " contributes it to the PR merge checkout.")
if not (source_clips or author_clips):
    print("INFO: missing asset uses safe ordinary STEP fallback.")
print("SERA v264 post-finisher lateral kick static regression PASSED.")

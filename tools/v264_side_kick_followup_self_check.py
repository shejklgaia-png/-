#!/usr/bin/env python3
"""SERA v264: guarded post-Melee3 lateral kick integration static regression."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
version = (ROOT / "project.godot").read_text(encoding="utf-8")
readme = (ROOT / "README_v264_ja.md").read_text(encoding="utf-8")
flick = (ROOT / "scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
source = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
author = json.loads(
    (ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8")
)


def require(message: str, condition: bool) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


require("game version is v264", 'config/name="SERA v264"' in version)
require("versioned change notes exist", "3段完走後" in readme)
require("post-finisher is the only candidate window",
        "side_kick_flick_candidate = (combat_state == CombatState.IDLE\n"
        "        and bash_followup_window_remaining > 0.0)" in main)
require("Bash retains priority over kick release",
        main.index("if bash_requested and _request_combo_bash():")
        < main.index("if side_kick_requested and flick_direction.length_squared()"))
require("kick and step share the same start implementation",
        "func _start_omni_step(flick: Vector2, kick_side: int = 0)" in main)
require("single EN charge in shared STEP entry",
        main.count("func _start_omni_step(") == 1
        and "_spend_energy(15.0 * float(part_stats.get" in main)
require("kick uses screen lateral sectors",
        "FLICK_DIRECTION_POLICY.sector_index(flick, Vector2.UP)" in main
        and "sector != 1 and sector != 3" in main)
require("physics uses same swept STEP, not new teleport",
        "if side_kick_active and not side_kick_did_hit" in main
        and "_move_player_swept(requested, true)" in main)
require("single-hit is armed once per kick",
        "side_kick_did_hit = true" in main
        and "func _register_side_kick_hit()" in main)
require("normal step remains fallback when clip missing",
        'if rig == null or not bool(rig.call("has_side_kick", side)):' in main
        and "if _start_omni_step(flick_direction):" in main)
require("kick clip imports do not replace model or old animations",
        "func _merge_authored_side_kick_clips()" in rig
        and "if animations.has(name):" in rig
        and '_build_animations({"animations": kick_clips})' in rig)
require("invalid or zero-length clip does not enable kick",
        'float(animations[chosen]["length"]) > 0.01' in rig
        and 'not (animations[chosen]["tracks"] as Dictionary).is_empty()' in rig)
require("kick animation time synchronized with step",
        'rig.call("start_side_kick", kick_side, step_duration_current)' in main
        and "playback_rate = side_kick_playback_scale" in rig)
require("kick state cleaned at STEP finish",
        "side_kick_active = false" in main
        and 'side_kick_clip_name = ""' in rig)
require("Bash and manual movement logic retained",
        "func _request_combo_bash()" in main
        and "func screen_step_direction" in flick)
require("STEP geometry and speed remain original",
        "const STEP_MIN_ARC_LENGTH: float = 2.0" in main
        and "const STEP_MAX_ARC_LENGTH: float = 4.0" in main
        and "const STEP_SPEED: float = 10.0" in main)

def matching_kicks(doc):
    return [a.get("name", "") for a in doc.get("animations", [])
            if any(word in a.get("name", "").lower()
                   for word in ("kick", "キック", "蹴"))]

source_clips = matching_kicks(source)
author_clips = matching_kicks(author)
print(f"INFO: runtime source kick clips: {source_clips}")
print(f"INFO: synced Blockbench kick clips: {author_clips}")
if not (source_clips or author_clips):
    print("INFO: authored kick clips not synced; safe STEP fallback remains active.")
print("SERA v264 post-finisher lateral kick static regression PASSED.")

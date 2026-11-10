#!/usr/bin/env python3
"""v204 static regression: heavy B/D SLIDE reuses directional BOOST poses without BOOST FX."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
stats = (ROOT / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")

match = re.search(r'    "legs": \{(.*?)\n    \},\n    "booster":', stats, re.S)
assert match, "Cannot locate leg stats"
legs = match.group(1)
for set_id, expected_weight, expected_motion in [
    ("A", "medium", "run"), ("B", "heavy", "slide"), ("D", "heavy", "slide")
]:
    match_part = re.search(rf'        "{set_id}": \{{(.*?)\}}', legs, re.S)
    assert match_part, f"Missing leg set {set_id}"
    body = match_part.group(1)
    assert f'"weight_class": "{expected_weight}"' in body, set_id
    assert f'"run_motion": "{expected_motion}"' in body, set_id

# C remains the standard A-profile fallback: it is a bird skeleton, not heavy.
assert 'options.get(set_id, options["A"])' in stats
assert 'rig.call("set_heavy_slide_run_enabled", str(part_stats.get("run_motion", "run")) == "slide")' in main
assert 'local_run_direction, movement_boost_active)' in main
assert 'var sliding: bool = moving and heavy_slide_run_enabled and not boost_input_active' in rig
assert 'var use_boost_pose: bool = boosting or sliding' in rig
assert 'wanted = BOOST_CLIP if use_boost_pose else RUN_CLIP' in rig
assert '_set_boost_motion_direction(local_direction)' in rig
assert 'locomotion_mode = "slide"' in rig
assert 'locomotion_mode = "boost"' in rig
assert '"legs": locomotion_mode == "slide" or locomotion_mode == "boost"' in rig
assert '"back": locomotion_mode == "boost"' in rig
# Afterimage emission is still from confirmed BOOST or a STEP, not clip selection.
assert 'blur_step_this_physics_frame or (combat_state == CombatState.IDLE' in main
assert 'and movement_boost_active and running)' in main
assert 'blur_step_this_physics_frame = stepping_this_frame and not damage_reaction_active' in main
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 204
print("SERA v204 heavy-leg slide source checks passed")

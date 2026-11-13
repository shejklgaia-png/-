#!/usr/bin/env python3
"""SERA v279: do not interrupt the final authored Kick_b pose before rendering."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT/"scripts/main.gd").read_text()
rig = (ROOT/"scripts/sera_rig.gd").read_text()
author = json.loads((ROOT/"models/storage/SERA_BOOSTER_allテスト (9) (2).bbmodel").read_text())
source = json.loads((ROOT/"assets/sera_source.json").read_text())
import re
assert int(re.search(r'config/name="SERA v(\d+)"', (ROOT/"project.godot").read_text()).group(1)) >= 279
assert next(x for x in source["animations"] if x["name"] == "Kick_b") == next(x for x in author["animations"] if x["name"] == "Kick_b")
assert "BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80" in main
assert "BACK_SOMERSAULT_DISTANCE: float = 5.0" in main
assert "BACK_SOMERSAULT_HEIGHT: float = 1.5" in main
assert "BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in main
assert 'rig.call("set_back_somersault_progress", pose_progress)' in main
assert 'rig.call("back_somersault_final_pose_sampled")' in main
assert 'if back_somersault_has_authored_clip and not bool(' in main
# v327: the final physical contact must always be on the floor, even
# when an earlier physics contact had raised the player above Y=0.
assert 'player.position.y = 0.0' in main.split("func _advance_back_somersault(",1)[1].split(
    "func _cancel_back_somersault(",1)[0]
assert 'rig.call("start_landing", from_back_somersault)' in main
assert 'func back_somersault_final_pose_sampled() -> bool:' in rig
assert 'clip_time = minf(duration * fraction, duration)' in rig
assert "duration - 0.0001" not in rig.split("func set_back_somersault_progress(",1)[1].split("func start_jump(",1)[0]
assert 'somersault_final_pose_sampled = false' in rig
assert 'and blend_weight >= 0.999999:' in rig
assert 'somersault_final_pose_sampled = true' in rig
assert '_switch_clip(JUMP_CLIP, 0.055 if from_back_somersault else 0.0)' in rig
assert '_begin_landing(true)' in main
print("V279_BACK_KICK_FULL_COMPLETION_STATIC_PASS")

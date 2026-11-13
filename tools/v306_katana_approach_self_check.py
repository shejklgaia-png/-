#!/usr/bin/env python3
"""v306: Katana uses frame-zero ready stance before the physical approach."""
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 306
assert 'const KATANA_APPROACH_BLEND_SECONDS: float = 0.20' in rig
assert 'rig.call("start_melee_approach", _katana_equipped())' in main
assert 'func start_melee_approach(katana_equipped: bool = false)' in rig
section = rig.split("func start_melee_approach(katana_equipped: bool = false)", 1)[1].split("func start_attack_windup", 1)[0]
for token in (
    'if katana_equipped and animations.has(KATANA_CLIP):',
    '_switch_clip(KATANA_CLIP, KATANA_APPROACH_BLEND_SECONDS)',
    'clip_time = 0.0',
    'freeze_attack_pose = true',
    'return blending_for >= KATANA_APPROACH_BLEND_SECONDS',
    'if current_clip == KATANA_CLIP and freeze_attack_pose:',
    '_switch_clip(MELEE_APPROACH_CLIP, 0.045)',
    'float(animations[MELEE_APPROACH_CLIP]["last_key_time"])',
):
    assert token in section, token
assert '_switch_clip(clip_name, 0.065)' in rig  # original strike start remains
assert 'if wanted == current_clip or not animations.has(wanted):' in rig
assert 'if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:' in main
assert 'if not _advance_homing_toward_target(boost_dt, MELEE_SURFACE_REACH):' in main
print("V306_KATANA_APPROACH_STATIC_PASS")

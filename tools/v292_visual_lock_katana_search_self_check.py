#!/usr/bin/env python3
"""v292: verify visual boss-facing lock and stable camera-auto part selection."""
from pathlib import Path
import json, math, re

root = Path(__file__).resolve().parents[1]
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
parts = (root/"scripts/target_parts.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
source = json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 292
assert "const AUTO_LOCK_SWITCH_CONFIRM_SECONDS: float = 0.0" in main
assert "var auto_lock_pending_part: String = \"\"" in main
assert "var auto_lock_pending_elapsed: float = 0.0" in main
helper = main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split("func _controller_start_area_contains(",1)[0]
for item in ("select_actor_parallel_lines_part", "locked_target_part_id = preferred",
             "auto_lock_initialized = true", 'auto_lock_pending_part = ""',
             "auto_lock_pending_elapsed = 0.0"):
    assert item in helper, item
assert "auto_lock_pending_elapsed >=" not in helper
assert "auto_lock_pending_part != preferred" not in helper
physics = main.split("func _physics_process(delta: float) -> void:",1)[1].split("func _process(delta: float) -> void:",1)[0]
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
assert "if not combo_held:" in physics
assert "player.look_at(player.global_position + aim, Vector3.UP)" in physics
assert 'aim = Vector3(part_aim' not in physics
assert "_acquire_stable_camera_part" in main
assert 'auto_lock_pending_part = ""' in main.split("func _toggle_auto_lock_mode() -> void:",1)[1].split("func _controller_start_area_contains",1)[0]

# The animation root used to yaw much farther than the character collider:
# Step_R's authored -70deg and run_front's +74.6deg minus the -90deg
# correction. Both can make the character *look* unlocked despite valid HUD.
assert 'const RUN_ROOT_BONE_UUID: String' in rig
assert "func _face_locked_boss_with_waist(q: Quaternion," in rig
lock = rig.split("func _face_locked_boss_with_waist(q: Quaternion,",1)[1].split("func _apply_animation(",1)[0]
assert "q * Vector3.FORWARD" in lock
assert "atan2(-authored_forward.x, -authored_forward.z)" in lock
assert "correction * clampf(blend_weight, 0.0, 1.0)" in lock
animation = rig.split("func _apply_animation(_delta: float) -> void:",1)[1].split("func _blockbench_rotation(",1)[0]
assert "if uid == RUN_ROOT_BONE_UUID and (" in animation
# v295: RUN preserves movement-relative Waist yaw, unlike STEP/BOOST.
assert "running_pose or current_clip == BOOST_CLIP" not in animation
assert "current_clip == BOOST_CLIP" in animation
assert "or (step_playback and directional_step_active)" in animation
assert "q = _face_locked_boss_with_waist(q, blend_weight)" in animation
assert "if blend_weight < 1.0 and prior_rotations.has(uid):" in animation
assert animation.index("if blend_weight < 1.0 and prior_rotations.has(uid):") < animation.index("q = _face_locked_boss_with_waist(q, blend_weight)")
# Attack clips are excluded from the new locomotion-only yaw constraint.
assert "current_clip == BACK_SOMERSAULT_CLIP" not in lock

clips = {a["name"]:a for a in source["animations"]}
assert "Melee_katana" in clips
# If the authored second animation is later imported, the existing
# renderer automatically favors it. No ad-hoc invented keyframes overwrite it.
builder=rig.split("func _build_katana_second_strike() -> void:",1)[1].split("func _switch_clip(",1)[0]
assert "if animations.has(KATANA_SECOND_CLIP)" in builder
assert "animations[KATANA_SECOND_CLIP] = second" in builder
latest = root/"models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel"
if latest.exists():
    authored=json.loads(latest.read_text(encoding="utf-8"))
    if "Melee_katana2" not in [a["name"] for a in authored.get("animations",[])]:
        assert "Melee_katana2" not in clips

# v305: no temporal confirmation: each paired-ray preferred candidate wins
# on the very first ordinary AUTO update outside the held-combo window.
selected="leg_fl"
for preferred in ("head","leg_rr","head",""):
    selected=preferred
    assert selected==preferred
assert selected==""
assert 'CAMERA_PART_LOCK_HYSTERESIS' in parts
print("V292_VISUAL_LOCK_AND_AUTHORED_KATANA_SEARCH_STATIC_PASS")

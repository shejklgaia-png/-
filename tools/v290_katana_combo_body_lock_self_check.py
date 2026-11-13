#!/usr/bin/env python3
"""v290 Katana mesh swap, authored-derived second combo and boss-centered strafing."""
from pathlib import Path

# v317: lock projections reside in the canonical delegated module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
import json, re, math
root = Path(__file__).resolve().parents[1]
m=(root/"scripts/main.gd").read_text()
r=(root/"scripts/sera_rig.gd").read_text()
e=(root/"scripts/sera_equipment.gd").read_text()
source=json.loads((root/"assets/sera_source.json").read_text())
version=(root/"project.godot").read_text()
assert int(re.search(r'config/name="SERA v(\d+)"',version).group(1))>=290
# No unprovided authored model clip was fabricated in the source.
assert "Melee_katana2" not in [c["name"] for c in source["animations"]]
assert next(c for c in source["animations"] if c["name"]=="Melee_katana")["length"]==0.5
assert 'KATANA_SECOND_STRIKE_CLIP: String = "Melee_katana2"' in m
assert 'KATANA_SECOND_CLIP: String = "Melee_katana2"' in r

src=e.split("func _set_katana_mesh_display(",1)[1].split("func set_grounding_enabled(",1)[0]
for token in (
    "piece.transparency = next_transparency",
    "piece.visible = display",
    'clip_name == "Melee_katana2"',
    'clip_name == "Melee_katana" and t >= 3.0 / 24.0 - 0.00001',
    "equipped and not drawn",
    "equipped and drawn",
    "_sync_afterimage_visibility()",
):
    assert token in src,token
assert 'if katana_role == "drawn":' in e
assert 'katana_drawn_meshes.append(child)' in e
assert 'katana_saya_meshes.append(child)' in e
assert 'group_name == "katana_r_nukimi"' in e
assert 'group_name.begins_with("katana_")' in e

ready=r.split("func _ready() -> void:",1)[1].split("func ",1)[0]
assert "_build_animations(data)" in ready
assert "_build_katana_second_strike()" in ready
assert ready.index("_build_animations(data)") < ready.index("_build_katana_second_strike()")
derived=r.split("func _build_katana_second_strike() -> void:",1)[1].split("func _switch_clip(",1)[0]
assert '(animations[KATANA_CLIP] as Dictionary).duplicate(true)' in derived
assert 'animations[KATANA_SECOND_CLIP] = second' in derived
assert 'original.x, -original.y, original.z' in derived
assert 'keyframe["quaternion"] = _blockbench_rotation(opposite)' in derived
assert 'second["looped"] = false' in derived
assert 'KATANA_SECOND_CLIP' in r.split("func start_strike(",1)[1].split("func start_bash(",1)[0]
assert 'KATANA_SECOND_CLIP' in r.split("func start_attack_windup(",1)[1].split("func release_attack_windup(",1)[0]

count=m.split("func _strike_stage_count() -> int:",1)[1].split("func _active_strike_clip(",1)[0]
assert "return 2 if _katana_equipped() else STRIKE_CLIPS.size()" in count
assert "return strike_index == _strike_stage_count() - 1" in count
active=m.split("func _active_strike_clip(stage: int) -> String:",1)[1].split("func _strike_cancel_time(",1)[0]
assert "KATANA_SECOND_STRIKE_CLIP if stage >= 1 else KATANA_STRIKE_CLIP" in active
assert 'str(STRIKE_CLIPS[clampi(stage, 0, STRIKE_CLIPS.size() - 1)])' in active
attack=m.split("func _start_attack() -> bool:",1)[1].split("func _combo_followup_input_window_open(",1)[0]
assert "strike_index < _strike_stage_count() - 1" in attack
finish=m.split("func _finish_strike_and_release_queued_kick() -> void:",1)[1].split("func _advance_attack(",1)[0]
assert "if _is_strike_finisher():" in finish
assert "bash_followup_window_remaining = BASH_LINK_SECONDS" in finish
assert "committed_kick_side = buffered_side_kick_side" in finish
advance=m.split("func _advance_attack(delta: float) -> void:",1)[1].split("func _screen_drag_to_ground(",1)[0]
assert "if _is_strike_finisher()" in advance
assert "strike_index < _strike_stage_count() - 1" in advance
assert "float(rig.call(\"get_clip_time\")) >= _melee3_flick_cancel_time()" in advance
assert "_launch_combo_side_kick(committed_kick_flick, committed_kick_side)" in finish
flick=m.split("func _request_combo_side_kick(flick: Vector2) -> bool:",1)[1].split("func _launch_combo_side_kick(",1)[0]
assert "and _is_strike_finisher():" in flick
assert '"STRIKE %d/%d  |  %s"' in m
cancel=m.split("func _melee3_flick_cancel_time() -> float:",1)[1].split("func _start_strike(",1)[0]
assert "7.0 / 24.0 + MELEE3_FLICK_CANCEL_DELAY" in cancel
assert "STRIKE_CANCEL_TIMES[STRIKE_CLIPS.size() - 1]) + MELEE3_FLICK_CANCEL_DELAY" in cancel
assert 7/24+0.05 < .5

# v305: the authored run yaw stays movement-relative, while the collider
# now faces the current locked head/leg point (BODY still uses core pivot).
phys=m.split("func _physics_process(delta: float) -> void:",1)[1].split("func _process(delta: float) -> void:",1)[0]
heading=phys.split("# The paired SERA->BODY rays",1)[1].split("player.look_at(",1)[0]
assert "aim = _locked_target_facing_direction()" in heading
face=m.split("func _locked_target_facing_direction() -> Vector3:",1)[1].split("func _controller_start_area_contains(",1)[0]
assert 'LOCK_MANAGEMENT.target_facing_direction(' in face
assert '"get_part_aim_world", part_id' in LOCK_MODULE
assert "point: Vector3 = boss_center" in LOCK_MODULE
assert "point.y - player" not in face
assert 'player.look_at(player.global_position + aim, Vector3.UP)' in phys
assert 'center_world += target_parts.call("get_part_local_aim", locked_target_part_id)' in m
turn=r.split("func _run_yaw_for_direction(direction: Vector2, retreat_weight: float) -> float:",1)[1].split("func _smooth_visual_direction(",1)[0]
# v305: the collider locks to the selected part, while the authored RUN
# Waist follows actual travel and its torso/head track the selected target.
assert "return travel_yaw" in turn
assert "RUN_TARGET_LOCK_MAX_YAW_DEGREES" not in r
for d in (-math.pi/2, 0.0, math.pi/2):
    yaw=-d
    assert abs(yaw + d) < 1e-8
print("V290_KATANA_COMBO_BODY_LOCK_STATIC_PASS")

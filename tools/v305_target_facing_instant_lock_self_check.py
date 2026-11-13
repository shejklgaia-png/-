#!/usr/bin/env python3
"""v305: immediate paired-ray AUTO and facing selected part rather than BODY."""
from pathlib import Path

# v317: AUTO state remains in main; paired-ray selection moved to a pure module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
import re
R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
parts=(R/"scripts/target_parts.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
manifest=(R/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1)) >= 305
assert (R/"README_v305_ja.md").is_file()
assert "const AUTO_LOCK_SWITCH_CONFIRM_SECONDS: float = 0.0" in main
auto=main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "# v305: yaw SERA toward the actual current LOCK target.",1)[0]
for term in (
    'LOCK_MANAGEMENT.select_auto_part(',
    "target_parts, player.global_position, target.global_position",
    "locked_target_part_id = LOCK_MANAGEMENT.select_auto_part(",
    "auto_lock_initialized = true",
    'auto_lock_pending_part = ""',
    "auto_lock_pending_elapsed = 0.0",
):
    assert term in auto,term
for term in (
    "AUTO_LOCK_SWITCH_CONFIRM_SECONDS", "current_on_line",
    "auto_lock_pending_part != preferred",
    "auto_lock_pending_elapsed +=",
    "actor_parallel_lines_hits_part",
):
    assert term not in auto,term

face=main.split("func _locked_target_facing_direction() -> Vector3:",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert 'LOCK_MANAGEMENT.target_facing_direction(' in face
assert 'locked_target_part_id)' in face
assert 'var point: Vector3 = boss_center' in LOCK_MODULE
assert 'not part_id.is_empty()' in LOCK_MODULE
assert '"get_part_aim_world", part_id' in LOCK_MODULE
assert 'point.x - player_world.x, 0.0,' in LOCK_MODULE
assert 'point.z - player_world.z' in LOCK_MODULE
assert "get_part_aim_world(id: String) -> Vector3:" in parts

phys=main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(delta: float) -> void:",1)[0]
assert "var combo_held: bool = _combo_lock_retention_active()" in phys
assert "if not combo_held:" in phys
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in phys
assert "manual_part_lock_active" in phys
assert "aim = _locked_target_facing_direction()" in phys
assert 'player.look_at(player.global_position + aim, Vector3.UP)' in phys
assert phys.index("aim = _locked_target_facing_direction()") > phys.index(
    "_acquire_stable_camera_part(delta, locked_part_broken)")
assert 'if aim.length_squared() > 0.000001:' in phys
assert "var target_forward: Vector3 = _locked_target_facing_direction()" in phys
motion=(R/"scripts/sera_motion_direction.gd").read_text(encoding="utf-8")
assert "var local_run_direction: Vector2 = MOTION_DIRECTION.local_run_direction(" in phys
assert "world_move, target_forward, -player.global_transform.basis.z)" in phys
assert "world_move.dot(facing.cross(Vector3.UP))" in motion
assert "world_move.dot(facing)" in motion
assert "if facing.length_squared() < 0.000001:" in motion
assert "target.position.x - player.position.x" not in phys[
    phys.index("var target_forward: Vector3"):phys.index("var local_run_direction: Vector2")]

assert 'func select_actor_parallel_lines_part(' in parts
assert 'func _parallel_lock_part_distance(' in parts
assert "const CAMERA_LOCK_VOLUME_SCALE: float = 1.15" in parts
assert 'lock_lines_button.name = "LockLinesVisibility"' in main
for path in (
    "py tools/v305_target_facing_instant_lock_self_check.py",
    "gd tools/v305_target_facing_instant_lock_runtime_check.gd"
):
    assert path in manifest,path
print("V305_TARGET_FACING_INSTANT_LOCK_STATIC_PASS")

# The authoritative selection API is still the same actor-origin dual-line method.
assert '"select_actor_parallel_lines_part", actor_origin, target_center' in LOCK_MODULE

#!/usr/bin/env python3
"""v315: a swept 1m pre-step warp, fixed 5m total, 50ms anchored launch FX."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
main=(r/"scripts/main.gd").read_text(encoding="utf-8")
rig=(r/"scripts/sera_rig.gd").read_text(encoding="utf-8")
eq=(r/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
project=(r/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v315"',project)
for token in ('const STEP_LAUNCH_WARP_DISTANCE: float = 1.0',
              'const STEP_LAUNCH_FX_SECONDS: float = 0.05',
              'const STEP_SIDE_DISTANCE: float = 5.0',
              'const STEP_SPEED: float = 15.0'):
    assert token in main,token
ordinary=main.split('func _start_omni_step(flick: Vector2) -> bool:',1)[1].split(
    'func _start_back_step()',1)[0]
assert ordinary.index('rig.call("capture_step_launch_afterimage", STEP_LAUNCH_FX_SECONDS)') < ordinary.index(
    '_move_player_swept(world_step.normalized() * minf(')
assert ordinary.index('rig.call("spawn_step_launch_flare", world_step, STEP_LAUNCH_FX_SECONDS)') < ordinary.index(
    '_move_player_swept(world_step.normalized() * minf(')
assert ordinary.index('if side_kick_active:') < ordinary.index(
    'rig.call("capture_step_launch_afterimage", STEP_LAUNCH_FX_SECONDS)')
for token in ('_move_player_swept(world_step.normalized() * minf(',
              'STEP_LAUNCH_WARP_DISTANCE, step_arc_length), false)',
              'step_traveled_distance = launch_distance',
              'step_elapsed = step_duration_current * clampf(',
              'launch_distance / maxf(step_arc_length, 0.0001)',
              'player.reset_physics_interpolation()'):
    assert token in ordinary,token
assert 'func capture_step_launch_afterimage(lifetime: float) -> void:' in rig
assert '_emit_motion_afterimage(true)' in rig.split(
    'func capture_step_launch_afterimage(lifetime: float) -> void:',1)[1].split(
    'func spawn_step_launch_flare(',1)[0]
assert 'maxf(0.001, lifetime)' in rig
fx=eq.split('func spawn_step_launch_flare(world_travel: Vector3, lifetime: float) -> void:',1)[1].split(
    'func update_back_thruster_fx(',1)[0]
for token in ('back_thruster_effects.get(selected_booster, [])',
              'var world_parent: Node3D = player_body.get_parent() as Node3D',
              'Basis.looking_at(', 'source_mesh.mesh',
              'source_material.duplicate()', 'set_shader_parameter("burst", 1.0)',
              'set_shader_parameter("strength", 1.0)',
              'frozen.global_transform = Transform3D(nozzle_basis, source_fx.global_position)',
              'create_timer(maxf(lifetime, 0.001)).timeout.connect('):
    assert token in fx,token
assert (r/"README_v315_ja.md").exists()
print("V315_STEP_WARP_AND_FIXED_LAUNCH_FX_STATIC_PASS")

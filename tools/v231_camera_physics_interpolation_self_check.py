#!/usr/bin/env python3
"""SERA v231: verify 60-Hz physics actors and render-camera interpolation."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 231

# The interpolation switch is local to the training scene, and is restored
# when returning to Nexus. It must not globally re-time keyframed menus.
ready = main.split("func _ready() -> void:", 1)[1].split("func _notification(", 1)[0]
assert '_previous_physics_interpolation = get_tree().physics_interpolation' in ready
assert 'get_tree().physics_interpolation = true' in ready
assert 'physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF' in ready
assert 'get_tree().physics_interpolation = _previous_physics_interpolation' in ready

# Physics actors + their floor marks get world-space interpolation, while
# authored rig joints and manually updating camera don't receive a second
# interpolation layer. Floor-stage tile origin also stays uninterpolated.
build_player = main.split("func _build_character() -> void:", 1)[1].split("func _build_target() -> void:", 1)[0]
build_target = main.split("func _build_target() -> void:", 1)[1].split("func _build_enemy_shooter()", 1)[0]
build_camera = main.split("func _build_camera() -> void:", 1)[1].split("func _build_overlay()", 1)[0]
assert 'player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in build_player
assert 'rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF' in build_player
assert 'player_floor_mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in build_player
assert 'target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in build_target
assert 'target_floor_mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON' in build_target
assert 'camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF' in build_camera
assert 'floor_stage.position = Vector3(' in main

# Exactly one sampled interpolation transform per actor per render frame.
render = main.split("func _process(delta: float) -> void:", 1)[1].split(
    "func _close_step_target_relative_yaw", 1)[0]
assert render.count('player.get_global_transform_interpolated().origin') == 1
assert render.count('target.get_global_transform_interpolated().origin') == 1
assert 'camera_player_render_position.x - camera_target_render_position.x' in render
assert 'camera_player_render_position.z - camera_target_render_position.z' in render
assert render.index('camera_player_render_position =') < render.index('var radial: Vector2')
assert 'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)' in render

# Every render-camera safety/projection path must use those same samples,
# instead of mixing fixed-physics player positions with interpolated visuals.
functions = {
    name: main.split('func ' + name + '(', 1)[1].split('\nfunc ', 1)[0]
    for name in ('_update_side_from_screen', '_signed_screen_gap',
                 '_place_camera', '_horizontal_safe',
                 '_target_fully_in_frame', '_full_frame_safe',
                 '_update_target_marker_projection')
}
assert 'camera_player_render_position' in functions['_update_side_from_screen']
assert 'camera_player_render_position' in functions['_signed_screen_gap']
assert 'camera_target_render_position' in functions['_signed_screen_gap']
assert 'camera_focus_follow_xz' in functions['_place_camera']
assert '_advance_camera_follow_focus(delta)' in render
assert 'camera_player_render_position' in functions['_desired_camera_follow_focus_xz']
assert 'camera_target_render_position' in functions['_desired_camera_follow_focus_xz']
assert 'camera_player_render_position' in functions['_horizontal_safe']
assert 'camera_target_render_position' in functions['_target_fully_in_frame']
assert 'camera_player_render_position' in functions['_full_frame_safe']
assert 'camera_target_render_position' in functions['_update_target_marker_projection']
for name in ('_update_side_from_screen', '_signed_screen_gap',
             '_place_camera','_horizontal_safe','_target_fully_in_frame','_full_frame_safe'):
    assert 'player.global_position' not in functions[name], name

# Target bob and motion must both be fixed-timestep when target is
# interpolated. Previously the bob lived in _process and caused mixed
# update clocks. Training teleports must clear interpolation history.
physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(delta: float) -> void:", 1)[0]
assert 'target.position.y = TARGET_BASE_HEIGHT + sin(elapsed * 1.4) * 0.07' in physics
assert 'target.position.y = TARGET_BASE_HEIGHT + sin(elapsed * 1.4) * 0.07' not in render
assert 'player.reset_physics_interpolation()' in main
assert 'target.reset_physics_interpolation()' in main
assert 'func _screen_drag_to_ground(screen_drag: Vector2) -> Vector3:' in main
assert 'player.velocity = world_move * float(part_stats.get("run_speed", 4.0625)) * boost_speed_multiplier' in main
assert 'func _enforce_screen_edge(bearing: float, delta: float)' in main
assert 'const CAMERA_CLOSE_BOOST_ENTER_DISTANCE: float = 6.0' in main

# Fixed physics clock sampled by a higher-refresh camera gives zero-velocity
# frames and larger jumps without interpolation. Linear interpolation removes
# this artificial cadence while leaving the exact physics trajectory intact.
physics_hz, render_hz, speed, duration = 60, 113, 6.0, 2.0
t_samples = [i/render_hz for i in range(int(duration*render_hz))]
stepped = [math.floor(t*physics_hz)/physics_hz*speed for t in t_samples]
interpolated = [t*speed for t in t_samples]
s_deltas = [stepped[i+1]-stepped[i] for i in range(len(stepped)-1)]
i_deltas = [interpolated[i+1]-interpolated[i] for i in range(len(interpolated)-1)]
assert any(math.isclose(x,0.0,abs_tol=1e-12) for x in s_deltas)
assert max(s_deltas) > 1.5*min(i_deltas)
assert max(i_deltas)-min(i_deltas) < 1e-11
print("PASS v231: interpolated actor + camera render samples, scoped lifecycle, fixed-tick target, teleport reset")

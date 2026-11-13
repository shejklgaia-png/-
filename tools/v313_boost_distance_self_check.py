#!/usr/bin/env python3
"""v313: manual RUN/BOOST hold has one 5m path budget; 7m STEP unchanged."""
from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]
s=(p/"scripts/main.gd").read_text(encoding="utf-8")
v=(p/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',v).group(1))>=313
assert 'const BOOST_TRAVEL_DISTANCE: float = 5.0' in s
assert 'var boost_distance_traveled: float = 0.0' in s
assert 'var boost_distance_capped: bool = false' in s
gesture=s.split('func _update_boost_gesture(delta: float) -> void:',1)[1].split('func _end_drag(',1)[0]
for token in ('if boost_distance_capped:',
              'if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:',
              'boost_distance_capped = false',
              'boost_confirm_elapsed = 0.0\n            return',
              'boost_distance_traveled = 0.0',
              'boost_has_activated_this_gesture = true'):
    assert token in gesture,token
physics=s.split('func _physics_process(delta: float) -> void:',1)[1]
for token in ('var boosted_travel_this_frame: bool = movement_boost_active and running',
              'var boost_start_position: Vector3 = player.global_position',
              'var budget_remaining: float = maxf(0.0, BOOST_TRAVEL_DISTANCE - boost_distance_traveled)',
              'player.velocity = player.velocity.limit_length(budget_remaining / delta)',
              'boost_displacement.y = 0.0',
              'boost_distance_traveled + boost_displacement.length()',
              'boost_distance_capped = true',
              'movement_boost_active = false'):
    assert token in physics,token
assert 'const STEP_SIDE_DISTANCE: float = 7.0' in s
assert 'const STEP_SPEED: float = 15.0' in s
assert 'const SIDE_KICK_BOOST_DISTANCE: float = 3.0' in s
assert 'const BOOST_SPEED_BLEND_SECONDS: float = 0.20' in s
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in s
assert (p/"README_v313_ja.md").is_file()
print("V313_BOOST_5M_ALL_DIRECTION_STATIC_PASS")

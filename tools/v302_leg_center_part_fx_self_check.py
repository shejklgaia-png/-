#!/usr/bin/env python3
"""v302: mid-leg aim; strict per-part material/rig + hit-spark depth isolation."""
from pathlib import Path
import re

R=Path(__file__).resolve().parents[1]
read=lambda p:(R/p).read_text(encoding="utf-8")
part,main,burst,project,manifest = [read(x) for x in (
    "scripts/target_parts.gd","scripts/main.gd","scripts/hit_burst.gd",
    "project.godot","tools/sera_ci_manifest.txt")]
assert re.search(r'config/name="SERA v302"',project)
assert (R/"README_v302_ja.md").is_file()
for label in ("leg_fl","leg_fr","leg_rl","leg_rr"):
    declaration=part.split('_add_part("'+label+'"',1)[1].split('100.0,',1)[0]
    assert 'Vector3.ZERO,' in declaration,(label,declaration)
    assert declaration.count("Vector3(")==2, (label,declaration)
head=part.split('_add_part("head",',1)[1].split('100.0,',1)[0]
assert 'Vector3(0.0, -0.03, 0.37)' in head
assert 'return node.to_global(parts[id]["aim"])' in part
assert 'return node.position + part["aim"]' in part

fx=main.split('func _apply_target_part_damage(',1)[1].split(
    'func _register_strike_hit(',1)[0]
assert 'target_parts.call("trigger_part_hit_fx",' in fx
assert 'HIT_FLASH_SECONDS if locked_target_part_id.is_empty() else 0.0' in fx
assert 'hit_flash_remaining = (' in fx
# The original BODY timer must not get restarted by individual callers,
# including Bash or kicks (or a broken held lock during the combo).
for start,end in (
    ('func _register_strike_hit(', 'func _register_side_kick_hit('),
    ('func _register_side_kick_hit(', 'func _part_hit_surface('),
    ('func _register_bash_hit(', 'func _update_melee_lock_marker('),
):
    section=main.split(start,1)[1].split(end,1)[0]
    assert 'hit_flash_remaining = HIT_FLASH_SECONDS' not in section
    assert '_apply_target_part_damage(' in section
    assert 'impact_origin = _part_hit_surface(' in section
    assert ('_spawn_sparks(impact_origin)' in section
            or 'hit_burst.call("start_burst", impact_origin,' in section)

advance=main.split('func _advance_hit_fx(delta: float) -> void:',1)[1].split(
    'func _input(',1)[0]
assert '"advance_part_hit_fx", delta' in advance
assert 'target_mesh.position = Vector3.ZERO' in advance
assert 'target_mesh.rotation_degrees.z = 0.0' in advance
assert 'target_mesh.position.x = sin(' not in advance
assert 'target_mesh.rotation_degrees.z = sin(' not in advance
assert 'target_material.albedo_color = Color("e53935").lerp(' in advance
local=part.split('func _set_part_hit_visual(id: String, ratio: float) -> void:',1)[1].split(
    'func advance_part_hit_fx(',1)[0]
assert 'var part: Dictionary = parts[id]' in local
assert 'var material: StandardMaterial3D = part[slot]' in local
assert 'var pivot: Node3D = part["node"]' in local
assert 'pivot.position = (part["rest_position"] as Vector3)' in local
assert '_set_part_hit_visual(id, remaining / float(part["hit_fx_duration"]))' in part
assert 'var shell: StandardMaterial3D = _make_material(color)' in part
assert 'var accent: StandardMaterial3D = _make_material(Color("5d4140"))' in part

# The impact spark plane must be at the *part* surface rather than the
# boss center, which was visually spreading all hits across the core.
draw=burst.split('func _redraw() -> void:',1)[1]
assert 'var center_world: Vector3 = origin' in draw
assert 'target_node.global_position if target_node != null else origin' not in draw
assert 'var target_depth: float = (center_world - view_camera.global_position).dot(' in draw
assert 'var depth: float = maxf(view_camera.near + 0.01, target_depth - FRONT_OFFSET)' in draw
assert 'const FRONT_OFFSET: float = 0.06' in burst
assert '_spark(i, spawn, depth, scale_factor)' in draw
assert 'var visible: Vector3 = hit.clamp(box.position, box.end)' in main

for entry in ("py tools/v302_leg_center_part_fx_self_check.py",
              "gd tools/v302_leg_center_part_fx_runtime_check.gd"):
    assert entry in manifest,entry
print("V302_LEG_CENTER_PART_FX_STATIC_PASS")

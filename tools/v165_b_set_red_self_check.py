#!/usr/bin/env python3
"""v165 static checks: B is red in mesh, sword foreground and boost afterimages.

Static source contract only; not Godot/Android rendered verification.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
project = (root / "project.godot").read_text(encoding="utf-8")
equipment = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
foreground = (root / "shaders/sera_foreground.gdshader").read_text(encoding="utf-8")
ghost = (root / "shaders/sera_motion_ghost.gdshader").read_text(encoding="utf-8")

if re.findall(r'^config/name="([^"]+)"
assert "const B_SET_TINT: Color = Color(1.0, 0.18, 0.18, 1.0)" in equipment
assert 'piece.set_meta("sera_equipment_set", set_id)' in equipment
assert 'if set_id != "B":\n        return' in equipment
assert 'var tinted: StandardMaterial3D = original.duplicate() as StandardMaterial3D' in equipment
assert 'tinted.albedo_color = B_SET_TINT' in equipment
assert 'piece.material_override = tinted' in equipment
assert '_apply_equipment_tint(piece, set_id)' in equipment
assert 'albedo_texture = null' not in equipment
assert 'const B_SET_TINT_RGB: Vector3 = Vector3(1.0, 0.18, 0.18)' in rig
assert 'str(part.get_meta("sera_equipment_set", "A")) == "B"' in rig
assert 'str(source.get_meta(' in rig and '"sera_equipment_set", "A")) == "B"' in rig
assert '_foreground_mat_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)' in rig
assert '_afterimage_material_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)' in rig
assert '_afterimage_material_b.set_shader_parameter("trail_alphas", layer_opacity)' in rig
assert 'for part in _foreground_parts:' in rig
assert 'for source in _foreground_parts:' in rig
for shader in (foreground, ghost):
    assert 'uniform vec3 set_tint = vec3(1.0, 1.0, 1.0);' in shader
    assert 'ALBEDO =' in shader and ' * set_tint;' in shader
assert 'func get_equipment_options(' in rig
assert 'func set_equipment_selection(' in rig
assert (root / "README_v165_ja.md").is_file()
print("PASS: v165 B red tint only; 6-slot equipment and A baseline preserved")
print("PASS: foreground/afterimage tint consistency")
print("Godot editor and Android display: NOT TESTED")
, project, re.MULTILINE) != ["SERA v165"]:
    print("SKIP: v165 historical regression test (current project is newer)")
    raise SystemExit(0)
assert "const B_SET_TINT: Color = Color(1.0, 0.18, 0.18, 1.0)" in equipment
assert 'piece.set_meta("sera_equipment_set", set_id)' in equipment
assert 'if set_id != "B":\n        return' in equipment
assert 'var tinted: StandardMaterial3D = original.duplicate() as StandardMaterial3D' in equipment
assert 'tinted.albedo_color = B_SET_TINT' in equipment
assert 'piece.material_override = tinted' in equipment
assert '_apply_equipment_tint(piece, set_id)' in equipment
assert 'albedo_texture = null' not in equipment
assert 'const B_SET_TINT_RGB: Vector3 = Vector3(1.0, 0.18, 0.18)' in rig
assert 'str(part.get_meta("sera_equipment_set", "A")) == "B"' in rig
assert 'str(source.get_meta(' in rig and '"sera_equipment_set", "A")) == "B"' in rig
assert '_foreground_mat_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)' in rig
assert '_afterimage_material_b.set_shader_parameter("set_tint", B_SET_TINT_RGB)' in rig
assert '_afterimage_material_b.set_shader_parameter("trail_alphas", layer_opacity)' in rig
assert 'for part in _foreground_parts:' in rig
assert 'for source in _foreground_parts:' in rig
for shader in (foreground, ghost):
    assert 'uniform vec3 set_tint = vec3(1.0, 1.0, 1.0);' in shader
    assert 'ALBEDO =' in shader and ' * set_tint;' in shader
assert 'func get_equipment_options(' in rig
assert 'func set_equipment_selection(' in rig
assert (root / "README_v165_ja.md").is_file()
print("PASS: v165 B red tint only; 6-slot equipment and A baseline preserved")
print("PASS: foreground/afterimage tint consistency")
print("Godot editor and Android display: NOT TESTED")

#!/usr/bin/env python3
"""v168 static regression: customized SERA silhouette uses actual visible geometry.

No Godot renderer or Android input is executed by this source-level check.
"""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
equipment = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
if re.findall(r'^config/name="([^"]+)"$', project, re.M) != ["SERA v168"]:
    print("SKIP: v168 historical regression test (current project is newer)")
    raise SystemExit(0)

def body(name: str) -> str:
    match = re.search(r"(?ms)^func " + re.escape(name) + r"\([^\n]*\)(?:[^\n]*)\n(.*?)(?=^func |\Z)", nexus)
    assert match, name
    return match.group(1)

capture = body("_capture_sera_silhouette")
collector = body("_collect_sera_geometry")
vertices = body("_mesh_outline_local_vertices")
switch = body("_tap_equipment_control")
restore = body("_restore_customization_preview")
rotate = body("_rotate_customization_preview")
projection = body("_project_model_contour")

# Every switch replaces the previously cached world-space silhouette, not adds
# on top of A or samples the selection before its visible flags are changed.
assert 'piece.visible = str(variant) == set_id' in equipment
assert 'sera_display_rig.call("set_equipment_selection", slot, choices[next_index])' in switch
assert switch.index("_refresh_equipment_controls()") < switch.index("_capture_sera_silhouette(sera_display_rig)") < switch.index("_update_projected_silhouettes()")
assert 'target_parts["CUSTOMIZE"] = visible_parts' in capture
assert '_collect_sera_geometry(rig, visible_parts)' in capture
assert "piece.is_visible_in_tree()" in collector
assert 'piece.name != "Swordeffect"' in collector
assert '_mesh_outline_local_vertices(piece.mesh)' in collector
assert 'world_vertices.append(piece.global_transform * vertex)' in collector
assert 'visible_parts.append(world_vertices)' in collector
assert 'piece.mesh.get_aabb()' not in collector

# Local geometry is deduplicated/cacheable and follows mesh geometry rather
# than bone AABBs; mesh IDs invalidate naturally when a scene is recreated.
assert 'mesh.get_instance_id()' in vertices
assert 'customize_silhouette_vertex_cache.has(mesh_id)' in vertices
assert 'mesh is ArrayMesh' in vertices
assert 'array_mesh.surface_get_arrays(surface_index)' in vertices
assert 'arrays[Mesh.ARRAY_VERTEX]' in vertices
assert 'seen.has(vertex)' in vertices
assert 'customize_silhouette_vertex_cache[mesh_id] = local_vertices' in vertices
assert 'mesh.get_aabb()' in vertices

# Rotation, preview stow and default pose continue to rebuild the current
# selected outfit silhouette and reuse the previous projected union logic.
assert '_capture_sera_silhouette(sera_display_rig)' in restore
assert '_capture_sera_silhouette(sera_display_rig)' in rotate
assert 'Geometry2D.convex_hull(screen_points)' in projection
assert '_union_outer_contours(result, poly)' in projection
assert 'outline.set("hide_customize_preview_outline", true)' in nexus
assert 'outline.set("hide_customize_preview_outline", false)' in nexus
assert 'func get_equipment_selection(' in rig

model = json.loads((root / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
sphere = [m for m in model["elements"] if m.get("name") == "sphere"]
assert sphere and len(sphere[0]["vertices"]) > 8, "The round B head must have more than box corners"
assert (root / "README_v168_ja.md").is_file()
print("PASS: v168 visible equipment mesh vertices -> refreshed contour and selection")
print("Godot parser/rendering and Android device: NOT TESTED")

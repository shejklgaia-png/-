#!/usr/bin/env python3
"""No-CI static check for NEXUS-only HEAD D visible-mesh ID-outline prototype.

Run manually in a checkout: python3 tools/iris_id_visible_outline_local_check.py
This does NOT prove the GL shader compiles, nor measure real Android FPS.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
read = lambda path: (root / path).read_text(encoding="utf-8")
model = json.loads(read("models/storage/カメラアイ頭部.bbmodel"))
assert len(model["elements"]) == 6
assert all(e.get("visibility") is not False for e in model["elements"])
assert len(model["textures"]) == 1
assert model["textures"][0]["source"].startswith("data:image/png;base64,")

widget = read("scripts/sera_part_preview_widget.gd")
nexus = read("scripts/command_nexus.gd")
layer = read("scripts/sera_iris_id_silhouette_preview.gd")
canvas = read("shaders/sera_iris_mesh_id_outline.gdshader")
closed = read("shaders/sera_iris_mesh_id_closed.gdshader")
opened = read("shaders/sera_iris_mesh_id_open.gdshader")
assert 'const IrisIDContour = preload(' in widget
assert 'enable_nexus_iris_id_contour: bool = false' in widget
assert 'current_blueprint == "H02"' in widget
assert 'customize_single_part_preview.enable_nexus_iris_id_contour = true' in nexus
assert '"head", "D"' in layer
assert 'float(index + 1) / 8.0' in layer
assert 'source.mesh' in layer and 'clone.global_transform = source.global_transform' in layer
assert 'source_preview.get("camera")' in layer
assert 'source.visible and source.is_visible_in_tree()' in layer
assert 'source.get_node_or_null(' in layer and '"SeraEdgeInk"' in layer
assert 'id_viewport.own_world_3d = true' in layer
assert 'id_viewport.msaa_3d = Viewport.MSAA_DISABLED' in layer
assert 'SubViewport.UPDATE_ONCE' in layer
assert 'SubViewport.UPDATE_ALWAYS' not in layer
assert 'SubViewport.UPDATE_DISABLED' in layer
assert 'id_viewport.size = new_size' in layer
assert 'set_process(false)' in layer and 'set_process(true)' in layer
assert 'TextureRect.STRETCH_SCALE' in layer
assert 'CanvasItem.TEXTURE_FILTER_NEAREST' in layer
assert 'stroke_px", 3.0)' in layer
assert 'Color("#17212f")' in layer
assert 'render_mode unshaded, cull_front, depth_draw_opaque;' in closed
assert 'render_mode unshaded, cull_disabled, depth_draw_opaque;' in opened
assert 'render_mode' not in canvas or 'shader_type canvas_item' in canvas
assert 'TEXTURE_PIXEL_SIZE' in canvas
assert 'mismatched_id' in canvas
assert 'neighbor_id + 0.05 < center_id' in canvas
assert 'if (id < 0.06)' in canvas
assert 'COLOR = edge ? ink_color : vec4(0.0);' in canvas
assert 'for (int r = 1; r <= 3; r++)' in canvas
# Other systems untouched: no new blanket replacement of SeraViewEdges.
assert 'const INK_SHADER = preload("res://shaders/sera_view_edges.gdshader")' in read(
    "scripts/sera_view_edges.gd")
assert 'SERA_INTAKE_PREVIEW' in read("tools/equipment_intake/godot_preview.gd")
print("IRIS_ID_VISIBLE_OUTLINE_LOCAL_STATIC_PASS / H02 only / 6 IDs / 3px / no CI")

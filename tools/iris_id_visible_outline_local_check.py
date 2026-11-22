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
assert 'uniform sampler2D mesh_id_texture' in canvas
assert 'uniform vec2 mesh_id_texel' in canvas
assert 'texture(mesh_id_texture, uv).r' in canvas
assert 'if (id >= 0.06)' in canvas
assert 'return;' not in canvas   # No undefined fragment() early return
assert 'COLOR = vec4(ink_color.rgb, ink_color.a * coverage);' in canvas
# Raw ID texture MUST NOT be assigned to the displayed TextureRect.
assert 'ink_rect.texture = id_viewport.get_texture()' not in layer
assert 'safe_image.fill(Color.TRANSPARENT)' in layer
assert 'ink_rect.texture = ImageTexture.create_from_image(safe_image)' in layer
assert 'material.set_shader_parameter("mesh_id_texture", id_viewport.get_texture())' in layer
assert '"mesh_id_texel"' in layer
assert 'mismatched_id' in canvas
assert 'neighbor_id + 0.05 < center_id' in canvas
assert 'if (id >= 0.06)' in canvas
assert 'COLOR = vec4(ink_color.rgb, ink_color.a * coverage);' in canvas
assert 'for (int dy = -3; dy <= 3; dy++)' in canvas
assert 'for (int dx = -3; dx <= 3; dx++)' in canvas
assert 'distance_sq > 10' in canvas
assert 'sqrt(float(distance_sq))' in canvas
assert 'stroke_px + 0.5 - nearest_dist' in canvas
assert 'nearest_dist <= stroke_px' in canvas
# The ID raster must match the actual overlay, not the initial 384x384 size.
assert 'roundi(ink_rect.size.x)' in layer
assert 'roundi(ink_rect.size.y)' in layer
assert 'func get_outline_metrics() -> Dictionary:' in layer
assert 'id_redraw_requests' in layer
assert 'estimated_max_id_samples_per_ink_pixel' in layer
# Numeric independent reference for a strict 3px solid core, with a 0.5px
# alpha edge on diagonals only. Two touching IDs get a single high-ID seam.
from math import sqrt

def coverage(ids, x, y):
    center = ids[y][x]
    if center == 0:
        return 0.0
    nearest = 99.0
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            dsq = dx * dx + dy * dy
            if not (0 < dsq <= 10):
                continue
            neighbor = ids[y + dy][x + dx]
            if neighbor == 0 or neighbor < center:
                nearest = min(nearest, sqrt(dsq))
    return min(1.0, max(0.0, (3.5 - nearest) / 0.5))

filled = [[1 if 12 <= x < 24 else 0 for x in range(40)] for y in range(40)]
assert [coverage(filled, x, 20) for x in range(11, 17)] == [0, 1, 1, 1, 0, 0]
touched = [[1 if 5 <= x < 20 else (2 if 20 <= x < 35 else 0)
            for x in range(40)] for y in range(40)]
assert [coverage(touched, x, 20) for x in range(17, 24)] == [0, 0, 0, 1, 1, 1, 0]
diagonal = [[1 if x + y >= 34 else 0 for x in range(48)] for y in range(48)]
for y in range(12, 23):
    line = [x for x in range(10, 35) if coverage(diagonal, x, y) > 0]
    assert line == list(range(min(line), max(line) + 1))  # no 45-degree breaks
# Other systems untouched: no new blanket replacement of SeraViewEdges.
assert 'const INK_SHADER = preload("res://shaders/sera_view_edges.gdshader")' in read(
    "scripts/sera_view_edges.gd")
assert 'SERA_INTAKE_PREVIEW' in read("tools/equipment_intake/godot_preview.gd")
print("IRIS_ID_VISIBLE_OUTLINE_LOCAL_STATIC_PASS / H02 only / 6 IDs / 3px / no CI")

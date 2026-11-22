#!/usr/bin/env python3
"""NEXUS-only 2 px grey polygon edges: preserve light silhouettes and SERA."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
nexus = read("scripts/command_nexus.gd")
shader = read("shaders/nexus_polygon_edges.gdshader")
policy = read("scripts/render_order_policy.gd")
selection = read("scripts/nexus_selection_outline.gd")
manifest = read("tools/sera_ci_manifest.txt")

# Contracts derived from the requested visual treatment, not implementation samples.
assert "const NEXUS_EDGE_SHADER = preload(" in nexus
assert "func _nexus_edge_material(" in nexus
assert "const NEXUS_EDGE_WIDTH_PIXELS: float = 2.0" in nexus
assert "Color(\"#7e858e\")" in nexus
assert 'edge.render_priority = RENDER_ORDER.NEXUS_SURFACE_EDGES' in nexus
assert "const NEXUS_SURFACE_EDGES: int = -10" in policy
assert "const AFTERIMAGE: int = -20" in policy
assert "const SHIELD_IMPACT: int = 115" in policy
assert "material.next_pass = _nexus_edge_material()" in nexus
assert "if index not in [5, 6, 7]:" in nexus
assert "pad_material.next_pass = _nexus_edge_material(1)" in nexus

# Geometry is bounded to NEXUS's authored cube instances and the 12-sided pad.
assert "draw.material_override = material" in nexus
assert "surface.material_override = pad_material" in nexus
sera_block = nexus.split("func _sera_display() -> void:")[1].split("\nfunc ")[0]
assert "_nexus_edge_material" not in sera_block
assert "next_pass" not in sera_block
assert "_render_batches()" in nexus
assert nexus.index("_render_batches()") < nexus.index("_sera_display()")
assert "var canvas := CanvasLayer.new()" in nexus
assert "hud.add_child(outline)" in nexus
assert 'Color(0.35, 0.85, 0.98, alpha)' in selection

assert "// RENDER_POLICY: NEXUS_SURFACE_EDGES; depth_test=on" in shader
assert "render_mode unshaded, blend_mix, cull_back, depth_draw_never;" in shader
assert "uniform float width_px = 2.0;" in shader
assert "fwidth(" in shader
assert "geometry_mode" in shader
assert "ALPHA =" in shader
assert "depth_test_disabled" not in shader
assert "py tools/nexus_polygon_edges_self_check.py" in manifest
assert "gd tools/nexus_polygon_edges_runtime_check.gd" in manifest
print("PASS: NEXUS 2px gray polygon edges, low-priority depth-tested pass, SERA exclusion")

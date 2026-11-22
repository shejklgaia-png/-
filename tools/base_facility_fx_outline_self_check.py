#!/usr/bin/env python3
"""BASE FX and crisp screen-space facility outlines: no FX edge contamination."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
vfx = (root / "scripts/sera_base_facility_vfx.gd").read_text(encoding="utf-8")
edges = (root / "scripts/sera_base_facility_outlines.gd").read_text(encoding="utf-8")
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const ARCHIVED_NEXUS_MODEL: bool = true" in arch
assert "g.hard_edges = true" in arch
assert "outline_solid_entries" in arch
assert "outline_enabled" in arch
assert 'tint not in ["blue_light", "amber_light", "amber", "glass"]' in arch
assert 'fresh_vfx.setup(node, "NEXUS")' in arch
assert 'archived_vfx.setup(node, "NEXUS")' in arch
assert 'device_vfx.setup(node, key)' in arch
assert "CPUParticles3D.new()" in vfx
assert 'part.name = "SmelterChimneySmoke"' in vfx
assert "DoorLightLeak" in vfx
assert "SmelterFireFloorReflection" in vfx
assert "sample_fire" in vfx and "FurnaceHeatLight" in vfx
assert "ShaderMaterial.new()" in vfx
assert "FX_NO_OUTLINE" in vfx
assert "extends RefCounted" in edges
assert "BaseFacilityCreaseGeometry._build_overlay(physical_mesh)" in edges
assert 'set_shader_parameter("stroke_px", 4.0)' in edges
assert "BaseFacilityCreaseGeometry._build_overlay" in edges
assert "ArchitecturalCreaseInk_" in arch
assert 'set_shader_parameter("crease_px", 1.0)' in edges
assert 'Color("#000000")' in edges
assert 'Color("#202020")' in edges
assert 'Color("#55798A")' not in edges
assert "Geometry2D.convex_hull" not in edges
assert "draw_polyline" not in edges
assert "get_node_or_null" not in edges
assert "SeraBaseFacilityOutlines" not in hub
assert "BaseFacilityInk.overlay_for" in arch
assert "ArchitecturalEdgeInk_" in arch
for key in ("NEXUS","LABO","SCRAP_COLLECTOR","SMELTER","RECYCLER",
            "GENERATOR","STORAGE","BUILD_TERMINAL"):
    # GPU physical mesh outlines are shared by every facility, not special-
    # cased by 2D silhouette keys. Each portal still has its own FX color.
    assert '"'+key+'"' in vfx
assert "py tools/base_facility_fx_outline_self_check.py" in manifest
assert "gd tools/base_facility_fx_outline_runtime_check.gd" in manifest
assert "base_facility_fx_outline_runtime_check.gd" in workflow
print("SERA_BASE_FX_PIXEL_OUTLINES_STATIC_PASS")

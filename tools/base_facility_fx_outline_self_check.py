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
assert "BaseFacilityVfx.attach(node, \"NEXUS\")" in arch
assert "BaseFacilityVfx.attach(node, key)" in arch
assert "CPUParticles3D.new()" in vfx
assert 'part.name = "SmelterChimneySmoke"' in vfx
assert "DoorLightLeak" in vfx
assert "SmelterFireFloorReflection" in vfx
assert "FireFlickerLight" in vfx
assert "ShaderMaterial.new()" in vfx
assert "FX_NO_OUTLINE" in vfx
assert "Geometry2D.convex_hull" in edges
assert 'draw_polyline(loop, Color("#55798A"), 6.0' in edges
assert 'draw_line(a, b, Color("#55798A"), 2.0' in edges
assert 'get_meta("outline_solid_entries"' in edges
assert 'get_node_or_null("SmelterChimneySmoke")' not in edges
assert 'not hub.get("power_view_active")' in edges
assert "SeraBaseFacilityOutlines" in hub
for key in ("NEXUS","LABO","SCRAP_COLLECTOR","SMELTER","RECYCLER",
            "GENERATOR","STORAGE","BUILD_TERMINAL"):
    assert '"'+key+'"' in edges
    assert '"'+key+'"' in vfx
assert "py tools/base_facility_fx_outline_self_check.py" in manifest
assert "gd tools/base_facility_fx_outline_runtime_check.gd" in manifest
assert "base_facility_fx_outline_runtime_check.gd" in workflow
print("SERA_BASE_FX_PIXEL_OUTLINES_STATIC_PASS")

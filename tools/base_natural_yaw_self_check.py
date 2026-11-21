#!/usr/bin/env python3
"""BASE outdoor rotation contract: independently yawed stations and prop piles."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
arch = (r / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
clutter = (r / "scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
base = (r / "scripts/base_exploration.gd").read_text(encoding="utf-8")
fac = (r / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (r / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const BODY_YAW_DEGREES" in arch
assert "static func facility_yaw_radians(" in arch
assert "Basis(Vector3.UP, yaw)" in arch
assert "var detail_scale: float = 1.0" in arch
assert "pivot + spin * ((at - pivot) * detail_scale)" in arch
assert "spin * basis.scaled_local(Vector3.ONE * detail_scale)" in arch
# The pivot and original yaw remain immutable when the optional scale is 1.
assert "g.yaw = facility_yaw_radians(key)" in arch
assert "BaseClutter.decorate(g, key)" in arch and 'BaseClutter.decorate(g, "NEXUS")' in arch
assert "func props_for(key: String) -> Array[Dictionary]:" in clutter
assert "const VIEW_AZIMUTH_DEGREES: float = 38.0" in clutter
assert 'item["yaw_deg"]' in clutter
assert "g.get_property_list()" in clutter, "capture-only renderers without yaw must remain supported"
assert "g.pivot = Vector3(" in clutter and "g.yaw = deg_to_rad(" in clutter
assert "foundation.rotation.y = BaseArchitecture.facility_yaw_radians(key)" in fac
assert 'BaseArchitecture.facility_yaw_radians("NEXUS")' in base
assert "_nexus_screen_rect" in base and "_projected_bounds" in fac
assert "py tools/base_natural_yaw_self_check.py" in ci
assert "gd tools/base_natural_yaw_runtime_check.gd" in ci
print("SERA_BASE_NATURAL_YAW_STATIC_PASS")

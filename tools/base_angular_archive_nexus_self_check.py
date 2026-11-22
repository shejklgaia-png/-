#!/usr/bin/env python3
"""BASE: archive NEXUS exactly; other seven are hard-edged, not rounded props."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
fresh = (root / "scripts/sera_base_fresh_design.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const ARCHIVED_NEXUS_MODEL: bool = true" in arch
assert 'if ACTIVE_BASE_MODEL == "FRESH_20261122" and not ARCHIVED_NEXUS_MODEL:' in arch
assert 'node.set_meta("base_design", "ARCHIVED_20261122")' in arch
for marker in ("NexusCutCornerShell", "ArmoredRoof", "GatePortal", "SealedGate",
               "FrontEmblem", "NexusFacadeArmor", "NexusRoofServiceRack"):
    assert marker in arch, marker
assert "g.hard_edges = true" in arch
assert "var hard_edges: bool = false" in arch
assert 'kind in ["bevel", "drum", "gear", "hopper", "canvas", "tube"]' in arch
assert 'resolved_kind = "cube"' in arch
assert 'var segments: int = 4 if hard_edges else 8' in arch
assert 'BaseFreshDesign.add_details(g, key)' in arch
assert 'BaseFreshDesign.add_details(g, "NEXUS")' in arch, "new NEXUS variant must remain reversible"
assert "static func _nexus(g: Variant)" in fresh
assert "gd tools/base_angular_archive_nexus_runtime_check.gd" in manifest
assert "py tools/base_angular_archive_nexus_self_check.py" in manifest
print("SERA_BASE_ANGULAR_ARCHIVE_NEXUS_STATIC_PASS")

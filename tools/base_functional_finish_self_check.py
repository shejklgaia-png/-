#!/usr/bin/env python3
"""Industrial finish acceptance contract, independent of model implementation."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding="utf-8")
arch=read("scripts/sera_base_architecture.gd")
finish=read("scripts/sera_base_functional_finish.gd")
floor=read("scripts/sera_base_floor_detail.gd")
ci=read("tools/sera_ci_manifest.txt")
assert 'const BaseFinish = preload("res://scripts/sera_base_functional_finish.gd")' in arch
assert 'BaseFinish.add_details(g, "NEXUS")' in arch
assert "BaseFinish.add_details(g, key)" in arch
expected={
"NEXUS":"NexusRaisedCatwalk",
"LABO":"LabPrinterServiceGantry",
"SCRAP_COLLECTOR":"CollectorArticulatedLine",
"SMELTER":"FurnaceHeatShieldRibs",
"RECYCLER":"CrusherInputSafetyRim",
"GENERATOR":"GeneratorWindingGuard",
"STORAGE":"CargoLoadingFrame",
"BUILD_TERMINAL":"BlueprintWorkLightSconce",
}
for k,v in expected.items():
    assert '"'+k+'"' in finish,(k,"missing branch")
    assert '"'+v+'"' in finish,(k,"missing modeled feature")
for bad in ("MeshInstance3D.new()", "CollisionShape3D.new()", "OmniLight3D.new()", "func _process(", "func _physics_process("):
    assert bad not in finish,bad
for call in ("g.box(", "g.rod(", "g.poly(", "g.box_tilt("):
    assert call in finish,call
for label in ("DockEdgeDrain", "DockVentSlits", "DockAnchorShoes"):
    assert '"'+label+'"' in floor
assert "if site_id.is_empty():" in floor, "preserve single slab"
assert '"cloth": "#68685f"' in arch, "muted practical canvas must not outshine steel"
assert 'py tools/base_functional_finish_self_check.py' in ci
assert 'gd tools/base_functional_finish_runtime_check.gd' in ci
print("SERA_BASE_FUNCTIONAL_FINISH_STATIC_PASS")

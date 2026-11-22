#!/usr/bin/env python3
"""BASE eight functional animations: real existing 3D parts, no extra draws."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
arch = (ROOT / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
motion = (ROOT / "scripts/sera_base_facility_motion.gd").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")
capture = (ROOT / "tools/base_isometric_visual_capture.gd").read_text(encoding="utf-8")
for feature in (
    "NexusAntennas", "NexusAntennasBeacon",
    "FreshLabPrinterServo", "FreshLabPrinterHotHead", "FreshLabPrinterTip",
    "FreshCollectorSuspendedCable", "FreshCollectorClawHead", "FreshCollectorOpenGrip",
    "FreshSmelterFlameTongue", "FreshSmelterLowFire",
    "FreshRecyclerRoller", "FreshRecyclerTooth",
    "FreshGeneratorRotorBlade", "FreshStorageLoadingLift",
    "FreshTerminalBlueprintRows", "FreshTerminalMastLamp",
):
    assert feature in motion, ("missing machine's animated real part", feature)
for key in ("NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
            "GENERATOR", "STORAGE", "BUILD_TERMINAL"):
    assert '"'+key+'"' in motion
assert 'const BaseFacilityMotion = preload("res://scripts/sera_base_facility_motion.gd")' in arch
assert "g.motion_names" in arch
assert "motion_indices" in arch
assert "BaseFacilityMotion.attach(node, \"NEXUS\")" in arch
assert "BaseFacilityMotion.attach(node, key)" in arch
assert 'const ARCHIVED_NEXUS_MODEL: bool = true' in arch
assert 'g.hard_edges = true' in arch
assert 'multi.set_instance_transform' in motion
assert 'func sample_at(seconds: float)' in motion
assert 'func _process(delta: float)' in motion
for forbidden in ("MeshInstance3D.new()", "MultiMeshInstance3D.new()", "OmniLight3D.new()",
                  "Area3D.new()", "create_tween()", "Timer.new()"):
    assert forbidden not in motion, ("unnecessary animation draw / timers", forbidden)
assert "py tools/base_facility_motion_self_check.py" in manifest
assert "gd tools/base_facility_motion_runtime_check.gd" in manifest
assert 'scripts/sera_base_facility_motion.gd' in workflow
assert "SERA_BASE_ANIMATION_CAPTURE" in workflow
assert "sera_base_animated.png" in capture
print("SERA_BASE_EIGHT_FUNCTIONAL_MOTIONS_STATIC_PASS")

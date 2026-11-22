#!/usr/bin/env python3
"""BASE visibility is judged against the REAL live portrait gameplay camera."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def get(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")

hub = get("scripts/base_exploration.gd")
roof = get("scripts/sera_base_fresh_design.gd")
arch = get("scripts/sera_base_architecture.gd")
capture = get("tools/base_isometric_visual_capture.gd")
manifest = get("tools/sera_ci_manifest.txt")
workflow = get(".github/workflows/base-roof-visual-preview.yml")

# Fix the approved real camera. We may change buildings, not cheat the shot.
for spec in (
    "const BASE_ORTHO_SIZE: float = 38.0",
    "const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)",
    "const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 2.1, -2.2)",
    "cam.projection = Camera3D.PROJECTION_ORTHOGONAL",
):
    assert spec in hub, "gameplay camera was changed: " + spec

# A full, unoccluded opening and a distinct foreground feature are required,
# rather than counting details positioned behind upper roof plates.
for feature in (
    '"FreshLabOpenPrinterBridge"', '"FreshLabFabricationBed"',
    '"FreshCollectorTallBoom"', '"FreshCollectorOpenGrip"',
    '"FreshGeneratorFrontRotor"', '"FreshGeneratorBlueCorona"',
    '"FreshStorageOffsetStacks"', '"FreshStorageShortRearTarp"',
):
    assert feature in roof, "missing camera-facing fresh part " + feature
assert '"FreshStorageLoadingLift"' in roof
assert "Vector3(2.13, 0.12, 0.63)" in roof, "storage canopy hides cargo"
assert 'BaseFreshDesign.add_details(g, key)' in arch
assert 'const ACTIVE_BASE_MODEL: String = "FRESH_20261122"' in arch
# Real viewport screenshot, AFTER fully constructing eight facilities.
assert 'BaseStartupOverlay' in capture
assert 'for _attempt in range(90):' in capture
assert 'Camera3D.PROJECTION_ORTHOGONAL' in capture
assert 'camera.size' in capture
assert 'power_view_active' in capture
assert 'RenderingServer.frame_post_draw' in capture
for entry in (
    "py tools/base_gameplay_angle_visibility_self_check.py",
    "gd tools/base_gameplay_angle_visibility_runtime_check.gd",
):
    assert entry in manifest, entry
for path in (
    "'tools/base_gameplay_angle_visibility_*'",
    "'tools/base_isometric_visual_capture.gd'",
):
    assert path in workflow, path
# All visual BASE modules must activate a fresh real gameplay screenshot in PR CI.
for trigger in (
    "'scripts/base_facility_system.gd'",
    "'scripts/base_exploration.gd'",
    "'scripts/sera_base_functional_finish.gd'",
    "'scripts/sera_base_clutter.gd'",
    "'scripts/sera_base_deck_layout.gd'",
    "'scripts/sera_base_materials.gd'",
    "'assets/base/**'",
):
    assert trigger in workflow, "visual edit would bypass screenshot review: " + trigger
assert "python3 tools/base_gameplay_angle_visibility_self_check.py" in workflow
assert "tools/base_gameplay_angle_visibility_runtime_check.gd" in workflow

# Keep floor colliders, building placement and mobile render-batching intact.
for source in (roof,):
    for bad in ("Area3D.new()", "OmniLight3D.new()", "MultiMeshInstance3D.new()"):
        assert bad not in source, "extra draw/physics allocation " + bad
print("SERA_BASE_GAMEPLAY_ANGLE_STATIC_PASS")

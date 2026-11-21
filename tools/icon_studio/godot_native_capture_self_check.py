#!/usr/bin/env python3
"""SERA: native-Godot icon capture must reuse in-game geometry and shaders."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
preset = json.loads((ROOT / "assets/ui/sera_icon_presets/H02.json").read_text(encoding="utf-8"))
assert preset["format"] == "SERA_ICON_PRESET_V1"
assert preset["render"]["model_rotation_deg"] == {
    "x": 11.8749389648438, "y": 156.900744628906, "z": 0
}
assert preset["render"]["auto_fit"] == 0.76
assert preset["render"]["model_scale"] == 1
assert preset["render"]["pan_clip"] == {"x": 0, "y": 0}
assert preset["render"]["engine"] == "SERA Godot 4.7 GL Compatibility"
assert preset["render"]["outline"] == {
    "enabled": True, "stroke_px_at_512": 3,
    "crease_degrees": 80, "color": "#17212F"
}
assert preset["equipment"] == {"blueprint_id": "H02", "slot": "head", "rig_set": "D"}
assert preset["render"]["image"] == {
    "width": 512, "height": 512, "background": "transparent",
    "ui_frame_baked": False,
}
model_file = ROOT / preset["source"]["repository_path"]
assert model_file.is_file()
assert hashlib.sha256(model_file.read_bytes()).hexdigest() == preset["source"]["fingerprint"]
capture = (ROOT / "tools/icon_studio/sera_godot_native_capture.gd").read_text(encoding="utf-8")
for required in (
    'preload("res://scripts/sera_rig.gd")',
    'preload("res://scripts/sera_view_edges.gd")',
    '"Waist/Torso/Chest/Neck/Head/CameraEyeHeadD"',
    'available.get("D", {})',
    'source.mesh',
    'source.material_override',
    'SubViewport.new()',
    'viewport.transparent_bg = true',
    'Camera3D.PROJECTION_ORTHOGONAL',
    'Environment.AMBIENT_SOURCE_COLOR',
    'Color("#bbc9e1")',
    'sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)',
    'sun.light_energy = 1.7',
    'Basis.from_euler',
    'EULER_ORDER_XYZ',
    'RenderingServer.frame_post_draw',
    'image.save_png(',
):
    assert required in capture, f"Native material/render contract missing: {required}"
# Do not regenerate textures/meshes in JS/CPU or take a screenshot of
# the 3D asset from a different renderer.
assert "_make_mesh(" not in capture
assert "load_png_from_buffer" not in capture
metadata = (ROOT / "tools/icon_studio/annotate_godot_native_png.py").read_text(encoding="utf-8")
assert '"SERA_ICON_MANIFEST_V1"' in metadata
assert '"SERA_ICON_PNG_V1"' in metadata
assert 'zlib.crc32(' in metadata
workflow = (ROOT / ".github/workflows/sera-model-policy.yml").read_text(encoding="utf-8")
assert "--script tools/icon_studio/sera_godot_native_capture.gd" in workflow
assert "annotate_godot_native_png.py" in workflow
assert "sera-native-equipment-icon" in workflow
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "py tools/icon_studio/godot_native_capture_self_check.py" in manifest
print("SERA_GODOT_NATIVE_ICON_CAPTURE_STATIC_PASS")

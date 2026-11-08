#!/usr/bin/env python3
"""SERA v120: verify Blockbench source->Godot geometry and menu constraints.

Read-only static validation; it does not run Godot or Android.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
embedded = (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8")
hud_icon = (ROOT / "scripts/nexus_tag_icon.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")

import re
version = re.search(r'config/name="SERA v(\d+)', project)
assert version is not None and int(version.group(1)) >= 120
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'renderer/rendering_method="gl_compatibility"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project

names = ("hangar_shell", "maintenance_pad", "maintenance_canopy",
         "deployment_gate", "kiosk", "data_bank", "archive_mezzanine")
modules = json.loads(embedded.split("const MODULES = ", 1)[1].strip())
palette = json.loads(embedded.split("const PALETTE = ", 1)[1].split("\n", 1)[0])
assert len(palette) <= 9
assert set(modules) == set(names)

elements_total = 0
for name in names:
    model = json.loads((ROOT / "blockbench" / "base" / f"SERA_{name}.bbmodel").read_text(encoding="utf-8"))
    assert model["meta"]["model_format"] == "free"
    assert len(model["elements"]) >= 10
    assert len({part["uuid"] for part in model["elements"]}) == len(model["elements"])
    assert set(model["outliner"]) == {part["uuid"] for part in model["elements"]}
    values = [[part["name"], part["from"], part["to"], part["color"], part["rotation"]]
              for part in model["elements"]]
    assert modules[name] == values, f"{name}: Blockbench != embedded Godot geometry"
    for part in model["elements"]:
        assert 0 <= part["color"] < len(palette)
        assert all(lo < hi for lo, hi in zip(part["from"], part["to"]))
    elements_total += len(values)
    assert f'_module("{name}"' in src, f"{name} not placed in scene"

# Actual visible copies of kiosk are reused and GPU instances are batched by palette.
assert src.count('_module("kiosk"') == 2
assert 150 <= elements_total <= 270
assert "MultiMesh.TRANSFORM_3D" in src
assert "set_instance_transform" in src
assert "scaled_local(hi - lo)" in src
assert "SeraRig.new()" in src
assert "rig.set_process(false)" in src
assert 'rig.get("bind_positions")' in src
assert 'rig.get("bind_rotations")' in src
assert "rig.rotation.y = PI" in src
assert "Quaternion(Vector3.BACK, deg_to_rad" in src
assert 'cam.look_at(Vector3(0.0, 3.00, -5.50)' in src
assert 'Environment.AMBIENT_SOURCE_COLOR' in src
assert 'Environment.AMBIENT_COLOR' not in src
assert 'func _tag(' in src
assert "Control.MOUSE_FILTER_IGNORE" in src
assert "TagIcon.new()" in src
for caption in ("DATA ARCHIVE", "DEPLOYMENT", "TRAINING", "SYSTEM", "CUSTOMIZE"):
    assert f'_tag("{caption}"' in src
    assert f'"{caption}":' in hud_icon
assert "Button.new()" not in src
assert "InputEventScreenTouch" not in src

# Prior gameplay scene and assets are still accessible.
assert (ROOT / "scenes/main.tscn").is_file()
assert (ROOT / "scripts/main.gd").is_file()
assert (ROOT / "assets/sera_source.json").is_file()

print(f"v120 static Blockbench/Godot parity: {len(names)} modules, {elements_total} source boxes, "
      f"{len(palette)} material batches maximum. PASS")
print("Godot/Android rendering, orientation and FPS remain untested.")

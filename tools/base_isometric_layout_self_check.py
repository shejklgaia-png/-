#!/usr/bin/env python3
"""SERA outdoor field: FOV-free oblique orthographic camera and readable portrait composition."""
from pathlib import Path
import math
import re
r = Path(__file__).resolve().parents[1]
base = (r/"scripts/base_exploration.gd").read_text(encoding="utf-8")
facility = (r/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (r/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'cam.projection = Camera3D.PROJECTION_ORTHOGONAL' in base
assert 'cam.size = BASE_ORTHO_SIZE' in base
assert 'const BASE_ORTHO_SIZE: float = 38.0' in base
assert 'const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 30.0, 25.0)' in base
assert 'const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 0.0, -2.2)' in base
assert 'cam.look_at(BASE_CAMERA_TARGET' in base
assert 'cam.fov = 0.0' not in base, "Godot cannot use 0-degree perspective"
# Japanese facility names and the bottom hint must render with bundled glyphs.
assert 'const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")' in base
assert 'node.add_theme_font_override("font", LaboSkin.ui_font())' in base
assert 'sign.font = LaboSkin.ui_font()' in facility
assert 'sign.visible = false' in facility, "HUD name should not duplicate 3D sign"
assert 'tag.add_theme_font_override("font", LaboSkin.ui_font())' in facility
assert 'const HUB_SERA_CONTROLS_ENABLED: bool = false' in base
assert '_nexus_screen_rect' in base and 'key_at' in facility
assert 'py tools/base_isometric_layout_self_check.py' in ci
assert 'gd tools/base_isometric_layout_runtime_check.gd' in ci

# Approved screen composition for the 720x1280 portrait viewport:
# NEXUS high center, LABO middle, six devices in three staggered outside rows.
# Not derived from the implementation: each independent target is specified here.
desired = {
    "NEXUS": (.50, .23),
    "LABO": (.50, .50),
    "SMELTER": (.19, .36),
    "RECYCLER": (.81, .37),
    "STORAGE": (.17, .575),
    "GENERATOR": (.83, .59),
    "SCRAP_COLLECTOR": (.235, .80),
    "BUILD_TERMINAL": (.76, .805),
}
read_nexus = re.search(
    r'const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3\(([-.\d]+), ([-.\d]+), ([-.\d]+)\)', base)
assert read_nexus is not None
positions = {"NEXUS": (float(read_nexus[1]), float(read_nexus[3]))}
for name in desired:
    if name == "NEXUS":
        continue
    m = re.search(
        r'{"id": "' + name + r'".*?"at": Vector3\(([-.\d]+), ([-.\d]+), ([-.\d]+)\)',
        facility, flags=re.S)
    assert m, "missing world placement for " + name
    positions[name] = (float(m[1]), float(m[3]))
eye = (21., 30., 25.)
target = (0., 0., -2.2)
dx,dy,dz = (target[i]-eye[i] for i in range(3))
norm = math.sqrt(dx*dx+dy*dy+dz*dz)
dx,dy,dz = dx/norm,dy/norm,dz/norm
right = (-dz/math.hypot(dx,dz), 0., dx/math.hypot(dx,dz))
up = (-right[2]*dy, right[2]*dx - right[0]*dz, right[0]*dy)
# CAMERA_KEEP_WIDTH/portrait scaling equivalent: orthographic vertical span 38.
for name, (px,pz) in positions.items():
    delta = (px-target[0], 0., pz-target[2])
    uv = (.5 + (delta[0]*right[0] + delta[2]*right[2])/(38.0*720/1280),
          .5 - (delta[0]*up[0] + delta[2]*up[2])/38.0)
    assert abs(uv[0]-desired[name][0]) < .02, (name,uv,desired[name])
    assert abs(uv[1]-desired[name][1]) < .02, (name,uv,desired[name])
print("SERA_BASE_ISOMETRIC_STATIC_PASS")

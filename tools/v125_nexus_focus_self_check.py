#!/usr/bin/env python3
"""v125 interactive Nexus: static source/projection regression (not Godot runtime)."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
nexus = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
overlay = (ROOT / "scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
model = (ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8")

assert 'config/name="SERA v125 - Nexus Focus Navigation"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'renderer/rendering_method="gl_compatibility"' in project

# The overview has no text signplates or input-emulation changes.
assert 'func _tag(' not in nexus
assert 'TagIcon.new()' not in nexus
assert 'Input.emulate_mouse_from_touch = true' not in nexus
assert 'InputEventScreenTouch' in nexus
assert 'InputEventMouseButton' in nexus
assert 'KEY_BACK' in nexus
assert 'func _return_to_overview()' in nexus
assert 'func _start_training()' in nexus
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in nexus
assert 'TRAINING_SCENE: String = "res://scenes/main.tscn"' in nexus

# Camera focus is 0.18 seconds, with no extra screen or particle effects.
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in nexus
assert 'Tween.TRANS_CUBIC' in nexus and 'Tween.EASE_OUT' in nexus
assert 'from_pose.interpolate_with(to_pose, progress)' in nexus
assert 'lerpf(from_fov, to_fov, progress)' in nexus
assert 'func _focus_arrived(' in nexus
assert 'func _overview_arrived()' in nexus
assert 'GPUParticles3D' not in nexus and 'CPUParticles3D' not in nexus
assert 'Button.new()' not in nexus
assert 'draw_colored_polygon' in overlay and 'draw_polyline' in overlay
assert 'sin(pulse_time * 2.8)' in overlay

# Outline is bound to the 3D camera, not a fixed 2D HUD sign.
assert 'cam.unproject_position(point)' in nexus
assert 'Geometry2D.is_point_in_polygon(point, poly)' in nexus
assert 'func _polygon_bounds(' in nexus
assert 'outline.set("active_target", target_name)' in nexus
assert 'outline.set("active_target", "")' in nexus

targets = ("TRAINING", "SYSTEM", "CUSTOMIZE", "DATA ARCHIVE", "DEPLOYMENT")
assert all(f'"{t}": {{"eye":' in nexus for t in targets)
assert all(f'"{t}": [' in nexus for t in targets)
assert len(re.findall(r'"eye": Vector3\(', nexus)) == 5
assert len(re.findall(r'"look": Vector3\(', nexus)) == 5

# Pinhole projection, 720x1280 overview. Check each hull is visible and at
# least thumb-sized, with no left/right kiosk to central body overlap.
camera = (0.0, 4.1, 10.2)
look = (0.0, 3.0, -5.5)
def norm(v):
    m = math.sqrt(sum(x*x for x in v))
    return tuple(x/m for x in v)
forward = norm(tuple(a-b for a,b in zip(look,camera)))
right = norm((-forward[2], 0.0, forward[0]))
up = (right[1]*forward[2]-right[2]*forward[1],
      right[2]*forward[0]-right[0]*forward[2],
      right[0]*forward[1]-right[1]*forward[0])
f = 1.0 / math.tan(math.radians(63.0 / 2.0))
def dot(a,b):
    return sum(x*y for x,y in zip(a,b))
bounds = {}
for name in targets:
    match = re.search(r'"' + re.escape(name) + r'": \[(.*?)\]', nexus, re.S)
    assert match, name
    coordinates = re.findall(r'Vector3\(([^)]+)\)', match.group(1))
    assert len(coordinates) >= 4
    pts = []
    for coord in coordinates:
        v = tuple(float(s.strip()) for s in coord.split(","))
        d = tuple(a-b for a,b in zip(v,camera))
        depth = dot(d,forward)
        assert depth > 0.1
        sx = 360.0 * (1.0 + dot(d,right)*f/depth/(720/1280))
        sy = 640.0 * (1.0 - dot(d,up)*f/depth)
        pts.append((sx,sy))
    x = [p[0] for p in pts]
    y = [p[1] for p in pts]
    bounds[name] = (min(x),min(y),max(x),max(y))
    assert 0 <= min(x) and max(x) <= 720, (name,bounds[name])
    assert 0 <= min(y) and max(y) <= 1280, (name,bounds[name])
    assert max(x)-min(x) >= 80 and max(y)-min(y) >= 80, name
assert bounds["TRAINING"][2] < bounds["CUSTOMIZE"][0]
assert bounds["CUSTOMIZE"][2] < bounds["SYSTEM"][0]
assert bounds["DATA ARCHIVE"][2] < bounds["DEPLOYMENT"][0]
assert 'Bash' in model and 'Guard_REACTION' in model

# The authored scene, model, modules and gate light setup remain available.
assert 'const GATE_ORIGIN: Vector3 = Vector3(4.00, 0.02, -10.48)' in nexus
assert 'var lamp := OmniLight3D.new()' in nexus
assert '_module("archive_mezzanine", Vector3(-4.00, 0.0, -6.55))' in nexus
assert 'SeraRig.new()' in nexus
assert (ROOT / "scenes/main.tscn").exists()
print("v125 interactive silhouettes, five focus cameras, touch/back, legacy assets: PASS")
print("Static/projection test only; Godot parser, Android viewport and touch remain untested.")

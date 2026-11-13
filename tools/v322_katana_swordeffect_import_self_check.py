#!/usr/bin/env python3
"""v322: staged Katana is integrated into one canonical source, with v85 FX."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT/path).read_text(encoding="utf-8")
doc = lambda path: json.loads(read(path))
core = doc("models/core/Katana.bbmodel")
assert doc("models/manifest.json")["variants"]["katana"] == "models/core/Katana.bbmodel"
assert not (ROOT/"models/storage/Katana.bbmodel").exists(), "staging duplicate must not remain after verified import"

fx_uid = next(g["uuid"] for g in core["groups"] if g["name"] == "Swordeffect")
clips = {a["name"]: a for a in core["animations"]}
assert set(clips) == {"Melee_katana", "Melee_katana2"}
assert len(core["elements"]) == 32 and len(core["groups"]) == 27

for name, t, rotation, position, scale in [
    ("Melee_katana", 0.33333, ("-12.4539","1.0809","4.882"),
     ("5.6","-17.3","-15"), ("4.05","1","3.56")),
    ("Melee_katana2", 0.0, ("0","0","75"),
     ("1.7","-10.8","-10.2"), ("4.84","1","4.18"))
]:
    keys = clips[name]["animators"][fx_uid]["keyframes"]
    assert len(keys) == 3, name
    by_channel = {k["channel"]: k for k in keys}
    for channel, values in [
        ("rotation",rotation), ("position",position), ("scale",scale)
    ]:
        key = by_channel[channel]
        assert abs(float(key["time"])-t)<0.00001
        assert tuple(key["data_points"][0][axis] for axis in "xyz") == values

# Generated Android fallback must be derived from the SAME two core clips.
embedded_lines = read("assets/sera_katana_data.gd").splitlines()
chunks = [json.loads(line.strip().removesuffix(","))
          for line in embedded_lines if line.startswith('    "')]
assert json.loads("".join(chunks)) == {"animations": core["animations"]}
# Never source animations/meshes from the removed incoming working copy.
rig = read("scripts/sera_rig.gd")
trail = read("scripts/sword_trail.gd")
assert 'res://models/core/Katana.bbmodel' in rig
assert 'res://models/storage/Katana.bbmodel' not in rig
assert '_build_animations({"animations": [authored]})' in rig
assert "source_plane = rig_node.call(\"get_sword_effect_mesh\")" in trail
assert "source_plane.get_parent().add_child(effect_root)" in trail
assert "effect_root.transform = source_plane.transform" in trail
for token in ["func _build_flat(", "func _build_lens(",
              "func _step_particles(", "flat_mesh.mesh = _build_flat(frame)",
              "lens_mesh.mesh = _build_lens(frame)"]:
    assert token in trail, token
assert "py tools/v322_katana_swordeffect_import_self_check.py" in read("tools/sera_ci_manifest.txt")
assert "gd tools/v322_katana_swordeffect_import_runtime_check.gd" in read("tools/sera_ci_manifest.txt")
print("SERA_V322_KATANA_SWORDEFFECT_IMPORT_STATIC_PASS")

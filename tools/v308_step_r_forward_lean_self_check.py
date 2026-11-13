#!/usr/bin/env python3
"""v308 Step_R has a right/forward lean, without touching other authored tracks."""
from pathlib import Path
import json, re, base64, copy
ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
source = json.loads(read("assets/sera_source.json"))
model = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
archive = json.loads(read("models/motion/SERA_BOOSTER_allテスト.bbmodel"))
assert int(re.search(r'config/name="SERA v(\d+)"', read("project.godot")).group(1)) >= 308
def clip(data, name): return next(x for x in data["animations"] if x["name"] == name)
def uid(data, name): return next(g["uuid"] for g in data["groups"] if g["name"] == name)
now, before, authored = (clip(x,"Step_R") for x in (source,archive,model))
assert now == authored, "live source and Blockbench authoring clip differ"
assert now["name"] == before["name"] and now["uuid"] == before["uuid"]
version = int(re.search(r'config/name="SERA v(\d+)"', read("project.godot")).group(1))
if version == 308:
    # Historical v308 posture test: only the Waist/Head rotation was changed.
    restore = copy.deepcopy(now)
    for name, expected in {"Waist":("-30","-15","-18"),"Head":("35.3614","30","12")}.items():
        ident = uid(source,name)
        k = [v for v in now["animators"][ident]["keyframes"] if v["channel"]=="rotation"]
        assert len(k)==1 and k[0]["time"]==0
        actual = tuple(k[0]["data_points"][0][a] for a in ("x","y","z"))
        assert actual == expected,(name,actual)
        restore["animators"][ident] = copy.deepcopy(before["animators"][ident])
    assert restore == before, "something beyond Waist/Head rotation changed"
else:
    # v309 explicitly reinstates the photographed Step_R from 9.2.2.
    user = json.loads(read("models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel"))
    assert now == clip(user,"Step_R"), "source no longer matches selected 9.2.2 motion"
# Earlier revisions changed some live A-only clips independently from the
# equipment authoring file. Preserve each version's existing correspondence.
for name in ("Step_L","Backstep","Boost_right","Boost_front"):
    assert clip(model,name)==clip(archive,name), name
for name in ("Boost_right","Boost_front"):
    assert clip(source,name)==clip(model,name), name
assert clip(source,"Frontstep")["name"]==clip(model,"Frontstep")["name"]
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$',read("assets/sera_data.gd"),re.M)
assert base64.b64decode("".join(parts)) == (ROOT/"assets/sera_source.json").read_bytes()
rig=read("scripts/sera_rig.gd")
assert 'const STEP_RIGHT_CLIP: String = "Step_R"' in rig
assert "STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP" in rig
print("PASS v308/v309: Step_R versioned pose and unaffected other tracks, APK embed exact")

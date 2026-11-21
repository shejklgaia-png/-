#!/usr/bin/env python3
"""SERA Equipment Intake v1: sources, standalone pack and live combat hooks."""
from pathlib import Path
import base64, hashlib, json, re
root=Path(__file__).resolve().parents[2]
read=lambda p:(root/p).read_text(encoding="utf-8")
html=read("tools/equipment_intake/dist/SERA_Equipment_Intake_IRIS.html")
stats=read("scripts/sera_part_stats.gd")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
ui=read("tools/equipment_intake/intake_ui.js")
hook=read("tools/equipment_intake/intake_preview_hook.js")
manifest=read("tools/sera_ci_manifest.txt")
assert "<nav id=\"intakeTabs\"" in html
assert all(x in html for x in ('data-nav="setup"','data-nav="rig"','data-nav="icon"','data-nav="stats"','data-nav="materials"','data-nav="analysis"','data-nav="output"'))
assert all(x in ui for x in ('SERA_EQUIPMENT_INTAKE_V1','statrow disabled','classrow','approval_required:true','intakeMessage','thumbnailCache','SERA_INTAKE_RENDER.snapshot()','weightClass'))
assert all(x in hook for x in ('intakeComposedDoc','intakeExternal','parseModel(doc)','uploadGeometry()','intakeBounds','draw();schedule()'))
bundle=json.loads(re.search(r'<script type="application/json" id="sera-model-bundle">([^<]+)</script>',html).group(1))
assert bundle["format"]=="SERA_MODEL_BUNDLE_V1"
assert bundle["source_path"]=="models/storage/カメラアイ頭部.bbmodel"
raw=base64.b64decode(bundle["bbmodel_base64"])
assert raw==(root/bundle["source_path"]).read_bytes()
assert hashlib.sha256(raw).hexdigest()==bundle["sha256"]
packs=json.loads(re.search(r'<script type="application/json" id="intake-model-packs">([^<]+)</script>',html).group(1))
files={"equipment":"models/core/Equipment.bbmodel","head_d":"models/storage/カメラアイ頭部.bbmodel","head_c":"models/storage/Head_C.bbmodel","legs_d":"models/storage/LowerBody_D.bbmodel","bird_leg":"models/core/BirdLeg.bbmodel","katana":"models/core/Katana.bbmodel"}
for key,path in files.items():
    assert base64.b64decode(packs[key])==(root/path).read_bytes(),path
for word in ('WEIGHT_SHARES','WEIGHT_EFFECTS','BASE_EN_RECOVERY_PER_SECOND','weight_class_for','en_output_mult','en_recovery_per_second','weight_percent_for'):
    assert word in stats,word
for word in ('"movement_en_efficiency"','"step_distance_mult"','"tracking_speed_mult"','"en_recovery_per_second"','set_melee_attack_speed_scale'):
    assert word in main,word
for word in ('equipment_melee_attack_speed_scale','func set_melee_attack_speed_scale','playback_rate *= equipment_melee_attack_speed_scale'):
    assert word in rig,word
assert 'py tools/equipment_intake/intake_self_check.py' in manifest
assert 'gd tools/equipment_intake/weight_runtime_check.gd' in manifest
print("SERA_EQUIPMENT_INTAKE_STATIC_OK")

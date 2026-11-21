#!/usr/bin/env python3
"""Approved BASE inward-facing staggered ring: independent coordinate contract."""
from math import atan2, degrees, hypot, pi
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
fac=(r/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
base=(r/"scripts/base_exploration.gd").read_text(encoding="utf-8")
arch=(r/"scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
ci=(r/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
CENTER=(0.0, -2.2)
PREVIOUS={"NEXUS":[-9.53,-14.55],"LABO":[6.2,5.25],"SMELTER":[-10.9,-4.9],"RECYCLER":[1.1,-11.1],"STORAGE":[-2.55,5.8],"GENERATOR":[9.4,-1.65],"SCRAP_COLLECTOR":[5.2,15.6],"BUILD_TERMINAL":[15.3,8.8]}
APPROVED={"NEXUS":[-9.3,-14.55],"LABO":[5.95,5.4],"SMELTER":[-9.6,-3.8],"RECYCLER":[0.85,-10.65],"STORAGE":[-2.15,5.35],"GENERATOR":[8.85,-1.65],"SCRAP_COLLECTOR":[4.7,15.35],"BUILD_TERMINAL":[14.35,8.4]}
YAW_DEGREES={"NEXUS":29,"LABO":-159,"SMELTER":93,"RECYCLER":-20,"STORAGE":179,"GENERATOR":-77,"SCRAP_COLLECTOR":-151,"BUILD_TERMINAL":-144}
assert "const BODY_YAW_DEGREES = {" in arch
assert "static func facility_yaw_radians(" in arch
assert "py tools/base_inward_facilities_self_check.py" in ci
assert "gd tools/base_inward_facilities_runtime_check.gd" in ci
coords={}
for key in APPROVED:
    if key=="NEXUS":
        m=re.search(r'const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3\(([-.\d]+), ([-.\d]+), ([-.\d]+)\)',base)
    else:
        m=re.search(r'{"id": "'+key+r'".*?"at": Vector3\(([-.\d]+), ([-.\d]+), ([-.\d]+)\)',fac,re.S)
    assert m, "lost site: "+key
    coords[key]=(float(m[1]),float(m[3]))
    assert all(abs(a-b)<=0.015 for a,b in zip(coords[key],APPROVED[key])), (key,coords[key])
    m=re.search(r'"'+key+r'": ([-.\d]+)',arch)
    assert m, "lost yaw: "+key
    actual=float(m[1])
    assert abs(actual-YAW_DEGREES[key])<0.001,(key,actual)
    inward=degrees(atan2(CENTER[0]-coords[key][0],CENTER[1]-coords[key][1]))
    error=abs((actual-inward+180)%360-180)
    assert 7<=error<=24,(key,"must face roughly inward with an individual slant",error)
    assert abs(actual)<=180
assert len(set(YAW_DEGREES.values()))==8
old_radius=sum(hypot(x-CENTER[0],z-CENTER[1]) for x,z in PREVIOUS.values())
new_radius=sum(hypot(x-CENTER[0],z-CENTER[1]) for x,z in coords.values())
assert new_radius<old_radius-3.8,(new_radius,old_radius)
closer=sum(hypot(*[APPROVED[k][i]-CENTER[i] for i in (0,1)])<hypot(*[PREVIOUS[k][i]-CENTER[i] for i in (0,1)])-.20 for k in APPROVED)
assert closer>=6, closer
print("SERA_BASE_INWARD_RING_STATIC_PASS: 8 inward, differently angled facilities")

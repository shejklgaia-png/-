#!/usr/bin/env python3
"""Approved BASE entrances: camera-facing first, then subtly tilted toward screen center."""
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
APPROVED={"NEXUS":[-13.44,-19.91],"LABO":[7.15,6.95],"SMELTER":[-12.61,-7.7],"RECYCLER":[-1.85,-14.73],"STORAGE":[-3.43,3.92],"GENERATOR":[7.37,-3.57],"SCRAP_COLLECTOR":[9.95,22.18],"BUILD_TERMINAL":[19.49,15.88]}
YAW_DEGREES={"NEXUS":33,"LABO":44,"SMELTER":60,"RECYCLER":16,"STORAGE":63,"GENERATOR":12,"SCRAP_COLLECTOR":56,"BUILD_TERMINAL":20}
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
    # Camera-facing is mandatory: the old world-center orientation hid the
    # fronts of LABO, STORAGE and all lower perimeter facilities.
    camera_azimuth=degrees(atan2(21.0,25.0-CENTER[1]))
    slant=(actual-camera_azimuth+180)%360-180
    assert abs(slant)<=27,(key,"entry would face away from viewer",slant)
    # The camera's screen-right unit vector in the ground plane is
    # (+27.2,-21), so a LEFT site must turn right (positive yaw), and a
    # RIGHT site must turn left (negative yaw), not the reverse.
    sx=0.5+(27.2*coords[key][0]-21.0*(coords[key][1]-CENTER[1]))/hypot(27.2,21.0)/(38.0*720.0/1280.0)
    if sx<0.42:
        assert 12<=slant<=27,(key,"left facade should lean toward screen center",slant)
    elif sx>0.60:
        assert -27<=slant<=-12,(key,"right facade should lean toward screen center",slant)
    else:
        assert abs(slant)<=10,(key,"central facade should remain frontal",slant)
    assert abs(actual)<=180
assert len(set(YAW_DEGREES.values()))==8
# After the requested taller composition, retain eight unique inward yaw checks
# above, but use approved two-column vertical ordering instead of the old
# obsolete shrink-to-center metric (which would force all stations to crowd).
def downward(key):
    x,z=coords[key]
    return 21.0*x+27.2*z
assert downward("NEXUS") < downward("SMELTER") < downward("STORAGE") < downward("LABO") < downward("SCRAP_COLLECTOR")
assert downward("NEXUS") < downward("RECYCLER") < downward("GENERATOR") < downward("LABO") < downward("BUILD_TERMINAL")
assert coords["NEXUS"][1] < -19.0, "NEXUS must be at the upper edge of the expanded yard"
print("SERA_BASE_INWARD_RING_STATIC_PASS: eight camera-facing entrances, tall staggered layout")

"""Research-grounded fictional mechanical design hypotheses. No production asset replacement."""
import copy
import json
import sys
from pathlib import Path
import structural_variants as sv
import reference_design_variants as rv

SOURCES={
 "actuator":{"url":"https://www.harmonicdrive.net/products/miniature-products/miniature-actuators/fha-mini","observed":"Compact hollow-shaft actuator with cross roller output bearing.","scope":"Coaxial housing, output flange and bearing visual arrangement; no product dimensions."},
 "robot_arm":{"url":"https://patents.google.com/patent/EP2165808A1/en","observed":"Industrial robot arm housing, wrist and internal cable routing.","scope":"Distinct service housing and continuous core; no exact routing or engineering claims."},
 "gripper":{"url":"https://robotiq.com/products/adaptive-grippers","observed":"Three independent articulated fingers, multiple joints.","scope":"Separated finger root, link and contact pad; retain CRATE one hinge per finger."},
 "tracks":{"url":"https://www.cat.com/en_US/products/new/parts/undercarriage.html","observed":"Separate rollers, idlers and sprockets.","scope":"Open belt volume and distinct internal wheels; simplified static visual representation."},
 "track_links":{"url":"https://www.cat.com/en_US/articles/for-owners/small-dozers/small-dozer-track-pins-and-bushings.html","observed":"Track pins and bushings connect track links.","scope":"Visual link separation; no working track mechanics."},
 "cargo":{"url":"https://milremrobotics.com/milrem-robotics-exhibits-the-themis-ugv-at-feindef/","observed":"Cargo UGV designed to transport equipment and supplies, modular architecture.","scope":"Non-weapon cargo/support interface and modular vehicle appearance only."},
 "housing":{"url":"https://www.rittal.com/us-en_US/products/PG20231215SCH101/PG20231215SCH201/PRO0009?variantId=9114210","observed":"Cast aluminium enclosure with separate cover and captive cover screws.","scope":"Service covers and fastener appearance."},
 "optical":{"url":"https://www.baslerweb.com/en/accessories/ip67-housing/","observed":"Separate camera housing, lens housing and cable gland.","scope":"Protected inset optical perimeter; retain single cyan light bar, not a real sensor."}
}
# Each hypothesis carries the actual source and an explicit fictional interpretation.
RECIPES={
 "shoulder_actuator":("actuator","Compact concentric output flange and shaped shoulder mounting housing.","arms"),
 "elbow_actuator":("actuator","Coaxial stepped rotor and narrower retaining flange, fixed side stays fixed.","arms"),
 "arm_assembly":("robot_arm","Reposition elbow and wrist into a more continuous serial chain and rebuild the connected link housings; preserve rotational ranges.","arms"),
 "arm_service":("housing","Separate visible service seam and cover on forearm housing.","arms"),
 "wrist_flange":("actuator","Recessed ring and short output flange at the existing wrist axis.","arms"),
 "gripper_links":("gripper","Tapered fingers with distinct root and wear pad, no extra joint count.","arms"),
 "open_undercarriage":("tracks","Replace solid belt with continuous hollow loop and support rollers.","tracks"),
 "track_links":("track_links","Two-row pad rhythm and narrow guide ridge within existing belt envelope.","tracks"),
 "cargo_mount":("cargo","Separate storage mounting brackets from cargo shell, retain original size.","chest"),
 "optical_bezel":("optical","Separate narrow inner protective bezel, keep cyan strip unoccluded.","head")
}
RECIPES_TEXT={k:v[1] for k,v in RECIPES.items()}

def prepare(src,dest):
    rv.prepare(src,dest)
    d=json.loads(Path(dest).read_text())
    for k in ("track_split","track_hub","chest_plate","chest_upper_panel","pack_shell","head_crown","head_side_panel"):
        d=rv.mutate_structural(d,k)
    d["blockout_reference"]["baseline_iou"]={"front":.8762095,"right":.9378004}
    d["research_sources"]=SOURCES
    d["research_adaptations"]=[]
    d.setdefault("design_notes",[]).append("Industrial V4 starts from reproduced V3 selection; all dimensions are fictional author choices.")
    Path(dest).write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding="utf-8")

def append_part(d,name,parent,mat,kind,location,**kw):
    if any(p["name"]==name for p in d["parts"]):raise ValueError("duplicate "+name)
    p={"name":name,"parent":parent,"material":mat,"shape":kind,"location":location,"bevel":.001,"bevel_segments":1,**kw}
    d["parts"].append(p)
    return p

def flange(d,name,parent,loc,inner,outer,depth,rotation,mat="steel"):
    p=append_part(d,name,parent,mat,"cylinder",loc,radius=outer,depth=depth,rotation_deg=rotation)
    sv.ring(p,inner,outer,depth,min(.003,(outer-inner)*.25))
    return p

def belt(d,p,t,sign):
    rings=p["rings"]
    outer=[list(v) for r in rings for v in r]
    n=len(rings[0])
    # Inner contour is concentric with the outer profile in side projection.
    center=.12
    inner=[[x,y*.87,center+(z-center)*.76] for x,y,z in outer]
    verts=outer+inner;faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([[i,j,n+j,n+i],[2*n+i,3*n+i,3*n+j,2*n+j],
                      [i,2*n+i,2*n+j,j],[n+i,n+j,3*n+j,3*n+i]])
    sv.shape(p,"mesh",vertices=verts,faces=faces);p["bevel"]=.0015
    for i,y in enumerate((-.115,0,.115)):
        append_part(d,"TrackSupportRoller"+t+str(i),"BodyRoot","frame","cylinder",[sign*.212,y,.081],
                    radius=.044,depth=.105,sides=16,rotation_deg=[0,90,0])
        flange(d,"TrackSupportRim"+t+str(i),"BodyRoot",[sign*.268,y,.081],.014,.036,.008,[0,90,0])
    append_part(d,"TrackInnerFrame"+t,"BodyRoot","frame","box",[sign*.212,0,.139],size=[.102,.37,.055])

def mutate(spec,key):
    d=copy.deepcopy(spec);p={v["name"]:v for v in d["parts"]}
    if key=="optical_bezel":
        for z in (.024,.110):
            append_part(d,"VisorSeal"+str(int(z*1000)),"NeckPitch","frame","box",[0,-.237,z],size=[.284,.006,.005])
        for s in (-1,1):
            append_part(d,"VisorSealSide"+("L" if s<0 else "R"),"NeckPitch","frame","box",[s*.143,-.237,.067],size=[.005,.006,.081])
    else:
        for s,t in ((-1,"L"),(1,"R")):
            if key=="shoulder_actuator":
                a=p["Shoulder"+t];sv.ring(a,.029,.054,.060,.006)
                rv.chamfer_box(p["ShoulderMount"+t],.30)
                c=p["ShoulderCap"+t];c["radius"]=.041;c["depth"]=.012
                flange(d,"ShoulderOutputFlange"+t,"ShoulderJoint"+t,[s*.030,0,0],.028,.046,.010,[0,90,0])
            elif key=="elbow_actuator":
                a=p["ElbowRotor"+t];sv.ring(a,.0195,.035,.055,.005)
                for k in ("A","B"):
                    b=p["ElbowBearing"+t+k];sv.ring(b,.0195,.038,.013,.004)
                c=p["ElbowCap"+t];c["radius"]=.032;c["depth"]=.010;c["bevel"]=.002
            elif key=="arm_assembly":
                # After blockout, joint centers take precedence over projected contours.
                # Shift the fixed elbow fittings and rotating elbow subtree by the same vector.
                el=p["ElbowJoint"+t];wr=p["WristJoint"+t]
                de=[s*.034-el["location"][0],0,.010]
                dw=[s*.008-wr["location"][0],0,0]
                for n in ("ElbowJoint","ElbowAxle","ElbowCap","ElbowBearing"+t+"A","ElbowBearing"+t+"B","ElbowFork"+t+"A","ElbowFork"+t+"B"):
                    name=n if n.endswith(t+"A") or n.endswith(t+"B") else n+t
                    p[name]["location"]=[x+y for x,y in zip(p[name]["location"],de)]
                for n in ("WristJoint","WristBearing"):
                    a=p[n+t];a["location"]=[x+y for x,y in zip(a["location"],dw)]
                # Rebuild core endpoints in their own mesh-local coordinates, not in projection space.
                for n,j in (("UpperArmCore",el),("ForearmCore",wr)):
                    core=p[n+t];origin=core["location"]
                    core["path"]=[[ -x for x in origin],[x-y for x,y in zip(j["location"],origin)]]
                sv.shell(p["UpperArm"+t],p["UpperArmCore"+t],[[.032,.028],[.050,.045],[.053,.045],[.034,.031]],[.20,.34,.65,.78],8)
                sv.shell(p["Forearm"+t],p["ForearmCore"+t],[[.031,.029],[.055,.047],[.056,.051],[.038,.032]],[.13,.28,.64,.85],8)
            elif key=="arm_service":
                a=p["Forearm"+t];core=p["ForearmCore"+t]
                c=sv.mix(core["path"][0],core["path"][-1],.53)
                c=[v+w for v,w in zip(c,core["location"])]
                # Same moving parent; narrow service cover on outer surface.
                c[0]+=s*.043
                cover=append_part(d,"ForearmServiceCover"+t,"ElbowJoint"+t,"frame","box",c,size=[.011,.069,.041])
                rv.chamfer_box(cover,.30)
                for j in (-1,1):
                    append_part(d,"ForearmCoverFastener"+t+str(j),"ElbowJoint"+t,"steel","cylinder",[c[0]+s*.005,c[1]+j*.024,c[2]],radius=.004,depth=.003,sides=8,rotation_deg=[0,90,0])
            elif key=="wrist_flange":
                a=p["WristBearing"+t];sv.ring(a,.0235,.039,.036,.004)
                flange(d,"WristOutputFlange"+t,"WristJoint"+t,[0,-.013,0],.0235,.041,.009,[90,0,0])
            elif key=="gripper_links":
                for n in ("ClawTop","ClawLowerA","ClawLowerB"):
                    a=p[n+t];pad=p[n+"Pad"+t];q=1 if n=="ClawTop" else -1
                    w=.034 if q>0 else .015
                    a["location"]=[0,0,0]
                    sv.shape(a,"sweep",path=[[0,0,0],[0,-.025,q*.027],[0,-.059,q*.041],[0,-.100,q*.032],[0,-.128,q*.008]],
                             sections=[[w*.73,.017],[w,.021],[w,.022],[w*.86,.017],[w*.68,.011]],sides=8,up=[0,0,1])
                    a["bevel"]=.0018
                    pad["location"]=[0,-.126,q*.010]
                    sv.shape(pad,"box",size=[w*1.32,.016,.020]);pad["bevel"]=.002
                    pin=p[n+"Pin"+t]
                    pin["radius"]=.016;pin["depth"]=max(.025,w*1.85)
            elif key=="open_undercarriage":belt(d,p["Track"+t],t,s)
            elif key=="track_links":
                for n in ("TrackPads","TrackPadsOuter"):
                    a=p[n+t];a["size"][1]*=.91;a["bevel"]=.0012
                a=copy.deepcopy(p["TrackPads"+t]);a["name"]="TrackGuideRidge"+t
                a["location"][0]=s*.212;a["size"][0]=.015;a["size"][1]*=.78;a["size"][2]=.016
                a["material"]="frame";d["parts"].append(a)
            elif key=="cargo_mount":
                a=p["PackRail"+t];rv.chamfer_box(a,.34)
                for z in (.259,.404):
                    append_part(d,"PackMount"+t+str(int(z*1000)),"BodyRoot","frame","box",[s*.104,.158,z],size=[.055,.067,.026])
            else:raise ValueError(key)
    src,adaptation,_=RECIPES[key]
    d.setdefault("research_adaptations",[]).append({"recipe":key,"source":src,"url":SOURCES[src]["url"],"observed":SOURCES[src]["observed"],"adaptation":adaptation,"provenance":"fictional author interpretation; not manufacturer CAD or working engineering validation"})
    d.setdefault("iteration_history",[]).append(key)
    return d

def priority(key,m):
    # Establish the arm chain before working on fittings. Then use mechanical evidence.
    if key=="arm_assembly":return 1000000
    target=RECIPES[key][2]
    prefixes={"arms":("Shoulder","Elbow","Wrist","Claw"),"head":("Neck","Antenna"),"tracks":(),"chest":()}[target]
    return sum(s["cross_new"] for n,v in m["per_joint"].items() if n.startswith(prefixes) for s in v)

def guard(m,parent,base):
    # Post-blockout only: no full-body or local silhouette thresholds.
    return [r for r in sv.guard(m,parent,base) if not r.endswith(" silhouette")]

def score(m):
    return (-m["cross_new"],-m["cross_surface"],-m["motion_new"],-m["static"])

def exploratory(key,m,parent,reasons):
    return not reasons

def reference_observations(m,parent,base):
    return {"policy":"post_blockout_advisory_only","global_delta_vs_baseline":{k:m[k]-base[k] for k in ("front","right")},
            "local_delta_vs_baseline":{k:v-base["local_iou"][k] for k,v in m["local_iou"].items()},
            "visual_review_required":True}

if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])

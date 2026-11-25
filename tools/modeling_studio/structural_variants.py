"""Part-level redesign hypotheses, not merely offsets. All geometry in Blender via build.py."""
import copy
import json
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

RECIPES={
 "elbow_bores":"Replace solid bearings and rotor with coaxial annular parts and actual through bores.",
 "clevis_links":"Rebuild fixed clevis cheeks as shaped swept links leading into the bearing centers.",
 "upper_link_shell":"Rebuild upper armor along the actual shoulder-to-elbow core axis, with chamfered variable sections.",
 "forearm_shell":"Rebuild forearm armor on the actual elbow-to-wrist axis, fuller central section and tapered ends.",
 "claw_sweep":"Replace flat extruded fingers with independently tapered curved solid sweeps; align the pads with the tips.",
 "wrist_ring":"Replace wrist bearing with bored stepped ring, preserve pin and pivot.",
 "shoulder_ring":"Replace shoulder cover/body with stepped radial housing with a true axial opening.",
 "hand_hub":"Rebuild hand base as stepped circular housing with axial bore and shorter front lip.",
 "forearm_facets":"Alternative angled hard-surface forearm cross-sections with an asymmetric chamfer.",
 "finger_tip_profile":"Rebuild contact pads as small tapered sweeps along the finger contact surface."
}
def prepare(src,dest):
    # Reproduce accepted geometry changes from run 45612533208, without relying on expired artifacts.
    from iterative_review import mutate
    d=json.loads(Path(src).read_text())
    for key in ("outward_shoulders","elbow_clearance","forearm_profile","finger_spacing"):
        d=mutate(d,key)
    d["blockout_reference"]["baseline_iou"]={"front":.8842467665394994,"right":.9360300920290208}
    d.setdefault("design_notes",[]).append("Seed reconstructs accepted changes from iteration run 45612533208; not a new aesthetic approval.")
    Path(dest).write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding="utf-8")

def shape(p,kind,**data):
    for k in ("size","radius","depth","rings","path","sections","profile","vertices","faces","cuts","up","sides"):
        p.pop(k,None)
    p["shape"]=kind;p.update(data)
def ring(p,inner,outer,depth,step=0):
    # Closed radial profile; nonzero inner radius means a real bore, not intersecting solid cylinders.
    if not 0<inner<outer or depth<=0:raise ValueError("invalid bore")
    h=depth/2
    profile=[[inner,-h],[outer-step,-h],[outer,-h*.6],[outer,h*.6],[outer-step,h],[inner,h]] if step else [[inner,-h],[outer,-h],[outer,h],[inner,h]]
    shape(p,"revolve",profile=profile,sides=20)
    p["bevel"]=0.0008;p["bevel_segments"]=1

def mix(a,b,t):return [x+(y-x)*t for x,y in zip(a,b)]
def shell(p,core,sections,ts,sides=8):
    a,b=core["path"][0],core["path"][-1]
    # The preexisting core path is in the same authored world-offset mesh coordinates as the armor.
    shape(p,"sweep",path=[mix(a,b,t) for t in ts],sections=sections,sides=sides,up=[0,0,1])
    p["bevel"]=.003;p["bevel_segments"]=1
def mutate_structural(spec,key):
    d=copy.deepcopy(spec);p={v["name"]:v for v in d["parts"]}
    for sign,t in ((-1,"L"),(1,"R")):
        if key=="elbow_bores":
            for suffix in ("A","B"):
                a=p["ElbowBearing"+t+suffix];ring(a,.0195,a["radius"],a["depth"],.004)
            a=p["ElbowRotor"+t];ring(a,.0195,a["radius"],a["depth"],.003)
        elif key=="clevis_links":
            for suffix in ("A","B"):
                f=p["ElbowFork"+t+suffix];b=p["ElbowBearing"+t+suffix]
                # Local origin at bearing; sweep joins fixed upper link and bearing, rather than floating box.
                at=list(b["location"]);f["location"]=at;f["rotation_deg"]=[0,0,0]
                shape(f,"sweep",path=[[0,.052,.014],[0,.025,.008],[0,0,0]],
                      sections=[[.008,.020],[.009,.022],[.006,.024]],sides=8,up=[0,0,1]);f["bevel"]=.0015
        elif key=="upper_link_shell":
            shell(p["UpperArm"+t],p["UpperArmCore"+t],[[.028,.025],[.045,.040],[.046,.041],[.032,.029]],[.23,.35,.63,.76])
        elif key=="forearm_shell":
            shell(p["Forearm"+t],p["ForearmCore"+t],[[.029,.030],[.048,.051],[.052,.048],[.030,.033]],[.16,.29,.67,.83])
        elif key=="forearm_facets":
            shell(p["Forearm"+t],p["ForearmCore"+t],[[.032,.029],[.050,.043],[.052,.050],[.047,.043],[.030,.030]],[.12,.25,.49,.71,.85],6)
        elif key=="wrist_ring":
            a=p["WristBearing"+t];ring(a,.0235,.039,.039,.006)
        elif key=="shoulder_ring":
            a=p["Shoulder"+t];ring(a,.0285,.055,.068,.008)
        elif key=="hand_hub":
            a=p["HandBase"+t];ring(a,.0235,.047,.055,.009)
        elif key=="claw_sweep":
            # Finger hinge is the actual local origin. Upper and lower fingers curve in opposite directions.
            for n in ("ClawTop","ClawLowerA","ClawLowerB"):
                c=p[n+t];pad=p[n+"Pad"+t];upper=n=="ClawTop";q=1 if upper else -1
                c["location"]=[0,0,0];c["rotation_deg"]=[0,0,0]
                path=[[0,0,0],[0,-.038,q*.037],[0,-.087,q*.047],[0,-.120,q*.029],[0,-.137,q*.004]]
                width=.043 if upper else .018
                shape(c,"sweep",path=path,sections=[[width*.73,.018],[width,.023],[width*.95,.023],[width*.87,.019],[width*.74,.013]],sides=8,up=[0,0,1])
                c["bevel"]=.002;c["bevel_segments"]=1
                pad["location"]=[0,-.135,q*.007];pad["rotation_deg"]=[0,0,0]
                shape(pad,"box",size=[width*1.40,.018,.021]);pad["bevel"]=.003
        elif key=="finger_tip_profile":
            for n in ("ClawTop","ClawLowerA","ClawLowerB"):
                a=p[n+"Pad"+t];upper=n=="ClawTop";q=1 if upper else -1
                w=a.get("size",[.077 if upper else .031,.029,.019])[0]/2
                shape(a,"sweep",path=[[0,.010,q*.005],[0,-.002,0],[0,-.013,-q*.004]],
                      sections=[[w*.92,.010],[w,.012],[w*.80,.008]],sides=8,up=[0,0,1]);a["bevel"]=.001
        else:raise ValueError(key)
    d.setdefault("iteration_history",[]).append(key)
    return d

def priority(key,m):
    p=m["per_joint"]
    prefix={"elbow_bores":"Elbow","clevis_links":"Elbow","upper_link_shell":"Shoulder","forearm_shell":"Elbow",
            "forearm_facets":"Elbow","claw_sweep":"Claw","wrist_ring":"Wrist","shoulder_ring":"Shoulder",
            "hand_hub":"Wrist","finger_tip_profile":"Claw"}[key]
    return sum(s.get("cross_new",s["new"]) for n,v in p.items() if n.startswith(prefix) for s in v)

def cross_metrics(root,m):
    """Separate rigidly co-moving contacts from contacts across the actuated joint.
    No pair is whitelisted. Surface and containment candidates remain distinct."""
    root=Path(root);spec=json.loads((root/"design.json").read_text())
    parent={p["name"]:p.get("parent") for p in spec["parts"]}
    def below(n,j):
        while parent.get(n):
            n=parent[n]
            if n==j:return True
        return False
    def surface(row,j):
        return {tuple(sorted(x["parts"])) for x in row["candidates"] if x.get("surface_triangle_pairs",0)>0
                and below(x["parts"][0],j)!=below(x["parts"][1],j)}
    neutral=json.loads((root/"interference.json").read_text())
    report=json.loads((root/"motion_review.json").read_text())
    for sw in report["sweeps"]:
        j=sw["node"];base=surface(neutral,j)
        for a,b in zip(m["per_joint"][j],sw["samples"]):
            pairs=surface(b,j)
            a["cross_surface"]=len(pairs);a["cross_new"]=len(pairs-base)
    m["cross_surface"]=sum(s["cross_surface"] for v in m["per_joint"].values() for s in v)
    m["cross_new"]=sum(s["cross_new"] for v in m["per_joint"].values() for s in v)
    return m

def guard(m,parent,base):
    reasons=[]
    if m["nonmanifold"] or m["zero_area"]:reasons.append("topology")
    if not m["visibility"]:reasons.append("visibility")
    if not m["joints"]:reasons.append("hierarchy")
    for k,minimum in (("front",.87),("right",.92)):
        if m[k]<max(minimum,base[k]-.018,parent[k]-.010):reasons.append(k+" silhouette")
    if m["triangles"]>base["triangles"]*1.18:reasons.append("triangle budget")
    for k in ("cross_surface","cross_new"):
        if m[k]>parent[k]:reasons.append(k+" regression")
    for node,samples in parent["per_joint"].items():
        other=m["per_joint"].get(node,[])
        if [s["angle"] for s in samples]!=[s["angle"] for s in other]:reasons.append("pose mismatch "+node);continue
        if sum(s["cross_new"] for s in other)>sum(s["cross_new"] for s in samples)+2:reasons.append("joint regression "+node)
    return reasons

def score(m):return (-m["cross_new"],-m["cross_surface"],-m["motion_new"],-m["static"],(m["front"]+m["right"])/2)
def image_delta(root,parent):
    a=Image.open(root/"front_3q.png").convert("RGBA")
    b=Image.open(parent/"front_3q.png").convert("RGBA")
    if a.size!=b.size:raise ValueError("45 degree size differs")
    aa=a.getchannel("A");bb=b.getchannel("A")
    mask=ImageChops.lighter(aa,bb).point(lambda x:255 if x>=128 else 0)
    ar=Image.new("RGB",a.size,(35,43,53));ar.paste(a,mask=aa)
    br=Image.new("RGB",b.size,(35,43,53));br.paste(b,mask=bb)
    diff=ImageChops.difference(ar,br);r,g,b=diff.split()
    changed=ImageChops.darker(ImageChops.lighter(ImageChops.lighter(r,g),b).point(lambda x:255 if x>24 else 0),mask)
    return {"changed_foreground_fraction":changed.histogram()[255]/max(1,mask.histogram()[255]),"limits":"Pixel change, not aesthetic quality or reference fidelity."}
def sheet(root,rows):
    candidates=[("00_baseline",root/"00_baseline")]+[(str(r["round"])+" "+r["recipe"],root/(f"{r['round']:02d}_"+r["recipe"])) for r in rows if r["status"]=="rendered"]
    out=Image.new("RGB",(960,math.ceil(len(candidates)/3)*260),(35,43,53));draw=ImageDraw.Draw(out)
    for i,(label,p) in enumerate(candidates):
        x=(i%3)*320;y=(i//3)*260
        a=Image.open(p/"front_3q.png").convert("RGBA");a.thumbnail((310,225))
        out.paste(a,(x+(320-a.width)//2,y+25),a)
        draw.text((x+8,y+6),label,fill="white")
    out.save(root/"comparison_45.jpg",quality=92)

if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])

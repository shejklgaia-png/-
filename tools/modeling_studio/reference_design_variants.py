"""Reference-guided local silhouette and layered hard-surface studies for CRATE."""
import copy
import json
import math
import subprocess
import sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
import structural_variants as sv

HERE=Path(__file__).resolve().parent
RECIPES={
 "claw_section":"Three tapered faceted C-claws preserving the traced side contour and actual hinge.",
 "claw_pad":"Conform orange gripping tips to the finger end geometry rather than floating pads.",
 "elbow_fork":"Shape fixed clevis as a tapered link from bearing toward upper arm.",
 "head_crown":"Broader, shallower crown facets; retain the verified visor aperture.",
 "head_side_panel":"Recessed side armor panels from existing head face topology.",
 "chest_plate":"Recessed chest armor plate on the main sloped face.",
 "chest_upper_panel":"Separate upper sloping chest plate with dark frame.",
 "track_split":"Twin rows of tread pads with a central groove, preserving belt path.",
 "track_hub":"Chamfered service housing following the track side envelope.",
 "pack_shell":"Chamfered rear storage enclosure, preserving status strips."
}
def prepare(src,dest):
    from iterative_review import mutate
    d=json.loads(Path(src).read_text())
    for k in ("outward_shoulders","elbow_clearance","forearm_profile","finger_spacing"):
        d=mutate(d,k)
    for k in ("upper_link_shell","shoulder_ring","elbow_bores","forearm_shell","finger_tip_profile","hand_hub"):
        d=sv.mutate_structural(d,k)
    d["blockout_reference"]["baseline_iou"]={"front":.875498,"right":.936730}
    d.setdefault("design_notes",[]).append("V3 seed reconstructs accepted geometry of run 45616093830.")
    Path(dest).write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding="utf-8")

def vec(a,b):return [x-y for x,y in zip(a,b)]
def add(a,b):return [x+y for x,y in zip(a,b)]
def scale(a,s):return [x*s for x in a]
def mean(rows):return [sum(v[i] for v in rows)/len(rows) for i in range(3)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def norm(a):
    l=math.sqrt(sum(x*x for x in a))
    if l<1e-9:raise ValueError("degenerate vector")
    return scale(a,1/l)
def loft_mesh(p):
    if p["shape"]=="mesh":return
    rings=p["rings"];n=len(rings[0]);verts=[v for r in rings for v in r]
    faces=[list(range(n-1,-1,-1))]
    for j in range(len(rings)-1):
        for i in range(n):faces.append([j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i])
    faces.append(list(range((len(rings)-1)*n,len(rings)*n)))
    sv.shape(p,"mesh",vertices=verts,faces=faces)
def panelize(d,p,face_key,name,material,inset=.12,depth=.005):
    """Replace original quad with connected inset rim and recess; add a distinct insert.
    Face key is a set of vertex IDs, so prior insertions do not alter lookup."""
    loft_mesh(p);verts=p["vertices"];faces=p["faces"]
    idx=next(i for i,f in enumerate(faces) if set(f)==set(face_key))
    face=faces.pop(idx);outer=[verts[i] for i in face];c=mean(outer)
    n=norm(cross(vec(outer[1],outer[0]),vec(outer[2],outer[0])))
    rim=[add(c,scale(vec(v,c),1-inset)) for v in outer]
    floor=[add(v,scale(n,-depth)) for v in rim]
    prev=face
    for ring in (rim,floor):
        ids=list(range(len(verts),len(verts)+4));verts.extend(ring)
        faces.extend([[prev[i],prev[(i+1)%4],ids[(i+1)%4],ids[i]] for i in range(4)]);prev=ids
    faces.append(prev)
    # Insert sits below original surface, separated from the recess walls.
    center=mean(floor);bottom=[add(center,scale(vec(v,center),.94)) for v in floor]
    top=[add(v,scale(n,depth*.66)) for v in bottom]
    d["parts"].append({"name":name,"shape":"loft","material":material,"rings":[bottom,top],
        "location":p.get("location",[0,0,0]),"parent":p["parent"],"bevel":.0007,"bevel_segments":1})
    p["bevel"]=min(p.get("bevel",.002),.0015)
def chamfer_box(p,corner=.22):
    w,l,h=p["size"];rings=[]
    for z,q in ((-h/2,.90),(-h*.34,1),(h*.34,1),(h/2,.90)):
        x=w*q/2;y=l*q/2;c=min(x,y)*corner
        rings.append([[a,b,z] for a,b in ((-x+c,-y),(x-c,-y),(x,-y+c),(x,y-c),(x-c,y),(-x+c,y),(-x,y-c),(-x,-y+c))])
    sv.shape(p,"loft",rings=rings);p["bevel"]=.0018;p["bevel_segments"]=1
def mutate_structural(spec,key):
    d=copy.deepcopy(spec);p={v["name"]:v for v in d["parts"]}
    if key=="head_crown":
        for j in (4,5):
            for v in p["Head"]["vertices"][j*8:j*8+8]:
                v[0]*=1.12 if j==4 else 1.22
                v[2]-=.003 if j==4 else .005
        p["RoofServicePanel"]["location"][2]-=.004;p["RoofServiceCover"]["location"][2]-=.004
    elif key=="head_side_panel":
        for suffix,ids in (("R",[10,11,19,18]),("L",[14,15,23,22])):
            panelize(d,p["Head"],ids,"HeadSidePanel"+suffix,"white",.16,.004)
    elif key=="chest_plate":
        panelize(d,p["Chest"],[8,9,17,16],"ChestMainPanel","white",.10,.007)
        # Latch is placed on the actual lower chest slope instead of a protruding brick.
        p["ChestAccent"]["size"]=[.062,.010,.059];p["ChestAccent"]["location"]=[0,-.187,.188]
    elif key=="chest_upper_panel":
        panelize(d,p["Chest"],[16,17,25,24],"ChestUpperPanel","white",.11,.006)
    elif key=="pack_shell":chamfer_box(p["Pack"],.30)
    else:
        for sign,t in ((-1,"L"),(1,"R")):
            if key=="claw_section":
                for n in ("ClawTop","ClawLowerA","ClawLowerB"):
                    a=p[n+t];r0,r1=a["rings"][0],a["rings"][-1];rings=[]
                    for k in (.10,.20,.80,.90):
                        ring=[sv.mix(x,y,k) for x,y in zip(r0,r1)]
                        center=mean(ring)
                        if k in (.10,.90):
                            for v in ring:
                                v[1]=center[1]+(v[1]-center[1])*.94
                                v[2]=center[2]+(v[2]-center[2])*.94
                        rings.append(ring)
                    a["rings"]=rings;a["bevel"]=.002;a["bevel_segments"]=1
            elif key=="claw_pad":
                for n in ("ClawTop","ClawLowerA","ClawLowerB"):
                    a=p[n+t];pad=p[n+"Pad"+t];vs=[v for ring in a["rings"] for v in ring]
                    y=min(v[1] for v in vs);tip=[v for v in vs if v[1]<y+.025];c=add(mean(tip),a["location"])
                    pad["location"]=c;pad["location"][1]+=.004
                    w=(max(v[0] for v in tip)-min(v[0] for v in tip))*.80
                    sv.shape(pad,"box",size=[w,.018,.016]);pad["bevel"]=.0025;pad["bevel_segments"]=1
            elif key=="elbow_fork":
                for suffix in ("A","B"):
                    f=p["ElbowFork"+t+suffix];b=p["ElbowBearing"+t+suffix];f["location"]=list(b["location"])
                    sv.shape(f,"sweep",path=[[0,.042,.014],[0,.022,.008],[0,0,0]],sections=[[.006,.017],[.007,.020],[.006,.018]],sides=8,up=[0,0,1])
                    f["bevel"]=.001;f["bevel_segments"]=1
            elif key=="track_split":
                a=p["TrackPads"+t];b=copy.deepcopy(a);b["name"]="TrackPadsOuter"+t
                full=a["size"][0];a["size"][0]=b["size"][0]=full*.46
                a["location"][0]-=sign*full*.255;b["location"][0]+=sign*full*.255
                a["bevel"]=b["bevel"]=.001
                d["parts"].append(b)
            elif key=="track_hub":chamfer_box(p["TrackHub"+t],.32)
            else:raise ValueError(key)
    d.setdefault("iteration_history",[]).append(key)
    return d

GROUPS={"front":{"head":[0,1,2,3,4,5],"chest":[6,11],"arms":[7,8],"tracks":[9,10]},
        "right":{"head":[0,1,2],"chest":[3,4],"arms":[6,7,8],"tracks":[5]}}
def group(name):
    if name.startswith(("Head","Visor","LightBar","Roof","Antenna","Neck")):return "head"
    if name.startswith(("Shoulder","UpperArm","Elbow","Forearm","Wrist","Hand","Claw")):return "arms"
    if name.startswith(("Track","FrontWheel","RearWheel")):return "tracks"
    if name.startswith(("Chest","Chassis","Pack")):return "chest"
    return "unknown"
def local_metrics(root,m,blender):
    root=Path(root)
    log=root/"part_id_review.log"
    with log.open("w",encoding="utf-8") as f:
        subprocess.run([blender,"--background",str(root/"model.blend"),"--python-exit-code","1","--python",str(HERE/"part_id_review.py"),"--",str(root)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=180)
    idroot=root/"structure_analysis/truth"
    ids=json.loads((idroot/"manifest.json").read_text())["ids"]
    cfg=json.loads((root/"design.json").read_text())["blockout_reference"]
    out=root/"local_reference_review";out.mkdir()
    scores={}
    for view,groups in GROUPS.items():
        label=np.load(idroot/(view+".npy"),allow_pickle=False)
        n=label.shape[0];step=cfg["meters_per_trace_px"]*n/cfg["scale"]
        data=cfg["views"][view];ox,oy=data["origin"]
        targets={}
        for name,indexes in groups.items():
            im=Image.new("L",(n,n));draw=ImageDraw.Draw(im)
            for i in indexes:
                draw.polygon([(round(n/2+(x-ox)*step),round(n/2+(y-oy)*step+cfg["target_z"]*n/cfg["scale"])) for x,y in data["polygons"][i]],fill=255)
            targets[name]=np.asarray(im)>0
        ambiguous=sum(t.astype(np.uint8) for t in targets.values())>1
        valid=~ambiguous
        for name,ref in targets.items():
            actual=np.isin(label,[int(i) for i,v in ids.items() if group(v)==name])
            ref=ref&valid;actual=actual&valid
            both=ref&actual;union=ref|actual
            k=view+"_"+name
            scores[k]=float(both.sum()/max(1,union.sum()))
            overlay=np.zeros((n,n,3),np.uint8);overlay[:,:,0]=ref*255;overlay[:,:,1]=both*255;overlay[:,:,2]=actual*255
            overlay[ambiguous]=[90,90,90]
            Image.fromarray(overlay).save(out/(k+".png"))
    m["local_iou"]=scores;m["local_mean"]=sum(scores.values())/len(scores)
    (out/"evaluation.json").write_text(json.dumps({"scores":scores,"mean":m["local_mean"],"limits":"Approximate manually traced group polygons, visible Blender mesh IDs; overlaps in reference excluded. Not exact art or aesthetic score."},indent=2))
    return m
def priority(key,m):
    target={"claw_section":"arms","claw_pad":"arms","elbow_fork":"arms","head_crown":"head","head_side_panel":"head","chest_plate":"chest","chest_upper_panel":"chest","track_split":"tracks","track_hub":"tracks","pack_shell":"chest"}[key]
    return 1-min(v for k,v in m["local_iou"].items() if k.endswith("_"+target))
def guard(m,parent,base):
    reasons=sv.guard(m,parent,base)
    for k,v in m["local_iou"].items():
        if v<max(base["local_iou"][k]-.035,parent["local_iou"][k]-.020):
            reasons.append("local "+k)
    # Overall lightweight target retained; exact device cost remains separate.
    return reasons
def score(m):return (round(m["local_mean"],5),-m["cross_new"],-m["cross_surface"],-m["motion_new"],-m["static"])
def exploratory(key,m,parent,reasons):
    # Preserve non-degrading authored panel/track hypotheses for later visual review.
    return key in ("head_side_panel","chest_plate","chest_upper_panel","track_split","track_hub","pack_shell") and not reasons and m["local_mean"]>=parent["local_mean"]-.001
if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])

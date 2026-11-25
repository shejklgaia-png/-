"""V8: preserve V7 assemblies while reallocating triangle budget to visible structure."""
import argparse
import copy
import math
import shutil
import subprocess
from pathlib import Path
import assembly_repair as v7
import arm_search as ar
import industrial_design_variants as iv
import structural_variants as sv
import reference_design_variants as rv
from iterative_review import read,write,digest
from blockout_review import main as review_outline
from offline_viewer import make_viewer
HERE=Path(__file__).resolve().parent
RECIPES={
 "tread_lite":"Remove redundant intermediate tread ring; retain footprint, chamfered outline and contact top.",
 "guide_lite":"Remove tiny bevels from concealed guide blocks.",
 "wheel_lite":"Use 16 radial segments for grooved wheels; preserve groove and axle centers.",
 "chassis_support":"Add track mounting bridges and bottom protection within reclaimed budget.",
 "chest_armor":"Give chest main and upper covers a raised faceted central face and edge reveal.",
 "shoulder_rib":"Add cast-like lower supporting gussets between torso and fixed shoulder housing.",
 "neck_clearance":"Taper fixed upper neck shell around pitch clearance, without moving pivot.",
 "pack_clearance":"Slope the upper cargo shell away from head sweep; keep rear indicators.",
 "wrist_clearance":"Shift wrist up and slightly forward as an assembly, regenerate forearm core and armor.",
 "claw_clearance":"Refine lower finger arc and contact pads without changing hinge or motion range."
}
SOURCE={
 "tread_lite":"https://docs.blender.org/manual/en/5.0/modeling/modifiers/generate/decimate.html",
 "guide_lite":"https://docs.blender.org/manual/en/latest/modeling/meshes/editing/mesh/cleanup.html",
 "wheel_lite":"https://docs.blender.org/manual/en/5.0/modeling/modifiers/generate/decimate.html",
 "chassis_support":"https://patents.google.com/patent/US20090321152A1/en",
 "chest_armor":"https://patents.google.com/patent/US10933540B2/ja",
 "shoulder_rib":"https://patents.google.com/patent/US10933540B2/ja",
 "neck_clearance":"https://patents.google.com/patent/WO2024060212A1/en",
 "pack_clearance":"https://milremrobotics.com/milrem-robotics-exhibits-the-themis-ugv-at-feindef/",
 "wrist_clearance":"https://patents.google.com/patent/US10933540B2/ja",
 "claw_clearance":"https://robotiq.com/products/adaptive-grippers"
}
def prepare(src,dest):
    v7.prepare(src,dest)
    d=read(Path(dest))
    for k in ("neck_lift","shoulder_flange","elbow_clevis","elbow_cover","forearm_shell","claw_clearance","tread_blocks","inner_guides"):
        d=v7.mutate(d,k)
    d.setdefault("design_notes",[]).append("V8 reproduces V7 09_inner_guides; budget cannot exceed measured V7 baseline.")
    write(Path(dest),d)
def tread_lite(a):
    old=a["vertices"];faces=[];verts=[]
    if len(old)%24:raise ValueError("unexpected tread topology")
    # Direct authored topology, not arbitrary decimation. Use full-width middle ring at base height.
    for i in range(0,len(old),24):
        b=len(verts)
        # Interpolate along the local vertical edge to keep the original lower plane.
        for j in range(8):
            v=old[i+j];mid=old[i+8+j];top=old[i+16+j]
            # Center of each ring gives its normal-axis translation even on curved track.
            center=lambda start:[sum(old[i+start+k][q] for k in range(8))/8 for q in range(3)]
            c0,c1=center(0),center(8)
            verts.append([mid[q]+c0[q]-c1[q] for q in range(3)])
        verts.extend(copy.deepcopy(old[i+16:i+24]))
        faces.append([b+j for j in reversed(range(8))])
        for j in range(8):
            k=(j+1)%8;faces.append([b+j,b+k,b+8+k,b+8+j])
        faces.append([b+8+j for j in range(8)])
    sv.shape(a,"mesh",vertices=verts,faces=faces);a["bevel"]=0;a["weighted_normals"]=False
def panel(a,amount):
    # Retain existing seating ring; add one broad raised face with a narrow bevel reveal.
    bottom,top=a["rings"]
    c=rv.mean(top);n=rv.norm(rv.vec(rv.mean(top),rv.mean(bottom)))
    shoulder=[rv.add(c,rv.scale(rv.vec(v,c),.91)) for v in top]
    crown=[rv.add(rv.add(c,rv.scale(rv.vec(v,c),.82)),rv.scale(n,amount)) for v in top]
    a["rings"]=[bottom,top,shoulder,crown];a["bevel"]=0
def mutate(seed,key):
    if key=="chassis_support":
        d=v7.mutate(seed,key)
        for a in d["parts"]:
            if a["name"].startswith(("TrackMountBridge","TrackSkidPlate")):a["bevel"]=0
        return d
    d=copy.deepcopy(seed);p={a["name"]:a for a in d["parts"]}
    if key=="chest_armor":
        panel(p["ChestMainPanel"],.008);panel(p["ChestUpperPanel"],.005)
        # Central latch stays seated on the raised cover.
        p["ChestAccent"]["location"][1]-=.008
    elif key=="neck_clearance":
        a=p["Neck"]
        for j,ring in enumerate(a["rings"]):
            if j==0:continue
            for v in ring:
                v[0]*=.76 if j==1 else .70
                v[1]=.016+(v[1]-.016)*(.70 if j==1 else .62)
                v[2]-=.006 if j==2 else .003
    elif key=="pack_clearance":
        a=p["Pack"]
        for ring in a["rings"][-2:]:
            for v in ring:
                # Only the forward/top side; rear lights and rear face stay in position.
                if v[1]<0:v[2]-=.018 if ring is a["rings"][-1] else .009
    else:
        for s,t in ((-1,"L"),(1,"R")):
            if key=="tread_lite":
                for n in ("TrackPads","TrackPadsOuter"):tread_lite(p[n+t])
            elif key=="guide_lite":
                a=p["TrackGuideRidge"+t];a["bevel"]=0;a["weighted_normals"]=False
            elif key=="wheel_lite":
                for n in ("FrontWheel","RearWheel","TrackRoadRoller"):
                    for suffix in (("0","1","2") if n=="TrackRoadRoller" else ("",)):
                        a=p[n+t+suffix];a["sides"]=16;a["bevel"]=0
            elif key=="shoulder_rib":
                at=p["ShoulderJoint"+t]["location"]
                a=iv.append_part(d,"ShoulderLowerGusset"+t,"BodyRoot","frame","sweep",[0,0,0],
                    path=[[s*.113,at[1],at[2]-.081],[s*.151,at[1],at[2]-.060],[s*(abs(at[0])-.033),at[1],at[2]-.035]],
                    sections=[[.031,.016],[.027,.022],[.022,.013]],sides=6,up=[0,0,1])
                a["bevel"]=0
            elif key=="wrist_clearance":
                for n in ("WristJoint","WristBearing"):
                    a=p[n+t];a["location"][2]+=.010;a["location"][1]+=.006
                core=p["ForearmCore"+t];o=core["location"];end=p["WristJoint"+t]["location"]
                core["path"]=[[-v for v in o],[v-w for v,w in zip(end,o)]]
                a=p["Forearm"+t];sv.shell(a,core,copy.deepcopy(a["sections"]),[.12,.29,.65,.85],8)
            elif key=="claw_clearance":
                for n in ("ClawLowerA","ClawLowerB"):
                    a=p[n+t];pad=p[n+"Pad"+t]
                    # Leave root unchanged, taper outer arc and keep end pad aligned.
                    for i,v in enumerate(a["path"]):
                        f=i/(len(a["path"])-1);v[2]*=1-.18*f;v[1]*=1-.06*f
                    pad["location"][1]*=.94;pad["location"][2]*=.82
            else:raise ValueError(key)
    d["research_adaptations"].append({"recipe":key,"url":SOURCE[key],"adaptation":RECIPES[key],"provenance":"fictional geometry and topology choice; no engineering certification"})
    return d
def measure(root,blender):return v7.measure(root,blender)
def rank(m):
    return (m["neck_new"],m["arm_external"],m["cross_new"],m["cross_surface"],m["neck_surface"],m["triangles"])
def run(src,out,blender):
    root=Path(out).resolve();root.mkdir(parents=True,exist_ok=False)
    baseline=root/"00_baseline";shutil.copytree(src,baseline);make_viewer(baseline);base=measure(baseline,blender)
    winner=baseline;best=base;global_best=baseline;gm=base;rows=[]
    def report():
        write(root/"iteration_report.json",{"format":"SERA_BUDGET_REPAIR_V8","target_rounds":10,"attempts":len(rows),"successful":sum(r["status"]=="rendered" for r in rows),"baseline":base,"selected":global_best.name,"selected_metrics":gm,"redesign":winner.name,"redesign_metrics":best,"rounds":rows,"visual_acceptance":"pending","limits":"Contact candidates only, 80 discrete poses, no outline constraints or exemptions; triangle cap at reproduced V7 baseline. Numeric or guarded design hypotheses are not aesthetic approval."})
    report()
    for i,key in enumerate(RECIPES,1):
        candidate=root/(f"{i:02d}_"+key);source=root/(f"{i:02d}_design.json")
        row={"round":i,"recipe":key,"parent":winner.name,"source":SOURCE[key]}
        try:
            spec=mutate(read(winner/"design.json"),key);write(source,spec)
            with (root/(f"{i:02d}_blender.log")).open("w",encoding="utf-8") as f:
                subprocess.run([blender,"--background","--factory-startup","--python-exit-code","1","--python",str(HERE/"build.py"),"--",str(source),str(candidate)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=480)
            shutil.copy2(source,candidate/"design.json");review_outline(candidate);make_viewer(candidate);m=measure(candidate,blender)
            reasons=ar.hard(m,base)
            if m["triangles"]>base["triangles"]:reasons.append("V7 triangle budget")
            for k in ("neck_new","neck_surface","arm_external","arm_neutral_external"):
                if m[k]>best[k]:reasons.append(k+" regression")
            if m["cross_new"]>best["cross_new"]+2:reasons.append("cross_new regression")
            if key.endswith("_lite") and m["triangles"]>=best["triangles"]:reasons.append("no triangle reduction")
            improved=not reasons and rank(m)<rank(best)
            explore=not reasons and key in ("tread_lite","guide_lite","wheel_lite","chassis_support","chest_armor","shoulder_rib")
            accepted=improved or explore
            global_reasons=iv.guard(m,base,base)
            if m["triangles"]>base["triangles"]:global_reasons.append("V7 triangle budget")
            if m["neck_new"]>base["neck_new"] or m["arm_external"]>base["arm_external"]:global_reasons.append("target contact regression")
            ga=not reasons and not global_reasons and rank(m)<rank(gm)
            row.update(status="rendered",metrics=m,accepted=accepted,global_accepted=ga,guard_reasons=reasons,global_guard_reasons=global_reasons,decision="numeric improvement" if improved else ("guarded design hypothesis" if explore else "retain previous"),image_change_vs_baseline=sv.image_delta(candidate,baseline),triangle_savings=base["triangles"]-m["triangles"])
            if accepted:winner=candidate;best=m
            if ga:global_best=candidate;gm=m
            write(candidate/"round_review.json",row)
        except Exception as e:row.update(status="failed",accepted=False,error=str(e))
        rows.append(row);report()
    sv.sheet(root,rows)
    for name,folder in (("best",global_best),("redesign",winner)):
        shutil.copy2(folder/"viewer.html",root/(name+"_viewer.html"));shutil.copy2(folder/"model.glb",root/(name+"_model.glb"))
    write(root/"manifest.json",{p.relative_to(root).as_posix():{"bytes":p.stat().st_size,"sha256":digest(p)} for p in sorted(root.rglob("*")) if p.is_file() and p.name!="manifest.json"})
    if any(r["status"]!="rendered" for r in rows):raise SystemExit("one or more trials failed; artifacts retained")
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("mode",choices=("prepare","run"));ap.add_argument("source",type=Path);ap.add_argument("dest",type=Path);ap.add_argument("--blender",default="blender");a=ap.parse_args()
    if a.mode=="prepare":prepare(a.source,a.dest)
    else:run(a.source,a.dest,a.blender)

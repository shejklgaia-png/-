"""Ten sequential, guarded CRATE geometry experiments. Never modify production assets."""
import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path
from blockout_review import main as review_outline
from offline_viewer import make_viewer

HERE=Path(__file__).resolve().parent
def read(p): return json.loads(p.read_text(encoding="utf-8"))
def write(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding="utf-8")
def pairs(row):
    return {tuple(sorted(x["parts"])) for x in row["candidates"] if not x.get("declared_intentional")}
def digest(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):h.update(b)
    return h.hexdigest()

def metrics(root):
    mesh=read(root/"mesh_report.json")
    stat=pairs(read(root/"interference.json"))
    motion=read(root/"motion_review.json")["sweeps"]
    per={}
    for sw in motion:
        per[sw["node"]]=[{"angle":s["degrees"],"pairs":len(pairs(s)),
                          "new":len(pairs(s)-stat)} for s in sw["samples"]]
    views=read(root/"blockout_review/evaluation.json")["views"]
    visibility=read(root/"visibility_review.json")
    joints=read(root/"joint_hierarchy_review.json")
    return {"triangles":sum(x["triangles"] for x in mesh),"nonmanifold":sum(x["non_manifold_edges"] for x in mesh),
            "zero_area":sum(x["zero_area_faces"] for x in mesh),
            "front":views["front"]["iou"],"right":views["right"]["iou"],
            "visibility":visibility["all_passed"],"joints":joints["all_passed"],
            "static":len(stat),"motion":sum(s["pairs"] for v in per.values() for s in v),
            "motion_new":sum(s["new"] for v in per.values() for s in v),"per_joint":per}

def mutate(spec,key):
    d=copy.deepcopy(spec); p={x["name"]:x for x in d["parts"]}
    def translate(n,v):
        a=p[n];a["location"]=[x+y for x,y in zip(a.get("location",[0,0,0]),v)]
    for sign,t in [(-1,"L"),(1,"R")]:
        if key=="raise_shoulders":
            for n in ("ShoulderMount","ShoulderAxle","ShoulderJoint"):translate(n+t,[0,0,.013])
        elif key=="forward_shoulders":
            for n in ("ShoulderMount","ShoulderAxle","ShoulderJoint"):translate(n+t,[0,-.012,0])
        elif key=="outward_shoulders":
            for n in ("ShoulderAxle","ShoulderJoint"):translate(n+t,[sign*.009,0,0])
            p["ShoulderMount"+t]["size"][0]+=.018
        elif key=="wrist_extension":
            for n in ("WristBearing","WristJoint"):translate(n+t,[0,-.009,0])
            p["ForearmCore"+t]["path"][-1][1]-=.009
        elif key=="elbow_clearance":
            # Keep pin span and axis position; move fixed cheeks apart symmetrically.
            for suffix,direction in [("A",-1),("B",1)]:
                for n in ("ElbowBearing","ElbowFork"):translate(n+t+suffix,[direction*.003,0,0])
            p["ElbowAxle"+t]["depth"]+=.006
            translate("ElbowCap"+t,[sign*.003,0,0])
        elif key=="finger_spacing":
            # Move complete lower finger hinge and corresponding fixed pin, not only its visible shell.
            for suffix in ("A","B"):
                n="ClawLower"+suffix
                j=p[n+"Hinge"+t];x=j["location"][0]
                delta=.004 if x>=0 else -.004
                for name in (n+"Hinge"+t,n+"Pin"+t):translate(name,[delta,0,0])
        elif key=="forearm_profile":
            a=p["Forearm"+t]
            # Reshape cross sections about their own center; do not shrink link length.
            for ring in a["rings"]:
                z=sum(v[2] for v in ring)/len(ring)
                for v in ring:v[2]=z+(v[2]-z)*.94
        elif key=="head_support":
            # Move the pitch assembly and its axle together without changing angles.
            translate("NeckPitch",[0,0,.005]);translate("NeckPitchAxle",[0,0,.005])
            break
        elif key=="visor_width":
            # Recess opening remains unchanged; restore stronger signature bar proportion.
            p["LightBar"]["size"][0]=min(.252,p["LightBar"]["size"][0]+.008)
            break
        elif key=="armored_elbow":
            # Match reference's stepped circular cover without increasing its axial reach.
            p["ElbowCap"+t]["radius"]=min(.034,p["ElbowCap"+t]["radius"]+.003)
            p["ElbowCap"+t]["bevel"]=.003
        else:raise ValueError(key)
    # Visibility samples use absolute world coordinates; move them with the head when needed.
    if key=="head_support":
        for check in d["visibility_checks"]:
            for pt in check["points"]:pt[2]+=.005
    d.setdefault("iteration_history",[]).append(key)
    return d

RECIPES={
 "raise_shoulders":"Shoulder/track clearance: raise complete shoulder assemblies with fixed mounts.",
 "forward_shoulders":"Shoulder/track clearance: shift assemblies forward without changing pivots or ranges.",
 "outward_shoulders":"Arm/body clearance: outward shoulder offset, widen support.",
 "wrist_extension":"Move hand farther from forearm, extend core.",
 "elbow_clearance":"Separate fixed cheeks while preserving coaxial shaft.",
 "finger_spacing":"Separate lower fingers with their pins and hinges.",
 "forearm_profile":"Modestly alter forearm section height; preserve length.",
 "head_support":"Raise pitch assembly and axle together.",
 "visor_width":"Widen cyan feature within existing recess.",
 "armored_elbow":"Refine circular elbow cap profile."
}
def priority(key,m):
    j=m["per_joint"]
    def count(prefix):return sum(s["new"] for n,v in j.items() if n.startswith(prefix) for s in v)
    if key in ("raise_shoulders","forward_shoulders","outward_shoulders"):return count("Shoulder")
    if key in ("wrist_extension","elbow_clearance","forearm_profile","armored_elbow"):return count("Elbow")+count("Wrist")
    if key=="finger_spacing":return count("Claw")
    if key=="head_support":return count("Neck")
    return 0

def guard(candidate,parent,baseline):
    reasons=[]
    if candidate["nonmanifold"] or candidate["zero_area"]:reasons.append("topology")
    if not candidate["visibility"]:reasons.append("visibility")
    if not candidate["joints"]:reasons.append("joint hierarchy")
    for k,minimum in (("front",.87),("right",.92)):
        if candidate[k]<max(minimum,baseline[k]-.012,parent[k]-.006):reasons.append(k+" silhouette")
    if candidate["triangles"]>baseline["triangles"]*1.10:reasons.append("triangle budget")
    if candidate["static"]>parent["static"]:reasons.append("static candidates")
    if candidate["motion"]>parent["motion"]:reasons.append("motion candidates")
    if candidate["motion_new"]>parent["motion_new"]:reasons.append("new motion candidates")
    for node,samples in parent["per_joint"].items():
        other=candidate["per_joint"].get(node,[])
        if [x["angle"] for x in samples]!=[x["angle"] for x in other]:reasons.append("pose mismatch "+node);continue
        if sum(x["new"] for x in other)>sum(x["new"] for x in samples)+2:reasons.append("joint regression "+node)
    return reasons

def score(m):return (-m["motion_new"],-m["motion"],-m["static"],(m["front"]+m["right"])/2)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("baseline",type=Path);ap.add_argument("out",type=Path)
    ap.add_argument("--blender",default="blender")
    ap.add_argument("--structural",action="store_true")
    ap.add_argument("--reference-design",action="store_true")
    ap.add_argument("--industrial-design",action="store_true")
    a=ap.parse_args()
    if a.industrial_design:
        import industrial_design_variants as iv
        import reference_design_variants as rv
        import structural_variants as sv
        recipes,change,order,check,rank=iv.RECIPES_TEXT,iv.mutate,iv.priority,iv.guard,iv.score
        def measure(p):return rv.local_metrics(p,sv.cross_metrics(p,metrics(p)),a.blender)
    elif a.reference_design:
        import reference_design_variants as rv
        import structural_variants as sv
        recipes,change,order,check,rank=rv.RECIPES,rv.mutate_structural,rv.priority,rv.guard,rv.score
        def measure(p):return rv.local_metrics(p,sv.cross_metrics(p,metrics(p)),a.blender)
    elif a.structural:
        import structural_variants as sv
        recipes,change,order,check,rank=sv.RECIPES,sv.mutate_structural,sv.priority,sv.guard,sv.score
        def measure(p):return sv.cross_metrics(p,metrics(p))
    else:
        recipes,change,order,check,rank=RECIPES,mutate,priority,guard,score
        measure=metrics
    root=a.out.resolve();root.mkdir(parents=True,exist_ok=False)
    baseline=root/"00_baseline";shutil.copytree(a.baseline,baseline)
    make_viewer(baseline)
    initial=measure(baseline);winner=baseline;best=initial
    remaining=list(recipes);rows=[]
    def publish():
        report={"format":"SERA_ITERATION_REVIEW_V4" if a.industrial_design else ("SERA_ITERATION_REVIEW_V3" if a.reference_design else ("SERA_ITERATION_REVIEW_V2" if a.structural else "SERA_ITERATION_REVIEW_V1")),"target_rounds":10,"attempts":len(rows),
                "successful":sum(r.get("status")=="rendered" for r in rows),
                "selected":winner.name,"baseline":initial,"selected_metrics":best,"rounds":rows,
                "visual_acceptance":"pending human/assistant visual review",
                "limits":"Contact candidates are proxies, not physical collision certification. No range reduction, no contact whitelisting, no game asset changes. Selection uses numeric guards and, in V3/V4, guarded authored design hypotheses; aesthetic approval remains separate. Each successful round retains actual GLB, eight Blender renders and HTML."}
        write(root/"iteration_report.json",report)
    publish()
    for i in range(1,11):
        key=max(remaining,key=lambda k:order(k,best));remaining.remove(key)
        candidate=root/(f"{i:02d}_"+key)
        source=root/(f"{i:02d}_design.json")
        spec=change(read(winner/"design.json"),key)
        spec["blockout_reference"]["baseline_iou"]={"front":best["front"],"right":best["right"]}
        write(source,spec)
        row={"round":i,"recipe":key,"reason":recipes[key],"parent":winner.name}
        log=root/(f"{i:02d}_blender.log")
        try:
            with log.open("w",encoding="utf-8") as f:
                subprocess.run([a.blender,"--background","--factory-startup","--python-exit-code","1","--python",str(HERE/"build.py"),"--",str(source),str(candidate)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=480)
            shutil.copy2(source,candidate/"design.json")
            review_outline(candidate)
            make_viewer(candidate)
            m=measure(candidate)
            reasons=check(m,best,initial)
            if a.industrial_design:
                row["reference_observations"]=iv.reference_observations(m,best,initial)
            if a.structural or a.reference_design or a.industrial_design:
                row["image_change_vs_parent"]=sv.image_delta(candidate,winner)
                row["image_change_vs_baseline"]=sv.image_delta(candidate,baseline)
            improved=not reasons and rank(m)>rank(best)
            explore=not improved and ((a.industrial_design and iv.exploratory(key,m,best,reasons)) or (a.reference_design and rv.exploratory(key,m,best,reasons)))
            accepted=improved or explore
            row.update(status="rendered",metrics=m,accepted=accepted,guard_reasons=reasons,
                       decision="numeric improvement" if improved else ("guarded design hypothesis; visual approval pending" if explore else "retain previous candidate"))
            if accepted:winner=candidate;best=m
            write(candidate/"round_review.json",row)
        except Exception as e:
            row.update(status="failed",accepted=False,error=str(e))
        rows.append(row);publish()
    if a.structural or a.reference_design or a.industrial_design:
        sv.sheet(root,rows)
    shutil.copy2(winner/"viewer.html",root/"best_viewer.html")
    shutil.copy2(winner/"model.glb",root/"best_model.glb")
    write(root/"manifest.json",{p.relative_to(root).as_posix():{"bytes":p.stat().st_size,"sha256":digest(p)} for p in sorted(root.rglob("*")) if p.is_file() and p.name!="manifest.json"})
    if any(r["status"]!="rendered" for r in rows):raise SystemExit("one or more rounds failed; partial results retained")
if __name__=="__main__":main()

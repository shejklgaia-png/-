"""Keep a redesigned arm branch alive and search contact-driven joint parameters.
All candidates are built by Blender; reference outlines are diagnostic only."""
import argparse
import copy
import hashlib
import json
import math
import shutil
import subprocess
from collections import Counter
from pathlib import Path
import industrial_design_variants as iv
import structural_variants as sv
import reference_design_variants as rv
from iterative_review import metrics, digest, read, write
from blockout_review import main as review_outline
from offline_viewer import make_viewer

HERE=Path(__file__).resolve().parent
PARAMS={
    "outward":(.0,.060,.018),
    "forward":(-.030,.045,.015),
    "height":(-.025,.035,.012),
    "elbow_reach":(-.025,.030,.012),
    "wrist_reach":(-.024,.030,.012),
    "elbow_lateral":(-.018,.035,.012),
}
ARMS=("ShoulderJoint","ElbowJoint","WristJoint","Claw")
def prepare(src,dest):
    iv.prepare(src,dest)
    d=read(Path(dest))
    for k in ("shoulder_actuator","elbow_actuator","gripper_links","optical_bezel","track_links"):
        d=iv.mutate(d,k)
    for sw in d["motion_sweeps"]:sw["samples"]=5
    d["blockout_reference"]["baseline_iou"]={"front":.869889,"right":.919489}
    d["search_notes"]=["Reproduce V4 selected geometry. Five samples per joint for ALL models in this run; previous three-sample totals not comparable."]
    write(Path(dest),d)
def arm_variant(seed,params):
    # Reconstruct from a fixed redesigned branch seed, so trials do not accumulate drift.
    d=copy.deepcopy(seed);p={v["name"]:v for v in d["parts"]}
    def translate(name,delta):
        a=p[name]
        a["location"]=[x+y for x,y in zip(a.get("location",[0,0,0]),delta)]
    for s,t in ((-1,"L"),(1,"R")):
        dx=s*params["outward"]
        v=[dx,-params["forward"],params["height"]]
        for n in ("ShoulderJoint","ShoulderAxle","ShoulderMount"):translate(n+t,v)
        # Extend mount back toward body; attachment to chassis stays meaningful.
        mount=p["ShoulderMount"+t]
        if params["outward"]>0:
            for ring in mount["rings"]:
                for pt in ring:pt[0]=pt[0]*(1+params["outward"]/.063)-dx/2
        de=[s*params["elbow_lateral"],-params["elbow_reach"],0]
        for n in ("ElbowJoint","ElbowAxle","ElbowCap"):translate(n+t,de)
        for k in ("A","B"):
            for n in ("ElbowBearing","ElbowFork"):translate(n+t+k,de)
        dw=[0,-params["wrist_reach"],0]
        for n in ("WristJoint","WristBearing"):translate(n+t,dw)
        # Rebuild core and armor together from the real local pivot centers.
        for n,j in (("UpperArm","ElbowJoint"),("Forearm","WristJoint")):
            core=p[n+"Core"+t];armor=p[n+t];o=core["location"]
            end=p[j+t]["location"]
            if math.sqrt(sum(v*v for v in end))<.085:raise ValueError("link too short")
            core["path"]=[[-v for v in o],[v-w for v,w in zip(end,o)]]
            sections=copy.deepcopy(armor["sections"])
            ts=[.20,.34,.65,.78] if n=="UpperArm" else [.13,.28,.64,.85]
            sv.shell(armor,core,sections,ts,8)
    d["arm_search_parameters"]=params
    d["research_adaptations"].append({"recipe":"contact_driven_arm_search","url":"https://moveit.picknik.ai/main/doc/examples/planning_scene/planning_scene_tutorial.html","observed":"Collision checking can return colliding link pairs.","adaptation":"Use contact pairs and pose frequency to prioritize fictional arm geometry proposals; no contact exemption."})
    return d
def pair_review(root,m):
    spec=read(root/"design.json");parent={p["name"]:p.get("parent") for p in spec["parts"]}
    def below(n,j):
        while parent.get(n):
            n=parent[n]
            if n==j:return True
        return False
    def pairs(row,j):
        return {tuple(sorted(x["parts"])) for x in row["candidates"] if x.get("surface_triangle_pairs",0)>0 and below(x["parts"][0],j)!=below(x["parts"][1],j)}
    def external(ps,j):
        out={}
        for a,b in ps:
            moving,fixed=(a,b) if below(a,j) else (b,a)
            group=rv.group(fixed)
            if group in ("head","tracks","chest"):
                out[(moving,fixed)]=group
        return out
    neutral=read(root/"interference.json");report=read(root/"motion_review.json")
    counts=Counter();new_counts=Counter();pair_counts=Counter();rows=[];neutral_total=0
    for sw in report["sweeps"]:
        j=sw["node"]
        if not j.startswith(ARMS):continue
        base=external(pairs(neutral,j),j);neutral_total+=len(base)
        for row in sw["samples"]:
            current=external(pairs(row,j),j)
            new=set(current)-set(base)
            for pair,group in current.items():
                counts[group]+=1;pair_counts[(j,*pair)]+=1
            for pair in new:new_counts[current[pair]]+=1
            rows.append({"joint":j,"angle":row["degrees"],"pairs":[{"moving":a,"fixed":b,"group":group,"new":(a,b) in new} for (a,b),group in sorted(current.items())]})
    m.update(arm_external=sum(counts.values()),arm_external_new=sum(new_counts.values()),arm_neutral_external=neutral_total,external_groups=dict(counts),external_new_groups=dict(new_counts))
    write(root/"arm_pair_review.json",{"metrics":{k:m[k] for k in ("arm_external","arm_external_new","arm_neutral_external","external_groups","external_new_groups")},"top_pairs":[{"joint":k[0],"moving":k[1],"fixed":k[2],"pose_count":v} for k,v in pair_counts.most_common()],"poses":rows,"limits":"Surface intersection candidates only. Neutral is also counted; raw contacts preserved. No exemptions or exact penetration volume."})
    return m
def measure(root,blender):
    return pair_review(root,rv.local_metrics(root,sv.cross_metrics(root,metrics(root)),blender))
def branch_score(m):
    # Total and neutral contact counts prevent merely converting new contacts into pre-existing ones.
    return (m["arm_external"],m["arm_neutral_external"],m["arm_external_new"],m["cross_new"],m["cross_surface"],m["static"])
def hard(m,base):
    reasons=[]
    if m["nonmanifold"] or m["zero_area"]:reasons.append("topology")
    if not m["visibility"]:reasons.append("visibility")
    if not m["joints"]:reasons.append("hierarchy")
    if m["triangles"]>base["triangles"]*1.18:reasons.append("triangle budget")
    for j,samples in base["per_joint"].items():
        if [s["angle"] for s in samples]!=[s["angle"] for s in m["per_joint"].get(j,[])]:reasons.append("pose mismatch "+j)
    return reasons
def choices(current,m,visited):
    # Rank proposals by actual obstacle group; alternate signs where the effect is uncertain.
    g=m["external_groups"];h=g.get("head",0);t=g.get("tracks",0);c=g.get("chest",0)
    order=[("outward",1,2*(h+t+c)),("forward",1,h+t+c),("height",1,2*t-h),("height",-1,2*h-t),
           ("elbow_lateral",1,h+t+c),("wrist_reach",-1,t+h),("elbow_reach",-1,t+h),("forward",-1,t//2),
           ("wrist_reach",1,t//2),("elbow_reach",1,h//2),("elbow_lateral",-1,c//2),("outward",-1,0)]
    order.sort(key=lambda x:-x[2])
    for factor in (1,.5,.25):
        for name,direction,_ in order:
            low,high,step=PARAMS[name];p=dict(current)
            p[name]=round(min(high,max(low,p[name]+direction*step*factor)),6)
            key=tuple(p[k] for k in PARAMS)
            if p!=current and key not in visited:return name,p,key
    raise RuntimeError("bounded search exhausted")
def run(baseline_path,out,blender):
    root=Path(out).resolve();root.mkdir(parents=True,exist_ok=False)
    baseline=root/"00_baseline";shutil.copytree(baseline_path,baseline)
    make_viewer(baseline);base=measure(baseline,blender)
    seed=iv.mutate(read(baseline/"design.json"),"arm_assembly")
    params={k:0. for k in PARAMS};visited=set();branch=None;branch_m=None;global_best=baseline;global_m=base;rows=[]
    def publish():
        write(root/"iteration_report.json",{"format":"SERA_ARM_SEARCH_V5","target_rounds":10,"attempts":len(rows),"successful":sum(r["status"]=="rendered" for r in rows),"selected":global_best.name,"baseline":base,"selected_metrics":global_m,"arm_branch":branch.name if branch else None,"arm_branch_metrics":branch_m,"rounds":rows,"visual_acceptance":"pending","limits":"Five discrete samples per joint, no range changes, no silhouette thresholds. Branch retains redesign independently of global guard. Contact candidates are not collision certification; numeric selection is not visual approval."})
    publish()
    for i in range(1,11):
        if i==1:
            name="arm_assembly";p=dict(params);key=tuple(p.values())
        else:
            name,p,key=choices(params,branch_m or base,visited)
        visited.add(key)
        candidate=root/(f"{i:02d}_"+name);source=root/(f"{i:02d}_design.json")
        row={"round":i,"recipe":name,"parameters":p,"parent":branch.name if branch else baseline.name}
        try:
            spec=arm_variant(seed,p);write(source,spec)
            with (root/(f"{i:02d}_blender.log")).open("w",encoding="utf-8") as f:
                subprocess.run([blender,"--background","--factory-startup","--python-exit-code","1","--python",str(HERE/"build.py"),"--",str(source),str(candidate)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=480)
            shutil.copy2(source,candidate/"design.json");review_outline(candidate);make_viewer(candidate);m=measure(candidate,blender)
            reasons=hard(m,base)
            accepted=not reasons and (branch_m is None or branch_score(m)<branch_score(branch_m))
            # Production-neutral comparison: original winner kept unless mechanical guards also pass.
            global_reasons=iv.guard(m,base,base)
            if m["arm_external"]>base["arm_external"] or m["arm_neutral_external"]>base["arm_neutral_external"]:global_reasons.append("arm external regression")
            global_accept=not reasons and not global_reasons and branch_score(m)<branch_score(global_m)
            row.update(status="rendered",metrics=m,guard_reasons=reasons,global_guard_reasons=global_reasons,accepted=accepted,global_accepted=global_accept,
                       image_change_vs_baseline=sv.image_delta(candidate,baseline))
            if accepted:branch=candidate;branch_m=m;params=p
            if global_accept:global_best=candidate;global_m=m
            write(candidate/"round_review.json",row)
        except Exception as e:row.update(status="failed",accepted=False,error=str(e))
        rows.append(row);publish()
    sv.sheet(root,rows)
    for target,src in (("best",global_best),("arm_branch",branch)):
        if src is None:continue
        shutil.copy2(src/"viewer.html",root/(target+"_viewer.html"))
        shutil.copy2(src/"model.glb",root/(target+"_model.glb"))
    write(root/"manifest.json",{p.relative_to(root).as_posix():{"bytes":p.stat().st_size,"sha256":digest(p)} for p in sorted(root.rglob("*")) if p.is_file() and p.name!="manifest.json"})
    if any(r["status"]!="rendered" for r in rows):raise SystemExit("one or more trials failed; artifacts retained")
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("mode",choices=("prepare","run"));ap.add_argument("source",type=Path);ap.add_argument("dest",type=Path);ap.add_argument("--blender",default="blender");a=ap.parse_args()
    if a.mode=="prepare":prepare(a.source,a.dest)
    else:run(a.source,a.dest,a.blender)

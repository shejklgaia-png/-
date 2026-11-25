"""V7: repair V6 contacts while retaining compact shoulders and hollow tracks."""
import argparse
import copy
import math
import shutil
import subprocess
from pathlib import Path
from collections import Counter
import shoulder_track_search as v6
import arm_search as ar
import industrial_design_variants as iv
import structural_variants as sv
import reference_design_variants as rv
from iterative_review import read,write,digest
from blockout_review import main as review_outline
from offline_viewer import make_viewer
HERE=Path(__file__).resolve().parent
RECIPES={
 "neck_lift":"Raise pitch support and head together by 16mm.",
 "shoulder_flange":"Compact fixed flange and housing; retain coaxial attachment.",
 "neck_compact":"Narrow neck yaw bearing and add another 8mm of supported pitch clearance.",
 "elbow_clevis":"Paired tapered supports leading into fixed elbow bearings.",
 "elbow_cover":"Stepped concentric rotor and retaining cap.",
 "forearm_shell":"Stronger faceted central armor with tapered joint ends.",
 "claw_clearance":"Shorter and slightly shallower lower fingers with matching pads.",
 "tread_blocks":"Explicit faceted tread blocks on the existing common path.",
 "inner_guides":"Inner guide tabs and grooved wheel profiles, replacing exterior ridge.",
 "chassis_support":"Cross-body track mounting members and chamfered lower skid plate."
}
SOURCE={
 "neck_lift":"https://www.harmonicdrive.net/products/miniature-products/miniature-actuators/fha-mini",
 "shoulder_flange":"https://www.harmonicdrive.net/products/miniature-products/miniature-actuators/fha-mini",
 "neck_compact":"https://www.igus.com/robot-components",
 "elbow_clevis":"https://www.igus.com/robot-components",
 "elbow_cover":"https://www.harmonicdrive.net/products/miniature-products/miniature-actuators/fha-mini",
 "forearm_shell":"https://patents.google.com/patent/EP2165808A1/en",
 "claw_clearance":"https://robotiq.com/products/adaptive-grippers",
 "tread_blocks":"https://www.cat.com/en_US/support/maintenance/undercarriage/rubber-track/selection-guide.html",
 "inner_guides":"https://www.cat.com/en_US/blog/rubber-tracks-for-cat-equipment.html",
 "chassis_support":"https://www.cat.com/en_US/products/new/parts/undercarriage/undercarriage-compact-track-multi-terrain-loaders.html"
}
def prepare(src,dest):
    v6.prepare(src,dest)
    # Exact V6 independent winner 10_assembly10, not V5 numeric winner.
    d=v6.variant(read(Path(dest)),(.225,-.015,.016,-.024,-.026,.92,.093,.19699999999999998,.124,30,.72))
    d.setdefault("design_notes",[]).append("V7 starts from V6 10_assembly10; preserves hollow tracks and compact shoulders.")
    write(Path(dest),d)
def neck(d,p,dz,narrow=False):
    for n in ("NeckPitch","NeckPitchAxle"):p[n]["location"][2]+=dz
    for cfg in d["visibility_checks"]:
        for pt in cfg["points"]:pt[2]+=dz
    h=p["NeckPitch"]["location"][2]
    name="NeckPitchSupport"
    if name not in p:
        a=iv.append_part(d,name,"NeckYaw","frame","box",[0,0,h/2],size=[.086,.074,h])
    else:
        a=p[name];sv.shape(a,"box",size=[.086,.074,h]);a["location"]=[0,0,h/2]
    rv.chamfer_box(a,.25)
    if narrow:p["NeckYawBearing"]["radius"]=.052
def tread(p):
    # Arc-length sampling, closed faceted independent blocks. No extra bevel modifier.
    path=p["path"];edges=[(a,b,math.dist(a,b)) for a,b in zip(path,path[1:]+path[:1])]
    length=sum(e[2] for e in edges);count=p["count"];w,l,h=p["size"];verts=[];faces=[]
    for i in range(count):
        dist=(i+.5)*length/count
        for a,b,n in edges:
            if dist<=n:
                t=dist/n;y,z=sv.mix(a,b,t);dy=(b[0]-a[0])/n;dz=(b[1]-a[1])/n;break
            dist-=n
        # Existing path is counterclockwise, so right normal points outward.
        base=len(verts)
        for q,height in ((.90,-h/2),(1.,-h*.25),(.88,h/2)):
            x=w*q/2;u=l*q/2;c=min(x,u)*.20
            for X,Y in ((-x+c,-u),(x-c,-u),(x,-u+c),(x,u-c),(x-c,u),(-x+c,u),(-x,u-c),(-x,-u+c)):
                verts.append([X,y+dy*Y+dz*height,z+dz*Y-dy*height])
        faces.append([base+j for j in reversed(range(8))])
        for ring in range(2):
            for j in range(8):
                k=(j+1)%8
                faces.append([base+ring*8+j,base+ring*8+k,base+(ring+1)*8+k,base+(ring+1)*8+j])
        faces.append([base+16+j for j in range(8)])
    sv.shape(p,"mesh",vertices=verts,faces=faces);p["bevel"]=0;p["weighted_normals"]=False
def groove(a,r,depth):
    # Annular wheel with central guide channel. Shaft/hub remains a separate part.
    h=depth/2;g=.010;root=r-.009
    sv.shape(a,"revolve",profile=[[.014,-h],[r,-h],[r,-g],[root,-g],[root,g],[r,g],[r,h],[.014,h]],sides=20)
    a["bevel"]=.0007;a["bevel_segments"]=1
def mutate(seed,key):
    d=copy.deepcopy(seed);p={v["name"]:v for v in d["parts"]}
    if key=="neck_lift":neck(d,p,.016)
    elif key=="neck_compact":neck(d,p,.008,True)
    else:
        for s,t in ((-1,"L"),(1,"R")):
            if key=="shoulder_flange":
                a=p["ShoulderMountFlange"+t];sv.ring(a,.030,.046,.009,.003)
                a=p["ShoulderFixedHousing"+t];sv.ring(a,.029,.047,.030,.004)
                # Taper only the upper support edge; root and axis remain in place.
                a=p["ShoulderMount"+t];axis=p["ShoulderJoint"+t]["location"][2]
                for ring in a["rings"]:
                    for v in ring:
                        if v[2]>axis:v[2]=axis+(v[2]-axis)*.72
            elif key=="elbow_clevis":
                for k in ("A","B"):
                    a=p["ElbowFork"+t+k];b=p["ElbowBearing"+t+k]
                    a["location"]=list(b["location"]);a["rotation_deg"]=[0,0,0]
                    sv.shape(a,"sweep",path=[[0,.045,.012],[0,.022,.008],[0,.008,.003]],sections=[[.007,.019],[.008,.026],[.007,.026]],sides=8,up=[0,0,1])
                    a["bevel"]=.0015;a["bevel_segments"]=1
            elif key=="elbow_cover":
                a=p["ElbowRotor"+t];sv.ring(a,.0195,.035,.055,.006)
                a=p["ElbowCap"+t];a["radius"]=.034;a["depth"]=.010;a["bevel"]=.0025
                loc=list(a["location"]);loc[0]+=s*.006
                iv.append_part(d,"ElbowCapCenter"+t,"ShoulderJoint"+t,"frame","cylinder",loc,radius=.019,depth=.005,sides=16,rotation_deg=[0,90,0])
            elif key=="forearm_shell":
                a=p["Forearm"+t];sv.shell(a,p["ForearmCore"+t],[[.029,.027],[.050,.043],[.054,.046],[.031,.028]],[.12,.29,.65,.85],8)
            elif key=="claw_clearance":
                for n in ("ClawLowerA","ClawLowerB"):
                    a=p[n+t];pad=p[n+"Pad"+t]
                    for v in a["path"]:v[1]*=.89;v[2]*=.90
                    pad["location"][1]*=.89;pad["location"][2]*=.90
            elif key=="tread_blocks":
                for n in ("TrackPads","TrackPadsOuter"):tread(p[n+t])
            elif key=="inner_guides":
                a=p["TrackGuideRidge"+t];cfg=d["track_design"];r=cfg["inner_radius"];half=cfg["wheel_half_spacing"]
                a["path"]=v6.capsule(r-.003,.114,half)
                a["size"]=[.014,.028,.010];a["bevel"]=.0005
                for n in ("FrontWheel","RearWheel","TrackRoadRoller"):
                    for suffix in (("0","1","2") if n=="TrackRoadRoller" else ("",)):
                        w=p[n+t+suffix];groove(w,w["radius"],w["depth"])
            elif key=="chassis_support":
                for j,y in enumerate((-.137,.137)):
                    a=iv.append_part(d,"TrackMountBridge"+t+str(j),"BodyRoot","frame","box",[s*.145,y,.137],size=[.124,.060,.047])
                    rv.chamfer_box(a,.30)
                a=iv.append_part(d,"TrackSkidPlate"+t,"BodyRoot","steel","box",[s*.112,0,.062],size=[.065,.295,.019]);rv.chamfer_box(a,.25)
            else:raise ValueError(key)
    d["research_adaptations"].append({"recipe":key,"url":SOURCE[key],"adaptation":RECIPES[key],"provenance":"fictional interpretation; no engineering certification"})
    return d
def measure(root,blender):
    m=ar.measure(root,blender)
    d=read(root/"design.json");parent={p["name"]:p.get("parent") for p in d["parts"]}
    def below(a,j):
        while parent.get(a):
            a=parent[a]
            if a==j:return True
        return False
    def pairs(row,j):
        return {tuple(sorted(x["parts"])) for x in row["candidates"] if x.get("surface_triangle_pairs",0)>0 and below(x["parts"][0],j)!=below(x["parts"][1],j)}
    static=read(root/"interference.json");motion=read(root/"motion_review.json")
    counts=Counter();rows=[];total=0;new=0
    for sw in motion["sweeps"]:
        j=sw["node"]
        if not j.startswith("Neck"):continue
        base=pairs(static,j)
        for s in sw["samples"]:
            ps=pairs(s,j);total+=len(ps);new+=len(ps-base)
            for pair in ps-base:counts[(j,*pair)]+=1
            rows.append({"joint":j,"angle":s["degrees"],"pairs":sorted(ps),"new":sorted(ps-base)})
    m["neck_surface"]=total;m["neck_new"]=new
    write(root/"neck_pair_review.json",{"surface":total,"new":new,"top_new_pairs":[{"joint":k[0],"parts":k[1:],"poses":v} for k,v in counts.most_common()],"poses":rows})
    return m
def rank(m):
    return (m["neck_new"],m["neck_surface"],m["arm_external"],m["cross_new"],m["cross_surface"],m["triangles"])
def run(src,out,blender):
    root=Path(out).resolve();root.mkdir(parents=True,exist_ok=False)
    baseline=root/"00_baseline";shutil.copytree(src,baseline);make_viewer(baseline);base=measure(baseline,blender)
    winner=baseline;best=base;global_best=baseline;gm=base;rows=[]
    def report():
        write(root/"iteration_report.json",{"format":"SERA_REPAIR_V7","target_rounds":10,"attempts":len(rows),"successful":sum(r["status"]=="rendered" for r in rows),"baseline":base,"selected":global_best.name,"selected_metrics":gm,"redesign":winner.name,"redesign_metrics":best,"rounds":rows,"visual_acceptance":"pending","limits":"Contact candidates only, 80 discrete poses, no outline constraints or exemptions; numeric or guarded design hypotheses are not aesthetic approval."})
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
            for k in ("neck_new","neck_surface","arm_external","arm_neutral_external"):
                if m[k]>best[k]:reasons.append(k+" regression")
            if m["cross_new"]>best["cross_new"]+2:reasons.append("cross_new regression")
            improved=not reasons and rank(m)<rank(best)
            explore=not reasons and key in ("elbow_clevis","elbow_cover","forearm_shell","tread_blocks","inner_guides","chassis_support")
            accepted=improved or explore
            global_reasons=iv.guard(m,base,base)
            if m["neck_new"]>base["neck_new"] or m["arm_external"]>base["arm_external"]:global_reasons.append("target contact regression")
            ga=not reasons and not global_reasons and rank(m)<rank(gm)
            row.update(status="rendered",metrics=m,accepted=accepted,global_accepted=ga,guard_reasons=reasons,global_guard_reasons=global_reasons,decision="numeric improvement" if improved else ("guarded design hypothesis" if explore else "retain previous"),image_change_vs_baseline=sv.image_delta(candidate,baseline))
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

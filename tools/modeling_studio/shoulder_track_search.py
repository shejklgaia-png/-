"""V6 shoulder mounts and shared-path hollow undercarriage studies."""
import argparse
import copy
import math
import shutil
import subprocess
from pathlib import Path
import arm_search as ar
import industrial_design_variants as iv
import structural_variants as sv
import reference_design_variants as rv
from iterative_review import read,write,digest
from blockout_review import main as review_outline
from offline_viewer import make_viewer
HERE=Path(__file__).resolve().parent
SOURCES={
 "shoulder":"https://www.harmonicdrive.net/products/miniature-products/miniature-actuators/fha-mini",
 "track":"https://www.cat.com/en_US/products/new/parts/undercarriage/undercarriage-compact-track-multi-terrain-loaders.html",
 "idler":"https://parts.cat.com/en/catcorp/product/560-6422"
}
def prepare(src,dest):
    ar.prepare(src,dest)
    d=iv.mutate(read(Path(dest)),"arm_assembly")
    d=ar.arm_variant(d,dict(outward=.060,forward=.015,height=.035,elbow_reach=0.,wrist_reach=0.,elbow_lateral=0.))
    d["blockout_reference"]["baseline_iou"]={"front":.810799,"right":.898350}
    write(Path(dest),d)
def capsule(r,z,half,n=12):
    # Two straight runs with tangent semicircles at the wheel axes.
    return [[side*half+r*math.cos(math.radians(a)),z+r*math.sin(math.radians(a))]
            for side,start in ((1,-90),(-1,90)) for a in [start+180*i/n for i in range(n+1)]]
def hollow(p,cx,width,outer,inner):
    n=len(outer)
    verts=[[cx+side*width/2,y,z] for path in (outer,inner) for side in (-1,1) for y,z in path]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([[i,j,n+j,n+i],[2*n+i,3*n+i,3*n+j,2*n+j],[i,2*n+i,2*n+j,j],[n+i,n+j,3*n+j,3*n+i]])
    sv.shape(p,"mesh",vertices=verts,faces=faces)
    p["location"]=[0,0,0];p["bevel"]=.001
def add(d,n,parent,mat,shape,loc,**kw):
    return iv.append_part(d,n,parent,mat,shape,loc,**kw)
def cylinder(d,n,parent,mat,loc,r,depth):
    return add(d,n,parent,mat,"cylinder",loc,radius=r,depth=depth,sides=16,rotation_deg=[0,90,0])
def shoulders(d,offset,dy,dz,elbow,wrist,profile):
    p={x["name"]:x for x in d["parts"]}
    for sign,t in ((-1,"L"),(1,"R")):
        joint=p["ShoulderJoint"+t]
        old=joint["location"];at=[sign*offset,old[1]+dy,old[2]+dz]
        delta=[x-y for x,y in zip(at,old)]
        joint["location"]=at
        axle=p["ShoulderAxle"+t];axle["location"]=list(at);axle["depth"]=.080
        # Broad root overlaps the torso side, tapered housing meets the fixed actuator flange.
        mount=p["ShoulderMount"+t];rings=[]
        for x,cy,cz,ry,rz in ((.105,at[1]+.012,at[2]-.016,.067,.053),(.142,at[1]+.008,at[2]-.010,.065,.050),(offset-.040,at[1],at[2],.048,.042),(offset-.026,at[1],at[2],.040,.036)):
            # Monotonic X section positions even at compact offsets.
            rings.append([[sign*x,cy+ry*math.cos(i*math.pi/4),cz+rz*math.sin(i*math.pi/4)] for i in range(8)])
        sv.shape(mount,"loft",rings=rings);mount["location"]=[0,0,0];mount["material"]="white";mount["bevel"]=.004
        h=iv.flange(d,"ShoulderFixedHousing"+t,"BodyRoot",[sign*(offset-.026),at[1],at[2]],.029,.050,.030,[0,90,0],"frame")
        iv.flange(d,"ShoulderMountFlange"+t,"BodyRoot",[sign*(offset-.043),at[1],at[2]],.030,.054,.010,[0,90,0],"steel")
        sv.ring(p["Shoulder"+t],.029,.053,.038,.006)
        p["Shoulder"+t]["location"]=[sign*.013,0,0]
        cap=p["ShoulderCap"+t];cap["location"]=[sign*.039,0,0];cap["radius"]=.042;cap["depth"]=.010
        flange=p["ShoulderOutputFlange"+t];flange["location"]=[sign*.030,0,0]
        # Shift fixed and moving elbow/wrist members together, then regenerate link axes.
        for n in ("ElbowJoint","ElbowAxle","ElbowCap"):
            a=p[n+t];a["location"][1]-=elbow
        for n in ("ElbowBearing","ElbowFork"):
            for k in ("A","B"):p[n+t+k]["location"][1]-=elbow
        for n in ("WristJoint","WristBearing"):p[n+t]["location"][1]-=wrist
        for n,j in (("UpperArm","ElbowJoint"),("Forearm","WristJoint")):
            core=p[n+"Core"+t];armor=p[n+t];o=core["location"]
            end=p[j+t]["location"]
            if math.sqrt(sum(x*x for x in end))<.085:raise ValueError("link too short")
            core["path"]=[[-x for x in o],[x-y for x,y in zip(end,o)]]
            sections=[[x*profile,y*profile] for x,y in armor["sections"]]
            sv.shell(armor,core,sections,[.20,.34,.65,.78] if n=="UpperArm" else [.13,.28,.64,.85],8)
    d["shoulder_design"]={"axis_abs_x":offset,"root_x":.105,"forward_delta":dy,"height_delta":dz,"elbow_reach":elbow,"wrist_reach":wrist,"armor_scale":profile}
def tracks(d,r=.096,half=.205,width=.134,count=32,cover=.80):
    p={x["name"]:x for x in d["parts"]}
    z=.114;inner=r-.015;outer=capsule(r,z,half);inside=capsule(inner,z,half);padpath=capsule(r+.004,z,half)
    length=sum(math.dist(a,b) for a,b in zip(padpath,padpath[1:]+padpath[:1]))
    for sign,t in ((-1,"L"),(1,"R")):
        cx=sign*.212
        hollow(p["Track"+t],cx,width,outer,inside)
        for n,side in (("TrackPads",-1),("TrackPadsOuter",1),("TrackGuideRidge",0)):
            a=p[n+t];a["path"]=padpath;a["count"]=count
            a["location"]=[cx+sign*side*width*.25,0,0]
            a["size"]=[width*.46 if side else .012,length/count*(.88 if side else .78),.018 if side else .014]
            a["bevel"]=.001
        # End wheels and bottom rollers are derived from the same inner path.
        for prefix,y in (("FrontWheel",-half),("RearWheel",half)):
            a=p[prefix+t];a["location"]=[cx,y,z];a["radius"]=inner-.001;a["depth"]=width*.82
            for suffix,rad,dep,off in (("Rim",inner*.82,.010,.055),("Hub",inner*.46,.008,.064),("Axle",inner*.20,.006,.070)):
                a=p[prefix+suffix+t];a["location"]=[cx+sign*off,y,z];a["radius"]=rad;a["depth"]=dep
        for i,y in enumerate((-.118,0,.118)):
            rad=.046
            rz=z-inner+rad+.001
            cylinder(d,"TrackRoadRoller"+t+str(i),"BodyRoot","frame",[cx,y,rz],rad,width*.76)
            cylinder(d,"TrackRoadRim"+t+str(i),"BodyRoot","steel",[cx+sign*.052,y,rz],rad*.70,.009)
            cylinder(d,"TrackRoadHub"+t+str(i),"BodyRoot","frame",[cx+sign*.059,y,rz],rad*.30,.008)
        f=add(d,"TrackSupportFrame"+t,"BodyRoot","frame","box",[cx-sign*.020,0,z+.008],size=[width*.44,half*1.86,.054])
        rv.chamfer_box(f,.26)
        # Simplified tensioner, not a working mechanical mechanism.
        add(d,"TrackTensioner"+t,"BodyRoot","steel","sweep",[[cx-sign*.015,-half+.026,z],[cx-sign*.015,-half+.092,z]][0],path=[[0,0,0],[0,.066,0]],sections=[[.022,.022],[.022,.022]],sides=8)
        a=p["TrackHub"+t];sv.shape(a,"box",size=[.019,half*cover,.056]);a["location"]=[cx+sign*.064,0,z+.022];rv.chamfer_box(a,.25)
        a=p["TrackHubInset"+t];a["location"]=[cx+sign*.076,0,z+.022];a["size"]=[.006,half*cover*.70,.029]
        for n,y in (("F",-half*cover*.34),("B",half*cover*.34)):
            a=p["TrackHubBolt"+t+n];a["location"]=[cx+sign*.081,y,z+.022];a["radius"]=.005
    d["track_design"]={"radius":r,"inner_radius":inner,"wheel_half_spacing":half,"width":width,"pads":count,"nominal_ground_z":z-r-.004-.009,
                      "end_wheel_radial_clearance":.001,"roller_radial_clearance":.001,"source":"common tangent path; fictional static assembly"}
def variant(seed,params):
    d=copy.deepcopy(seed)
    shoulders(d,*params[:6]);tracks(d,*params[6:])
    d["research_adaptations"].extend([{"recipe":"v6_shoulders","url":SOURCES["shoulder"],"adaptation":"Fixed mount and output flange; compact cast housing."},{"recipe":"v6_tracks","url":SOURCES["track"],"adaptation":"Shared tangent path, open belt, separate end wheels and road rollers."},{"recipe":"v6_idler","url":SOURCES["idler"],"adaptation":"Visible simplified tensioner; not engineering validation."}])
    return d
# Diverse shoulder/link and track alternatives; avoid repeatedly moving only the shoulder.
TRIALS=[
 (.205,0,0,0,0,1,.096,.205,.134,32,.80),
 (.215,-.012,.004,-.010,-.012,.96,.096,.205,.134,32,.80),
 (.225,-.022,.008,-.012,-.016,.96,.096,.205,.134,32,.80),
 (.205,-.020,.012,.008,-.014,.92,.090,.205,.134,32,.80),
 (.215,-.028,.012,-.014,.010,.94,.090,.195,.124,30,.72),
 (.225,-.015,.016,-.016,-.018,.92,.093,.205,.124,30,.72),
]
def rank(m,params):
    # Contact quality first, then compact shoulder position, not outline matching.
    return (m["arm_external"],m["arm_neutral_external"],m["cross_new"],params[0],m["cross_surface"],m["triangles"])
def run(src,out,blender):
    root=Path(out).resolve();root.mkdir(parents=True,exist_ok=False)
    baseline=root/"00_baseline";shutil.copytree(src,baseline);make_viewer(baseline);base=ar.measure(baseline,blender)
    seed=read(baseline/"design.json");best=None;bm=None;bp=None;global_best=baseline;gm=base;gp=(.258,)
    rows=[];visited=set()
    def report():
        write(root/"iteration_report.json",{"format":"SERA_SHOULDER_TRACK_V6","target_rounds":10,"attempts":len(rows),"successful":sum(r["status"]=="rendered" for r in rows),"baseline":base,"selected":global_best.name,"selected_metrics":gm,"redesign":best.name if best else None,"redesign_metrics":bm,"rounds":rows,"visual_acceptance":"pending","limits":"Static fictional track mechanism; single-joint five-pose samples. No silhouette constraints, no contact exemptions. Numeric ranking is not aesthetic approval."})
    report()
    for i in range(1,11):
        if i<=len(TRIALS):params=TRIALS[i-1]
        else:
            # Four feedback refinements vary four different design dimensions.
            origin=bp or TRIALS[0];params=list(origin)
            k,step=((3,-.008),(4,-.008),(0,-.008),(7,-.008))[i-7]
            if k==0:params[k]=max(.200,params[k]+step)
            else:params[k]+=step
            params=tuple(params)
            if params in visited:
                params=list(origin);params[k]+=abs(step);params=tuple(params)
        visited.add(params)
        name="assembly"+str(i);candidate=root/(f"{i:02d}_"+name);source=root/(f"{i:02d}_design.json")
        row={"round":i,"recipe":name,"parameters":list(params),"parent":best.name if best and i>6 else baseline.name}
        try:
            spec=variant(seed,params);write(source,spec)
            with (root/(f"{i:02d}_blender.log")).open("w",encoding="utf-8") as f:
                subprocess.run([blender,"--background","--factory-startup","--python-exit-code","1","--python",str(HERE/"build.py"),"--",str(source),str(candidate)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=480)
            shutil.copy2(source,candidate/"design.json");review_outline(candidate);make_viewer(candidate);m=ar.measure(candidate,blender)
            reasons=ar.hard(m,base)
            global_reasons=iv.guard(m,base,base)
            if m["arm_external"]>base["arm_external"] or m["arm_neutral_external"]>base["arm_neutral_external"]:global_reasons.append("arm external regression")
            accepted=not reasons and (bm is None or rank(m,params)<rank(bm,bp))
            ga=not reasons and not global_reasons and rank(m,params)<rank(gm,gp)
            row.update(status="rendered",metrics=m,accepted=accepted,global_accepted=ga,guard_reasons=reasons,global_guard_reasons=global_reasons,shoulder_design=spec["shoulder_design"],track_design=spec["track_design"],image_change_vs_baseline=sv.image_delta(candidate,baseline))
            if accepted:best=candidate;bm=m;bp=params
            if ga:global_best=candidate;gm=m;gp=params
            write(candidate/"round_review.json",row)
        except Exception as e:row.update(status="failed",accepted=False,error=str(e))
        rows.append(row);report()
    sv.sheet(root,rows)
    for label,folder in (("best",global_best),("redesign",best)):
        if folder is None:continue
        shutil.copy2(folder/"viewer.html",root/(label+"_viewer.html"));shutil.copy2(folder/"model.glb",root/(label+"_model.glb"))
    write(root/"manifest.json",{p.relative_to(root).as_posix():{"bytes":p.stat().st_size,"sha256":digest(p)} for p in sorted(root.rglob("*")) if p.is_file() and p.name!="manifest.json"})
    if any(r["status"]!="rendered" for r in rows):raise SystemExit("one or more trials failed; artifacts retained")
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("mode",choices=("prepare","run"));ap.add_argument("source",type=Path);ap.add_argument("dest",type=Path);ap.add_argument("--blender",default="blender");a=ap.parse_args()
    if a.mode=="prepare":prepare(a.source,a.dest)
    else:run(a.source,a.dest,a.blender)

"""AI-authored CRATE surface recipe evaluated by the existing Texture Studio painter."""
import sys,json
from pathlib import Path
from collections import defaultdict
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"texture_studio"))
from ai_pipeline import bake,geometry

def write(p,v):
    p.write_text(json.dumps(v,indent=2,allow_nan=False),encoding="utf-8")

def main(root):
    out=Path(root)/"textured"
    g=json.loads((out/"surface_geometry.json").read_text())
    uv=json.loads((out/"face_uv.json").read_text())
    # UV connectivity on original polygon loops, never across triangle diagonals.
    parents=list(range(len(g["faces"])))
    def find(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]];i=parents[i]
        return i
    edges={}
    for f,coords in zip(g["faces"],uv):
        for i,a in enumerate(f["vertices"]):
            j=(i+1)%len(coords);b=f["vertices"][j]
            u,v=coords[i],coords[j]
            if a>b:a,b,u,v=b,a,v,u
            key=(f["part"],a,b,tuple(round(x,6) for x in u),tuple(round(x,6) for x in v))
            if key in edges:parents[find(f["id"])]=find(edges[key])
            else:edges[key]=f["id"]
    pos=[];tex=[];parts=[];charts=[];groups=[[] for _ in uv]
    for i,t in enumerate(g["triangles"]):
        f=g["faces"][t["face"]];corners=t["corners"]
        pos.extend(x for k in corners for x in f["positions"][k])
        tex.extend(x for k in corners for x in uv[f["id"]][k])
        parts.append(t["part"]);charts.append(find(f["id"]));groups[f["id"]].append(i)
    tex=np.asarray(tex)
    if tex.min()<-1e-6 or tex.max()>1+1e-6:raise ValueError("atlas UV outside square")
    mesh={"positions":pos,"uvs":tex.clip(0,1).tolist(),"parts":parts,"chart":charts,"source_faces":groups}
    p,u,c,face,part,n,edge,quad,digest=geometry(mesh)
    palette={"white":[231,231,225],"dark":[61,68,77],"orange":[244,140,41],"steel":[134,146,156],
             "cyan":[73,223,240],"rubber":[68,71,76],"frame":[101,112,124],"black":[32,40,47]}
    mats=[f["material"] for f in g["faces"]]
    if set(mats)-set(palette):raise ValueError("unexpected materials "+str(set(mats)-set(palette)))
    layers=[];log=[]
    # V16: no automatic cross-section rings, broad decorative bands, or
    # unscoped planes. A geometric joint seam belongs to the game ID outline,
    # not the albedo. Only defined maintenance features are painted below.
    # V15: projected, chamfered maintenance panels on the actual exterior faces.
    # Color accents are materials, not directional lighting. Projected detail
    # spans polygon boundaries without relying on the UV chart orientation.
    def scoped(pid,axis,sign):
        ids=np.flatnonzero((part==pid)&(n[:,axis]*sign>.35))
        return sorted(set(int(face[t]) for t in ids))
    def line(pid,faces,axes,points,width,color):
        if not faces:return
        layers.append({"kind":"projected_stroke","parts":[pid],"faces":faces,
            "axes":axes,"points":points,"width":width,"color":color})
    def bolt(pid,faces,axes,q,r=.003):
        if not faces:return
        for width,color in ((r*1.5,[47,54,62]),(r,[155,164,171]),(r*.35,[48,53,61])):
            layers.append({"kind":"projected_dot","parts":[pid],"faces":faces,
                "axes":axes,"center":q,"width":width,"color":color})
    def hatch(pid,faces,axes,lo,hi,ch=.008,bolts=True):
        x,y=lo;X,Y=hi
        pts=[[x+ch,y],[X-ch,y],[X,y+ch],[X,Y-ch],[X-ch,Y],[x+ch,Y],[x,Y-ch],[x,y+ch],[x+ch,y]]
        line(pid,faces,axes,pts,.005,[150,158,165])
        line(pid,faces,axes,pts,.0024,[39,47,55])
        if bolts:
            for a,b in ((x+ch*1.5,y+ch*1.5),(X-ch*1.5,y+ch*1.5),(x+ch*1.5,Y-ch*1.5),(X-ch*1.5,Y-ch*1.5)):
                bolt(pid,faces,axes,[a,b])
    for row in g["parts"]:
        pid=row["id"];name=row["name"]
        if name=="Chest":
            for sign in (-1,1):
                fs=scoped(pid,0,sign)
                hatch(pid,fs,[2,1],[-.094,.200],[.119,.318],.018)
                # Paint only the physically recessed socket floor.
                ids=np.flatnonzero((part==pid)&(n[:,0]*sign>.35))
                for t in ids:
                    q=p[t].mean(0)
                    if abs(q[0])<.128 and .226<q[1]<.292 and -.007<q[2]<.079:
                        mats[int(face[t])]="recess"
                # Contacts and retainer only on the actual socket floor, not its rim.
                floor=[f for f in fs if mats[f]=="recess" and
                       max(abs(v[0]) for v in g["faces"][f]["positions"])<.125]
                line(pid,floor,[2,1],[[.013,.242],[.059,.242],[.059,.276],[.013,.276],[.013,.242]],.0025,[110,122,134])
                for z in (.022,.036,.050):
                    bolt(pid,floor,[2,1],[z,.259],.0025)
                log.append({"part":pid,"purpose":"recess connector contacts","floor_faces":len(floor)})
            fs=scoped(pid,2,1)
            hatch(pid,fs,[0,1],[-.081,.200],[.081,.285],.013)

        elif name=="Pack":
            fs=scoped(pid,2,-1)
            hatch(pid,fs,[0,1],[-.051,.263],[.051,.401],.012)
            ids=np.flatnonzero((part==pid)&(n[:,2]<-.35))
            for t in ids:
                q=p[t].mean(0)
                if abs(q[0])<.039 and .279<q[1]<.384 and q[2]>-.286:
                    mats[int(face[t])]="recess"
            floor=[f for f in fs if mats[f]=="recess" and
                   min(v[2] for v in g["faces"][f]["positions"])>-.280]
            for y in (.303,.318,.333,.348,.363):
                line(pid,floor,[0,1],[[-.029,y],[.029,y]],.003,[24,32,40])
                line(pid,floor,[0,1],[[-.027,y+.005],[.027,y+.005]],.0016,[113,127,139])
            log.append({"part":pid,"purpose":"recess cooling fins","floor_faces":len(floor)})
        elif name.startswith("TrackHub") and name[-1] in ("L","R"):
            sign=-1 if name[-1]=="L" else 1
            fs=scoped(pid,0,sign)
            hatch(pid,fs,[2,1],[-.049,.119],[.049,.153],.006)

        elif name=="Head":
            fs=scoped(pid,2,-1)
            hatch(pid,fs,[0,1],[-.128,.535],[.128,.633],.014)
        elif name in ("ShoulderCapL","ShoulderCapR","ElbowCapL","ElbowCapR"):
            sign=-1 if name[-1]=="L" else 1
            pts=p[part==pid];lo=pts.min((0,1));hi=pts.max((0,1))
            fs=scoped(pid,0,sign)
            # Real end-cap face only; fasteners sit on the existing removable cap.
            outer=hi[0] if sign>0 else lo[0]
            fs=[f for f in fs if all(abs(v[0]-outer)<.003 for v in g["faces"][f]["positions"])]
            center=(lo+hi)/2
            rad=.029 if name.startswith("Shoulder") else .026
            for ang in np.linspace(0,2*np.pi,6,endpoint=False):
                bolt(pid,fs,[2,1],[float(center[2]+rad*np.cos(ang)),float(center[1]+rad*np.sin(ang))],.0023)
            log.append({"part":pid,"purpose":"existing removable bearing end-cap fasteners","faces":len(fs)})
        elif name.startswith("Forearm") and name[-1] in ("L","R") and "Core" not in name:
            sign=-1 if name[-1]=="L" else 1
            fs=scoped(pid,0,sign)
            pts=p[part==pid];lo=pts.min((0,1));hi=pts.max((0,1))
            dz=hi[2]-lo[2];dy=hi[1]-lo[1]
            # Find a closed chamfered hatch whose outline and fasteners
            # remain on the projected outward arm surface.
            axes=[2,1];tris=p[(part==pid)&(n[:,0]*sign>.35)][:,:,axes]
            center=(lo[axes]+hi[axes])/2
            span=(hi[axes]-lo[axes])/2*np.array([.62,.56])
            def covered(points):
                q=np.asarray(points,float)
                hit=np.zeros(len(q),bool)
                for tri in tris:
                    a=(tri[1:]-tri[0]).T
                    if abs(np.linalg.det(a))<1e-12:continue
                    w=(q-tri[0])@np.linalg.inv(a).T
                    hit|=(w>=-1e-7).all(1)&(w.sum(1)<=1+1e-7)
                return bool(hit.all())
            for scale in (1,.9,.8,.7,.6,.5,.4):
                x,y=(center-span*scale).tolist();X,Y=(center+span*scale).tolist()
                ch=min(.005,(X-x)*.18,(Y-y)*.18)
                pts=np.array([[x+ch,y],[X-ch,y],[X,y+ch],[X,Y-ch],[X-ch,Y],[x+ch,Y],[x,Y-ch],[x,y+ch],[x+ch,y]])
                samples=np.concatenate([np.linspace(a,b,25) for a,b in zip(pts[:-1],pts[1:])])
                bolts=[[x+ch*1.5,y+ch*1.5],[X-ch*1.5,y+ch*1.5],[x+ch*1.5,Y-ch*1.5],[X-ch*1.5,Y-ch*1.5]]
                if covered(np.concatenate([samples,bolts])):
                    hatch(pid,fs,axes,[x,y],[X,Y],ch)
                    log.append({"part":pid,"fitted_hatch_scale":scale,"projected_samples":len(samples)+len(bolts)})
                    break
            else:log.append({"part":pid,"fitted_hatch":"no closed fit"})
    # Scope checks prevent arbitrary lines returning to axes, pins and pivots.
    allowed={"Chest","Pack","Head","TrackHubL","TrackHubR","ForearmL","ForearmR",
             "ShoulderCapL","ShoulderCapR","ElbowCapL","ElbowCapR"}
    for layer in layers:
        if layer["kind"] not in ("projected_stroke","projected_dot") or not layer.get("faces"):
            raise ValueError("unscoped or decorative line")
        for pid in layer["parts"]:
            if g["parts"][pid]["name"] not in allowed:raise ValueError("unexpected painted component")
            if any(g["faces"][f]["part"]!=pid for f in layer["faces"]):raise ValueError("foreign face scope")
    palette["recess"]=[39,46,54]
    plan={"geometry_sha256":digest,"resolution":2048,"supersample":1,"padding":3,
          "light":[-.18,1,.32],"ambient":1.0,"direct":0.0,"palette":palette,
          "face_material":mats,"emissive_materials":["cyan"],"layers":layers}
    write(out/"surface_plan.json",plan)
    write(out/"paint_intent.json",{"status":"candidate","rules":"functional hatches, recess contacts and cooling fins, actual removable bearing cap fasteners only; no unscoped rings or directional diffuse bake","fasteners":log,
         "uv":"repacked existing Modeling Studio UVs; inspect density and raster collisions; no manual approval"})
    bake(mesh,plan,out/"paint")

if __name__=="__main__":main(sys.argv[1])

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
    def plane(pid,axis,offset,width,color,opacity=1,faces=None,relief=False):
        row={"kind":"plane","parts":[pid],"normal":[int(i==axis) for i in range(3)],
             "offset":float(offset),"width":float(width),"color":color,"opacity":opacity,"relief":relief}
        if faces is not None:row["faces"]=faces
        layers.append(row)
    def dot(pid,q,width,color,relief=False):
        layers.append({"kind":"dot","parts":[pid],"center":q.tolist(),"width":width,"color":color,"relief":relief})
    def seam(pid,axis,ratio,fasten=False):
        ids=np.flatnonzero(part==pid);pts=p[ids];lo=pts.min((0,1));hi=pts.max((0,1))
        span=hi-lo;offset=lo[axis]+span[axis]*ratio
        width=min(.0032,max(.0016,span[axis]*.012))
        plane(pid,axis,offset,width*2.1,[145,152,158],.9)
        plane(pid,axis,offset,width,[44,53,63])
        plane(pid,axis,offset+width*1.7,width*.6,[247,246,237],.65)
        if not fasten:return
        # Locate actual triangle/offset-plane intersections rather than floating bolt coordinates.
        points=[]
        for tri in pts:
            hits=[]
            for a,b in zip(tri,np.roll(tri,-1,axis=0)):
                v=b[axis]-a[axis]
                if abs(v)>1e-9:
                    t=(offset+width*3-a[axis])/v
                    if 0<=t<=1:hits.append(a+(b-a)*t)
            if len(hits)>=2:points.append((hits[0]+hits[1])/2)
        chosen=[]
        for q in sorted(points,key=lambda q:(float(q[0]),float(q[2]),float(q[1]))):
            if all(np.linalg.norm(q-v)>.043 for v in chosen):
                chosen.append(q)
                if len(chosen)>=12:break
        for q in chosen:
            dot(pid,q,.0048,[52,61,69]);dot(pid,q,.0031,[149,159,167],True)
        log.append({"part":pid,"seam_axis":axis,"fastener_centers":len(chosen)})
    # Authored cover division, different directions for head, body, arm and drivetrain.
    for row in g["parts"]:
        pid=row["id"];name=row["name"];ids=np.flatnonzero(part==pid)
        if not len(ids):continue
        pts=p[ids];lo=pts.min((0,1));hi=pts.max((0,1));span=hi-lo
        if name=="Head":
            seam(pid,1,.74,True);seam(pid,2,.22,True)
        elif name=="Chest":
            seam(pid,1,.28,True);seam(pid,1,.79,True)
        elif name=="Pack":
            seam(pid,1,.77,True)
            rear=sorted(set(int(face[t]) for t in ids if n[t,2]<-.75))
            if rear:
                for frac in (.35,.43,.51,.59):
                    plane(pid,1,lo[1]+span[1]*frac,.003,[29,37,46],1,rear,True)
        elif name=="Chassis":
            seam(pid,1,.39,True)
        elif name.startswith(("UpperArm","Forearm")) and "Core" not in name:
            seam(pid,int(np.argmax(span)),.29,True)
        elif name.startswith(("TrackHub","TrackSkidPlate")):
            seam(pid,2,.28,True)
        elif name.startswith(("Shoulder","ElbowCap","HandBase")) and "Mount" not in name and span.max()>.06:
            seam(pid,int(np.argmax(span)),.62,False)
        elif name.startswith(("ClawTop","ClawLower","Antenna")) and mats[int(face[ids[0]])] in ("white","steel","frame") and span.max()>.075:
            seam(pid,int(np.argmax(span)),.74,False)
        elif name=="RoofServiceCover":
            seam(pid,0,.25,True)
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
                for y in (.243,.256,.269):
                    line(pid,fs,[2,1],[[.009,y],[.064,y]],.003,[42,49,57])
            fs=scoped(pid,2,1)
            hatch(pid,fs,[0,1],[-.081,.200],[.081,.285],.013)
            line(pid,fs,[0,1],[[-.052,.245],[-.024,.245],[-.012,.255],[.012,.255],[.024,.245],[.052,.245]],.004,[87,101,113])
        elif name=="Pack":
            fs=scoped(pid,2,-1)
            hatch(pid,fs,[0,1],[-.051,.263],[.051,.401],.012)
            ids=np.flatnonzero((part==pid)&(n[:,2]<-.35))
            for t in ids:
                q=p[t].mean(0)
                if abs(q[0])<.039 and .279<q[1]<.384 and q[2]>-.286:
                    mats[int(face[t])]="recess"
            for y in (.303,.318,.333,.348,.363):
                line(pid,fs,[0,1],[[-.029,y],[.029,y]],.004,[33,41,49])
                line(pid,fs,[0,1],[[-.027,y+.006],[.027,y+.006]],.0018,[113,127,139])
            for sign in (-1,1):
                sf=scoped(pid,0,sign)
                hatch(pid,sf,[2,1],[-.269,.266],[-.169,.392],.012)
        elif name.startswith("TrackHub") and name[-1] in ("L","R"):
            sign=-1 if name[-1]=="L" else 1
            fs=scoped(pid,0,sign)
            hatch(pid,fs,[2,1],[-.049,.119],[.049,.153],.006)
            for z in (-.029,0,.029):bolt(pid,fs,[2,1],[z,.136],.0023)
        elif name=="Head":
            for sign in (-1,1):
                fs=scoped(pid,0,sign)
                hatch(pid,fs,[2,1],[-.172,.524],[-.080,.599],.012)
            fs=scoped(pid,2,-1)
            hatch(pid,fs,[0,1],[-.128,.535],[.128,.633],.014)
        elif name.startswith(("Forearm","UpperArm")) and name[-1] in ("L","R") and "Core" not in name:
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
    palette["recess"]=[39,46,54]
    plan={"geometry_sha256":digest,"resolution":2048,"supersample":1,"padding":3,
          "light":[-.18,1,.32],"ambient":1.0,"direct":0.0,"palette":palette,
          "face_material":mats,"emissive_materials":["cyan"],"layers":layers}
    write(out/"surface_plan.json",plan)
    write(out/"paint_intent.json",{"status":"candidate","rules":"scoped chamfered access hatches, actual recess floors, flat surface color; no directional diffuse bake","fasteners":log,
         "uv":"repacked existing Modeling Studio UVs; inspect density and raster collisions; no manual approval"})
    bake(mesh,plan,out/"paint")

if __name__=="__main__":main(sys.argv[1])

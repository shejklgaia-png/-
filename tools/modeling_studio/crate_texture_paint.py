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
    plan={"geometry_sha256":digest,"resolution":2048,"supersample":1,"padding":3,
          "light":[-.18,1,.32],"ambient":.78,"direct":.20,"palette":palette,
          "face_material":mats,"emissive_materials":["cyan"],"layers":layers}
    write(out/"surface_plan.json",plan)
    write(out/"paint_intent.json",{"status":"candidate","rules":"full-body cover divisions, actual surface fasteners, rear vents, upper light","fasteners":log,
         "uv":"repacked existing Modeling Studio UVs; inspect density and raster collisions; no manual approval"})
    bake(mesh,plan,out/"paint")

if __name__=="__main__":main(sys.argv[1])

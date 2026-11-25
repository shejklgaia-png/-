"""Soft orthographic region correspondence, with explicit ambiguity and missing views."""
import itertools
import math
import numpy as np
import cv2

def camera(cfg):
    x,y,z=map(float,cfg["camera_rotation"])
    cx,sx=math.cos(x),math.sin(x)
    cy,sy=math.cos(y),math.sin(y)
    cz,sz=math.cos(z),math.sin(z)
    r=np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])@np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])@np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    n=int(cfg["resolution"]); scale=float(cfg["ortho_scale"])
    origin=np.array(cfg["camera_location"],float)
    if n<=0 or scale<=0 or not np.isfinite(np.r_[r.ravel(),origin,scale]).all():
        raise ValueError("invalid camera")
    return {"right":r[:,0],"up":r[:,1],"normal":r[:,2],"origin":origin,"step":scale/n,"n":n,"scale":scale}

def regions(labels,image,cam):
    if labels.shape!=(cam["n"],cam["n"]) or image.shape[:2]!=labels.shape:
        raise ValueError("camera/image dimensions differ")
    lab=cv2.cvtColor(image,cv2.COLOR_BGR2LAB).astype(float)
    rows={}
    for rid in np.unique(labels):
        if rid==0: continue
        y,x=np.where(labels==rid)
        if len(x)<12: continue
        px=(x+.5-cam["n"]/2)*cam["step"]
        py=(cam["n"]/2-y-.5)*cam["step"]
        xyz=cam["origin"]+px[:,None]*cam["right"]+py[:,None]*cam["up"]
        rows[int(rid)]={"points":xyz,"center":xyz.mean(axis=0),"lab":np.median(lab[y,x],axis=0),
                       "area_m2":len(x)*cam["step"]**2}
    return rows

def pair_candidates(a,b,ca,cb):
    axis=np.cross(ca["normal"],cb["normal"])
    strength=np.linalg.norm(axis)
    if strength<.15:
        return [],"parallel_or_opposite_views"
    axis/=strength
    def features(rows):
        return {i:(np.quantile(r["points"]@axis,[.05,.95]),float(r["center"]@axis)) for i,r in rows.items()}
    fa,fb=features(a),features(b)
    rows=[]
    for i,j in itertools.product(a,b):
        ia,ma=fa[i]; ib,mb=fb[j]
        width=max(ia[1]-ia[0],ib[1]-ib[0],ca["step"]*3,cb["step"]*3)
        gap=max(0.,max(ia[0],ib[0])-min(ia[1],ib[1]))
        d=abs(ma-mb)/width
        if gap>max(ca["step"],cb["step"])*3 or d>1.2: continue
        chroma=np.linalg.norm(a[i]["lab"][1:]-b[j]["lab"][1:])
        if chroma>35: continue
        light=abs(a[i]["lab"][0]-b[j]["lab"][0])
        area=abs(math.log(a[i]["area_m2"]/b[j]["area_m2"]))
        cost=.60*d+.25*chroma/35+.05*min(light/80,2)+.10*min(area/2,2)
        if cost>.85: continue
        rows.append({"a":i,"b":j,"cost":float(cost),"shared_axis_offset_m":abs(ma-mb),"interval_gap_m":float(gap),"chroma_delta":float(chroma)})
    rows.sort(key=lambda r:(r["cost"],r["a"],r["b"]))
    by_a={i:[r for r in rows if r["a"]==i] for i in a}
    by_b={j:[r for r in rows if r["b"]==j] for j in b}
    for r in rows:
        aa=by_a[r["a"]]; bb=by_b[r["b"]]
        margin=min(aa[1]["cost"]-r["cost"] if len(aa)>1 else 1.,bb[1]["cost"]-r["cost"] if len(bb)>1 else 1.)
        r["mutual_best"]=aa[0] is r and bb[0] is r
        r["margin"]=float(margin)
        r["status"]="strong_candidate" if r["mutual_best"] and margin>=.08 and r["cost"]<=.5 else "ambiguous"
        r["geometry_approved"]=False
    return rows,"ok"

def triangulate(members,views):
    # Visible region centroids are not corresponding surface landmarks: only a rough center hypothesis.
    matrices=[]; rhs=[]
    for name,rid in members:
        c,rows=views[name]
        a=np.eye(3)-np.outer(c["normal"],c["normal"])
        matrices.append(a);rhs.append(a@rows[rid]["center"])
    mat=np.vstack(matrices); b=np.concatenate(rhs)
    xyz,_,rank,_=np.linalg.lstsq(mat,b,rcond=None)
    if rank<3: return None
    residual=float(np.sqrt(np.mean((mat@xyz-b)**2)))
    return {"center_hypothesis_m":xyz.tolist(),"ray_residual_m":residual,"rank":int(rank),
            "limits":"Visible region centroid rays are approximate, not matched surface points."}

def associate(views):
    nodes={(name,rid) for name,(_,r) in views.items() for rid in r}
    parent={k:k for k in nodes}; groups={k:{k} for k in nodes}
    def root(k):
        while parent[k]!=k:
            parent[k]=parent[parent[k]];k=parent[k]
        return k
    pairs=[]; edges=[]
    for a,b in itertools.combinations(views,2):
        ca,ra=views[a];cb,rb=views[b]
        rows,status=pair_candidates(ra,rb,ca,cb)
        pairs.append({"views":[a,b],"status":status,"candidates":rows})
        edges.extend((r["cost"],(a,r["a"]),(b,r["b"])) for r in rows if r["status"]=="strong_candidate")
    rejected=[]
    strong_pairs={frozenset((a,b)) for _,a,b in edges}
    pair_status={frozenset(p["views"]):p["status"] for p in pairs}
    for cost,a,b in sorted(edges):
        u,v=root(a),root(b)
        if u==v: continue
        g=groups[u]|groups[v]
        if len({k[0] for k in g})!=len(g):
            rejected.append({"edge":[a,b],"reason":"same_view_conflict"});continue
        # Require mutual support on every nonparallel cross-group pair; avoid transitive false matches.
        if any(pair_status[frozenset((p[0],q[0]))]=="ok" and frozenset((p,q)) not in strong_pairs for p in groups[u] for q in groups[v]):
            rejected.append({"edge":[a,b],"reason":"missing_cycle_support"});continue
        parent[v]=u;groups[u]=g;del groups[v]
    result=[]
    for g in sorted(groups.values(),key=lambda g:sorted(g)):
        members=sorted(g)
        result.append({"members":members,"missing_views":sorted(set(views)-{k[0] for k in g}),
                       "center":triangulate(members,views) if len(g)>1 else None,
                       "status":"candidate" if len(g)>1 else "unmatched","geometry_approved":False})
    return {"pairs":pairs,"groups":result,"rejected_edges":rejected,
            "limits":"Calibrated orthographic only; visible centroids and color may differ under occlusion. No forced correspondence or semantic approval."}

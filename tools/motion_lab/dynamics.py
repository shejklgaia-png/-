"""Sampled geometry interference and simplified dynamic support diagnostics."""
import itertools, math
import numpy as np
from mathutils.bvhtree import BVHTree
from spatial import margin

class Interference:
    def __init__(self, meshes):
        self.meshes=sorted(meshes,key=lambda o:o.name)
        self.tris={}
        for o in self.meshes:
            o.data.calc_loop_triangles()
            self.tris[o.name]=[tuple(t.vertices) for t in o.data.loop_triangles]
        self.pairs=[]; self.excluded=[]
        for a,b in itertools.combinations(self.meshes,2):
            item=(a.name,b.name)
            # Connected and sibling meshes can intentionally intersect.
            if a.parent==b.parent or (a.parent is not None and a.parent.parent==b.parent) or (b.parent is not None and b.parent.parent==a.parent):
                self.excluded.append(item)
            else: self.pairs.append(item)
        self.frames=[]
    def sample(self):
        geo={}
        for o in self.meshes:
            v=[o.matrix_world@p.co for p in o.data.vertices]
            geo[o.name]=(v,[min(p[k] for p in v) for k in range(3)],[max(p[k] for p in v) for k in range(3)])
        trees={}; hits=[]
        for a,b in self.pairs:
            va,la,ha=geo[a];vb,lb,hb=geo[b]
            if not all(la[k]<=hb[k] and lb[k]<=ha[k] for k in range(3)): continue
            for n,v in ((a,va),(b,vb)):
                if n not in trees: trees[n]=BVHTree.FromPolygons(v,self.tris[n],all_triangles=True)
            count=len(trees[a].overlap(trees[b]))
            contains=all(la[k]<=lb[k] and hb[k]<=ha[k] for k in range(3)) or all(lb[k]<=la[k] and ha[k]<=hb[k] for k in range(3))
            if count or contains: hits.append({"pair":[a,b],"triangle_pairs":count,"aabb_containment_candidate":contains})
        self.frames.append(hits)
    def report(self):
        return {"frames":self.frames,"checked_pairs":self.pairs,"excluded_joint_neighbor_pairs":self.excluded,
                "candidate_frame_pairs":sum(map(len,self.frames)),"scope":"discrete triangle overlap and AABB containment candidates; not penetration volume, intentional contact classification, or swept collision"}

def support_dynamics(sole,fps,ground_z,gravity=9.81):
    """Point-mass zero moment approximation; no angular momentum or true forces."""
    rows=sole["frames"]; p=np.array([r["com_m"] for r in rows]); n=len(p)
    if n<3 or not np.isfinite(p).all() or not math.isfinite(gravity) or gravity<=0: raise ValueError("invalid dynamic samples")
    acc=(p[2:]-2*p[1:-1]+p[:-2])*fps**2
    result=[]
    for i in range(1,n-1):
        r=rows[i]; a=acc[i-1]; h=p[i,2]-ground_z; denom=gravity+a[2]
        names=list(r["support_centers_m"]); xy=np.array([r["support_centers_m"][k][:2] for k in names])
        row={"frame":i+1,"com_accel_m_s2":a.tolist(),"normal_force_per_kg_m_s2":float(denom),"zmp_xy_m":None,"zmp_margin_m":None,"load_fraction":None,"friction_ratio_proxy":None,"valid":False}
        # Positive normal force, positive COM height and exactly three point supports.
        if h>0 and denom>1e-5 and len(names)==3:
            zmp=p[i,:2]-h*a[:2]/denom
            A=np.vstack([xy.T,np.ones(3)])
            if abs(np.linalg.det(A))>1e-9:
                weights=np.linalg.solve(A,np.r_[zmp,1.])
                row.update(zmp_xy_m=zmp.tolist(),zmp_margin_m=margin(r["support_polygon_xy"],zmp),
                           friction_ratio_proxy=float(np.linalg.norm(a[:2])/denom),
                           load_fraction={k:float(v) for k,v in zip(names,weights)},
                           valid=bool(np.min(weights)>=-1e-6))
        result.append(row)
    margins=[r["zmp_margin_m"] for r in result if r["zmp_margin_m"] is not None]
    frictions=[r["friction_ratio_proxy"] for r in result if r["friction_ratio_proxy"] is not None]
    return {"frames":result,"invalid_load_frames":sum(not r["valid"] for r in result),
            "min_zmp_margin_m":min(margins) if margins else None,"max_friction_ratio_proxy":max(frictions) if frictions else None,
            "scope":"uniform-density COM, three assumed fixed point supports, horizontal Wait plane, no angular momentum, real masses, torque or force validation; endpoints omitted"}

def regressions(base,candidate):
    reasons=[]
    for i,(a,b) in enumerate(zip(base["interference"]["frames"],candidate["interference"]["frames"]),1):
        previous={tuple(v["pair"]):v for v in a}
        for v in b:
            k=tuple(v["pair"])
            if k not in previous: reasons.append({"frame":i,"pair":list(k),"kind":"new_interference_candidate"})
            elif v["triangle_pairs"]>previous[k]["triangle_pairs"]: reasons.append({"frame":i,"pair":list(k),"kind":"triangle_overlap_count_increase"})
    a,b=base["dynamics"],candidate["dynamics"]
    if b["invalid_load_frames"]>a["invalid_load_frames"]: reasons.append({"kind":"invalid_load_count_increase"})
    for key,sign,tol in (("min_zmp_margin_m",-1,.001),("max_friction_ratio_proxy",1,.01)):
        if a[key] is not None and (b[key] is None or sign*(b[key]-a[key])>tol): reasons.append({"kind":key+"_regression"})
    return reasons

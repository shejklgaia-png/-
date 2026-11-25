"""Rigid preview sole anchors and uniform-density geometry mass proxies."""
import math
from collections import Counter
from mathutils import Vector
from spatial import hull, margin


def mass_proxy(obj):
    mesh=obj.data
    mesh.calc_loop_triangles()
    verts=[v.co.copy() for v in mesh.vertices]
    if not verts: raise ValueError("empty mass mesh")
    origin=sum(verts,Vector((0,0,0)))/len(verts)
    directed=Counter(); signed=0.; moment=Vector((0,0,0))
    for tri in mesh.loop_triangles:
        ids=tuple(tri.vertices)
        a,b,c=(verts[i]-origin for i in ids)
        vol=a.dot(b.cross(c))/6.
        signed+=vol;moment+=vol*(a+b+c)/4.
        for i,j in zip(ids,ids[1:]+ids[:1]): directed[i,j]+=1
    closed=bool(directed) and all(n==1 and directed[j,i]==1 for (i,j),n in directed.items())
    lo=Vector(tuple(min(v[k] for v in verts) for k in range(3)))
    hi=Vector(tuple(max(v[k] for v in verts) for k in range(3)))
    box=math.prod(hi-lo)
    if closed and abs(signed)>1e-10 and abs(signed)<=box+1e-6:
        return abs(signed),origin+moment/signed,"closed_mesh_volume"
    # Open/inconsistent meshes have no trustworthy solid volume. Explicit box proxy.
    if box>1e-10: return box,(lo+hi)/2,"aabb_volume_proxy"
    return 0.,origin,"zero_volume_excluded"


class SoleReview:
    def __init__(self,nodes,spec,meshes):
        self.meshes={name:nodes[uid] for name,uid in spec["sole_meshes"].items()}
        expected=set(spec["markers"])|{spec["strike_marker"]}
        if set(self.meshes)!=expected or any(o.type!="MESH" or not o.data.vertices for o in self.meshes.values()):
            raise ValueError("explicit sole meshes required")
        self.tol=float(spec.get("sole_band_m",.005))
        if not math.isfinite(self.tol) or not 0<self.tol<=.05: raise ValueError("sole band")
        for name,o in self.meshes.items():
            if o not in meshes: raise ValueError("sole outside geometry")
        self.mass=[(o,*mass_proxy(o)) for o in meshes]
        self.total=sum(v for _,v,_,_ in self.mass)
        if self.total<=0: raise ValueError("no nonzero geometry mass")
        self.planted=spec["markers"]; self.strike=spec["strike_marker"]
        self.patches={};self.anchors={};self.rows=[]

    def sample(self):
        if not self.patches:
            for name,o in self.meshes.items():
                z=min((o.matrix_world@v.co).z for v in o.data.vertices)
                self.patches[name]=[v.co.copy() for v in o.data.vertices if (o.matrix_world@v.co).z<=z+self.tol]
        patches={n:[self.meshes[n].matrix_world@v for v in vs] for n,vs in self.patches.items()}
        centers={n:sum(vs,Vector((0,0,0)))/len(vs) for n,vs in patches.items()}
        lows={n:min((o.matrix_world@v.co).z for v in o.data.vertices) for n,o in self.meshes.items()}
        if not self.anchors: self.anchors={n:v.copy() for n,v in centers.items()};self.wait_lows=lows.copy()
        com=sum((w*(o.matrix_world@p) for o,w,p,_ in self.mass),Vector((0,0,0)))/self.total
        polygon=hull([v for n in self.planted for v in patches[n]])
        m=margin(polygon,com)
        if m is None or not math.isfinite(m): raise ValueError("degenerate sole polygon")
        drift=[(centers[n]-self.anchors[n]).length for n in self.planted]
        offset=sum((self.anchors[n]-centers[n] for n in self.planted),Vector((0,0,0)))/len(self.planted)
        # A fixed Wait-derived patch tracks material points, not a sliding minimum.
        self.rows.append({"offset_m":list(offset),"drifts_m":drift,"com_m":list(com),
                          "support_margin_m":m,"support_polygon_xy":polygon,
                          "support_centers_m":{n:list(centers[n]) for n in self.planted},
                          "support_low_delta_m":{n:lows[n]-self.wait_lows[n] for n in self.planted},
                          "strike_center_m":list(centers[self.strike]),
                          "strike_low_delta_m":lows[self.strike]-self.wait_lows[self.strike]})

    def report(self):
        counts=Counter(method for _,_,_,method in self.mass)
        return {"frames":self.rows,"max_drift_m":max(x for r in self.rows for x in r["drifts_m"]),
                "mean_drift_m":sum(x for r in self.rows for x in r["drifts_m"])/(len(self.rows)*len(self.planted)),
                "min_com_margin_m":min(r["support_margin_m"] for r in self.rows),
                "max_support_low_error_m":max(abs(x) for r in self.rows for x in r["support_low_delta_m"].values()),
                "patch_vertex_counts":{n:len(v) for n,v in self.patches.items()},
                "mass_methods":dict(counts),"volume_proxy_total_m3":self.total,
                "scope":"Wait-derived fixed sole material points; uniform density solid volume or explicit box fallback; quasi-static geometry proxy, no actual mass/contact forces"}

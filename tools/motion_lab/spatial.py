"""Sampled world-space spatial diagnostics for rigid motion; not a physics solver."""
import json, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def hull(points):
    pts=sorted(set((float(p[0]),float(p[1])) for p in points))
    def cross(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    if len(pts)<3: return pts
    lower=[]; upper=[]
    for p in pts:
        while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0: upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]

def margin(poly,p):
    if len(poly)<3: return None
    distances=[]; inside=True
    for a,b in zip(poly,poly[1:]+poly[:1]):
        dx=b[0]-a[0];dy=b[1]-a[1]
        x=p[0]-a[0];y=p[1]-a[1]
        inside &= dx*y-dy*x>=-1e-10
        t=max(0.,min(1.,(x*dx+y*dy)/(dx*dx+dy*dy)))
        distances.append(math.hypot(x-t*dx,y-t*dy))
    return min(distances)*(1 if inside else -1)

def audit(scene,nodes,markers,spec,end,out, *, frame_hook=None, filename="spatial_report.json"):
    if not spec: return None
    floor=spec.get("floor",{})
    z=float(floor.get("z",0)); tol=float(floor.get("tolerance_m",.002))
    if not math.isfinite(z+tol) or tol<0: raise ValueError("floor settings")
    pairs=spec.get("pairs",[])
    if len(pairs)>64: raise ValueError("max 64 explicit interference pairs")
    mesh_ids=set(floor.get("meshes",[]))
    for pair in pairs:
        a,b=pair["nodes"]
        if a==b: raise ValueError("self pair")
        mesh_ids.update((a,b))
    if any(nodes[n].type!="MESH" for n in mesh_ids): raise ValueError("mesh IDs required")
    support=spec.get("support",{})
    stance=support.get("contacts",[])
    masses=support.get("masses",[])
    for c in stance:
        lo,hi=c["frames"]
        if not 1<=lo<=hi<=end or c["marker"] not in markers: raise ValueError("invalid stance")
    weights=[float(m["mass_kg"]) for m in masses]
    if any(not math.isfinite(w) or w<=0 for w in weights): raise ValueError("invalid mass")
    if stance and not masses: raise ValueError("support requires explicit masses")
    ground_tol=float(support.get("ground_tolerance_m",.002))
    slip_tol=float(support.get("slip_tolerance_m",.005))
    if min(ground_tol,slip_tol)<0 or not math.isfinite(ground_tol+slip_tol): raise ValueError("support tolerance")
    results=[]; anchors={}; violations=[]
    for frame in range(1,end+1):
        scene.frame_set(frame); scene.view_layers[0].update()
        if frame_hook is not None:
            frame_hook(frame); scene.view_layers[0].update()
        import bpy
        dg=bpy.context.evaluated_depsgraph_get()
        geo={}
        for n in sorted(mesh_ids):
            obj=nodes[n].evaluated_get(dg)
            mesh=obj.to_mesh()
            try:
                verts=[obj.matrix_world @ v.co for v in mesh.vertices]
                mesh.calc_loop_triangles()
                tris=[tuple(t.vertices) for t in mesh.loop_triangles]
                if not verts or not tris: raise ValueError("empty evaluated mesh "+n)
                geo[n]=(verts,tris,tuple(min(v[i] for v in verts) for i in range(3)),tuple(max(v[i] for v in verts) for i in range(3)))
            finally: obj.to_mesh_clear()
        row={"frame":frame,"floor":{},"pairs":[],"supports":[]}
        for n in floor.get("meshes",[]):
            h=geo[n][2][2]-z
            row["floor"][n]={"lowest_height_m":h,"penetration_m":max(0.,-h)}
            if h < -tol: violations.append({"frame":frame,"kind":"floor","mesh":n,"depth_m":-h})
        trees={}
        for p in pairs:
            a,b=p["nodes"]; va,ta,la,ha=geo[a];vb,tb,lb,hb=geo[b]
            overlap=all(la[i]<=hb[i] and lb[i]<=ha[i] for i in range(3))
            hits=0; containment=False
            if overlap:
                for n in (a,b):
                    if n not in trees:
                        v,t,_,_=geo[n];trees[n]=BVHTree.FromPolygons(v,t,all_triangles=True)
                hits=len(trees[a].overlap(trees[b]))
                containment=all(la[i]<=lb[i] and hb[i]<=ha[i] for i in range(3)) or all(lb[i]<=la[i] and ha[i]<=hb[i] for i in range(3))
            candidate=bool(hits or containment)
            row["pairs"].append({"nodes":[a,b],"triangle_overlap_pairs":hits,"aabb_containment_candidate":containment,"intentional":bool(p.get("intentional",False))})
            if candidate and not p.get("intentional",False): violations.append({"frame":frame,"kind":"interference_candidate","nodes":[a,b]})
        active=[]
        for i,c in enumerate(stance):
            lo,hi=c["frames"]
            if not lo<=frame<=hi: continue
            pos=markers[c["marker"]].matrix_world.translation.copy()
            if i not in anchors: anchors[i]=pos.copy()
            slide=math.hypot(pos.x-anchors[i].x,pos.y-anchors[i].y)
            height=pos.z-z; grounded=abs(height)<=ground_tol
            row["supports"].append({"marker":c["marker"],"height_m":height,"horizontal_drift_m":slide,"grounded":grounded})
            if grounded: active.append((pos.x,pos.y))
            if not grounded or slide>slip_tol: violations.append({"frame":frame,"kind":"support_contact","marker":c["marker"],"height_m":height,"drift_m":slide})
        if masses:
            com=Vector((0,0,0))
            for m,w in zip(masses,weights):
                com+=w*(nodes[m["node"]].matrix_world @ Vector(m.get("local",[0,0,0])))
            com/=sum(weights)
            poly=hull(active); m=margin(poly,com)
            row["com_m"]=list(com);row["support_polygon_xy"]=poly;row["static_margin_m"]=m
            if active and m is not None and m<0: violations.append({"frame":frame,"kind":"static_margin","margin_m":m})
        results.append(row)
    summary={"frames":results,"violations":violations,"counts":{k:sum(v["kind"]==k for v in violations) for k in ("floor","interference_candidate","support_contact","static_margin")},"scope":"discrete frame mesh surface overlap/AABB containment candidates; explicit point masses; quasi-static planar support; no swept collision, penetration volume, friction or dynamic stability"}
    (out/filename).write_text(json.dumps(summary,indent=2))
    return summary

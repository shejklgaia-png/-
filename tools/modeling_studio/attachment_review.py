"""Optional reusable evaluated-mesh attachment audit. Distinct from collision review."""
import json
from pathlib import Path
from mathutils.bvhtree import BVHTree
import bpy

def geometry(obj,deps):
    obj=obj.evaluated_get(deps);mesh=obj.to_mesh()
    try:
        verts=[obj.matrix_world@v.co for v in mesh.vertices]
        faces=[tuple(p.vertices) for p in mesh.polygons]
        adjacency=[[] for _ in verts]
        for e in mesh.edges:
            a,b=e.vertices;adjacency[a].append(b);adjacency[b].append(a)
        ids=[-1]*len(verts);groups=[]
        for start in range(len(verts)):
            if ids[start]>=0:continue
            k=len(groups);stack=[start];ids[start]=k;group=[]
            while stack:
                a=stack.pop();group.append(a)
                for b in adjacency[a]:
                    if ids[b]<0:ids[b]=k;stack.append(b)
            groups.append(group)
        polys=[[] for _ in groups]
        for f in faces:polys[ids[f[0]]].append(f)
        islands=[]
        for group,fs in zip(groups,polys):
            if not fs:continue
            index={v:i for i,v in enumerate(group)}
            points=[verts[v] for v in group]
            islands.append((points,BVHTree.FromPolygons(points,[tuple(index[v] for v in f) for f in fs])))
        return verts,BVHTree.FromPolygons(verts,faces),islands
    finally:obj.to_mesh_clear()

def gap(a,b):
    pa,ta=a;pb,tb=b
    if ta.overlap(tb):return 0.
    best=float("inf")
    for points,tree in ((pa,tb),(pb,ta)):
        for v in points:
            result=tree.find_nearest(v)
            if result[3] is not None:best=min(best,result[3])
    return best

def review(objects,checks,out):
    by={o.name:o for o in objects if o.type=="MESH"}
    deps=bpy.context.evaluated_depsgraph_get();cache={};rows=[]
    def get(n):
        if n not in cache:cache[n]=geometry(by[n],deps)
        return cache[n]
    for c in checks:
        a,b=c["part"],c["support"];tol=float(c.get("max_gap_m",.001))
        if a not in by or b not in by:
            rows.append({**c,"passed":False,"error":"missing mesh"});continue
        va,ta,islands=get(a);vb,tb,_=get(b)
        samples=islands if c.get("each_island") else [(va,ta)]
        gaps=[gap(x,(vb,tb)) for x in samples]
        bad=[i for i,v in enumerate(gaps) if v>tol]
        count_ok=c.get("expected_islands",len(samples))==len(samples)
        rows.append({**c,"islands":len(samples),"failed_islands":bad,"worst_sampled_gap_m":max(gaps,default=None),
                     "passed":bool(gaps) and count_ok and not bad})
    report={"format":"SERA_ATTACHMENT_REVIEW_V1","all_passed":all(r["passed"] for r in rows),"checks":rows,
            "limits":"Evaluated mesh surface overlap or bidirectional vertex-to-surface sampled proximity. Neutral pose only; positive sampled gap is not exact minimum; tolerance is author-defined. Not load, weld, or physical contact certification. No collision exemptions."}
    Path(out,"attachment_review.json").write_text(json.dumps(report,indent=2,allow_nan=False),encoding="utf-8")
    return report


def graph_review(objects,config,out):
    """Audit all connected mesh islands, including parts absent from declared checks."""
    import math
    deps=bpy.context.evaluated_depsgraph_get()
    tol=float(config.get("max_gap_m",.001))
    if not math.isfinite(tol) or tol<0:raise ValueError("invalid graph tolerance")
    nodes=[];samples=[];bounds=[]
    for obj in sorted(objects,key=lambda x:x.name):
        if obj.type!="MESH":continue
        _,_,islands=geometry(obj,deps)
        for i,(points,tree) in enumerate(islands):
            nodes.append({"part":obj.name,"island":i,"vertices":len(points)})
            samples.append((points,tree))
            bounds.append(([min(v[k] for v in points) for k in range(3)],
                           [max(v[k] for v in points) for k in range(3)]))
    roots=[i for i,n in enumerate(nodes) if n["part"] in config["roots"]]
    if not roots:raise ValueError("attachment graph root missing")
    edges=[];adj=[set() for _ in nodes];exact=[set() for _ in nodes]
    def lower_bound(i,j):
        a,b=bounds[i];c,d=bounds[j]
        return math.sqrt(sum(max(0,a[k]-d[k],c[k]-b[k])**2 for k in range(3)))
    for i in range(len(nodes)):
        for j in range(i):
            if lower_bound(i,j)>tol+1e-8:continue
            distance=gap(samples[i],samples[j])
            if distance<=tol:
                adj[i].add(j);adj[j].add(i)
                if distance==0:
                    exact[i].add(j);exact[j].add(i)
                edges.append({"a":j,"b":i,"sampled_gap_m":distance})
    def reachable(starts,links):
        seen=set(starts);stack=list(starts)
        while stack:
            for j in links[stack.pop()]-seen:
                seen.add(j);stack.append(j)
        return seen
    attached=reachable(roots,adj);contact=reachable(roots,exact)
    remaining=set(range(len(nodes)))-attached;components=[]
    while remaining:
        cluster=reachable([min(remaining)],adj);remaining-=cluster
        # Find the nearest observed bridge to the root-connected assembly.
        nearest=None;best=float("inf")
        for i,j in sorted(((i,j) for i in cluster for j in attached),key=lambda ij:lower_bound(*ij)):
            if lower_bound(i,j)>best:break
            distance=gap(samples[i],samples[j])
            if distance<best:
                best=distance;nearest={"island":nodes[i],"root_connected_island":nodes[j],"sampled_gap_m":distance}
        components.append({"islands":[nodes[i] for i in sorted(cluster)],"nearest_sampled_bridge":nearest})
    result={"format":"SERA_ATTACHMENT_GRAPH_V1","roots":[nodes[i] for i in roots],"max_gap_m":tol,
            "mesh_islands":len(nodes),"root_connected":len(attached),"zero_gap_connected":len(contact),
            "all_root_connected":len(attached)==len(nodes),"nodes":nodes,"edges":edges,
            "disconnected_components":components,
            "limits":"Neutral pose only; BVH overlap or sampled surface proximity, not exact minimum or mechanical support certification. Contained or intentionally separated components may be flagged. No collision exemptions. Near contact is not physical attachment."}
    Path(out,"attachment_graph.json").write_text(json.dumps(result,indent=2,allow_nan=False),encoding="utf-8")
    return result

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

"""Calibrated orthographic guide reconstruction. Pure math; Blender builds the surface."""
import math
from collections import Counter

# Image horizontal axis as seen from the named camera; vertical pixels point down.
AXES = {"front": (0,1), "back": (0,-1), "right": (1,1), "left": (1,-1)}

def pair(value):
    if not isinstance(value,(list,tuple)) or len(value)!=2:
        raise ValueError("expected two coordinates")
    result = tuple(float(x) for x in value)
    if not all(math.isfinite(x) for x in result):
        raise ValueError("nonfinite guide coordinate")
    return result

def solve(spec):
    """Return vertices, faces and a pre-surface guide report, all in part-local metres."""
    cfg = spec["wireframe"]
    views = cfg["views"]
    if not views or not set(views)<=set(AXES):
        raise ValueError("unsupported guide view")
    calibration={}
    for name,v in views.items():
        origin=pair(v["origin_px"])
        scale=float(v["px_per_m"])
        weight=float(v.get("weight",1))
        if not (math.isfinite(scale) and scale>0 and math.isfinite(weight) and weight>0):
            raise ValueError("positive finite guide scale/weight required")
        calibration[name]=(origin,scale,weight)
    limit=float(cfg.get("max_error_px",3))
    if not math.isfinite(limit) or limit<0:
        raise ValueError("invalid max_error_px")
    points=cfg["points"]
    if not points or len(points)>10000:
        raise ValueError("invalid guide point count")
    ids=list(points)
    index={name:i for i,name in enumerate(ids)}
    vertices=[]
    diagnostics={}
    for name,obs in points.items():
        if not obs or not set(obs)<=set(views):
            raise ValueError("missing or unknown observations: "+name)
        values=[[],[],[]]
        for view,p in obs.items():
            u,v=pair(p)
            (ox,oy),s,w=calibration[view]
            axis,sign=AXES[view]
            # Minimize weighted squared pixel reprojection error.
            values[axis].append((sign*(u-ox)/s,w*s*s))
            values[2].append(((oy-v)/s,w*s*s))
        if any(not x for x in values):
            raise ValueError("underdetermined guide point: "+name)
        xyz=tuple(sum(v*w for v,w in x)/sum(w for v,w in x) for x in values)
        if not all(math.isfinite(v) for v in xyz):
            raise ValueError("nonfinite solved point: "+name)
        projections={}
        for view,((ox,oy),s,w) in calibration.items():
            axis,sign=AXES[view]
            pixel=(ox+sign*xyz[axis]*s,oy-xyz[2]*s)
            item={"projected_px":pixel}
            if view in obs:
                item["observed_px"]=pair(obs[view])
                item["error_px"]=math.dist(pixel,item["observed_px"])
                if item["error_px"]>limit:
                    raise ValueError("conflicting guide point %s/%s: %.3f px"%(name,view,item["error_px"]))
            projections[view]=item
        diagnostics[name]={"xyz":xyz,"views":projections}
        vertices.append(xyz)
    faces=[]
    def face(labels):
        if len(labels)<3 or len(set(labels))!=len(labels):
            raise ValueError("invalid face or loop")
        faces.append(tuple(index[k] for k in labels))
    for strip in cfg.get("strips",[]):
        rings=strip["rings"]
        if len(rings)<2 or len(rings[0])<3 or any(len(r)!=len(rings[0]) or len(set(r))!=len(r) for r in rings):
            raise ValueError("strips require corresponding unique equal-length closed rings")
        n=len(rings[0])
        for a,b in zip(rings,rings[1:]):
            for i in range(n):
                j=(i+1)%n
                face([a[i],a[j],b[j],b[i]])
        if strip.get("cap_start",True):
            face(list(reversed(rings[0])))
        if strip.get("cap_end",True):
            face(rings[-1])
    for labels in cfg.get("faces",[]):
        face(labels)
    if not faces or len({tuple(sorted(f)) for f in faces})!=len(faces):
        raise ValueError("empty or duplicate surface faces")
    counts=Counter(tuple(sorted((a,b))) for f in faces for a,b in zip(f,f[1:]+f[:1]))
    used={i for f in faces for i in f}
    if len(used)!=len(vertices) or any(n!=2 for n in counts.values()):
        raise ValueError("wireframe surface must be closed, with every edge incident to two faces and every point used")
    if any(math.dist(vertices[a],vertices[b])<1e-9 for a,b in counts):
        raise ValueError("collapsed guide edge")
    # Optional authored structural lines must be edges of the surface, not guessed diagonals.
    for line in cfg.get("lines",[]):
        if len(line)<2:
            raise ValueError("structural line needs at least two points")
        for a,b in zip(line,line[1:]):
            if tuple(sorted((index[a],index[b]))) not in counts:
                raise ValueError("structural line not represented by a surface edge")
    report={"format":"SERA_WIREFRAME_GUIDE_V1","points":diagnostics,
            "edges":[[ids[a],ids[b]] for a,b in sorted(counts)],
            "faces":[[ids[i] for i in f] for f in faces],
            "authored_lines":cfg.get("lines",[]),"max_error_px":limit,
            "limits":"Correspondence and topology are authored; occluded points need observations from other axes. Residual is for guide vertices before bevel, not silhouette or visual approval."}
    return vertices,faces,report

"""Opt-in structured hard-surface design compiler. No image interpretation is implied."""
import copy
import math

METHODS = {
    "outline":"wireframe", "section":"loft", "solid":"box", "extrusion":"prism",
    "joint":"cylinder", "revolution":"revolve", "variable_section":"sweep",
    "explicit":"mesh", "fixed_tube":"tube", "pivot":"pivot", "repeat":"repeat_path",
}
LINE_TYPES = {
    "silhouette":"shape", "panel_boundary":"split", "chamfer":"bevel",
    "recess":"cut", "circular":"revolve", "curve":"sweep",
    "scratch":"texture", "pattern":"texture", "shadow":"ignore",
    "unknown":"review",
}

def positive(v):
    v=float(v)
    if not math.isfinite(v) or v<=0:
        raise ValueError("expected positive finite number")
    return v

def fit_dimensions(part):
    """Bounded local adjustment of explicitly selected primitive parameters.
    Targets are pre-finish local dimensions, not render scores.
    """
    cfg=part.get("dimension_fit")
    if not cfg:
        return None
    shape=part["shape"]
    if shape=="box":
        keys={"x":("size",0,1),"y":("size",1,1),"z":("size",2,1)}
    elif shape=="cylinder":
        keys={"diameter":("radius",None,2),"depth":("depth",None,1)}
    else:
        raise ValueError("dimension_fit supports box and cylinder only")
    rows={}
    for key,t in cfg.items():
        field,i,factor=keys[key]
        value=positive(part[field] if i is None else part[field][i])
        target=positive(t["target_m"])
        low,high=map(positive,t["bounds_m"])
        if low>high or not low<=value*factor<=high:
            raise ValueError("invalid dimension bounds or initial value")
        candidate=min(high,max(low,target))/factor
        if i is None:
            part[field]=candidate
        else:
            part[field][i]=candidate
        rows[key]={"before_m":value*factor,"after_m":candidate*factor,"target_m":target,
                   "before_error_m":abs(value*factor-target),"after_error_m":abs(candidate*factor-target),
                   "bounded":not low<=target<=high}
    return rows

def compile_design(source):
    spec=copy.deepcopy(source)
    cfg=spec.get("hard_surface")
    if cfg is None:
        return spec,None
    level=int(cfg.get("level",5))
    if not 1<=level<=5:
        raise ValueError("level must be 1..5")
    active=[]
    names=set()
    report={"format":"SERA_HARD_SURFACE_V1","level":level,"parts":{},"excluded":[],"lines":[],
            "limits":"Authored semantic roles and recipe choices; no automatic image understanding. Dimension fit is bounded primitive adjustment, not image optimization."}
    for part in spec["parts"]:
        name=part["name"]
        if name in names:
            raise ValueError("duplicate part: "+name)
        names.add(name)
        stage=int(part.get("level",1))
        if not 1<=stage<=5:
            raise ValueError("invalid part level")
        if stage>level:
            report["excluded"].append(name)
            continue
        # Preserve identity and joint hierarchy while refining geometry by level.
        applied=[]
        refinements=part.pop("refinements",{})
        allowed={"size","radius","depth","sides","rings","path","sections","profile","vertices",
                 "faces","wireframe","cuts","bevel","bevel_segments","weighted_normals","uv","material","count"}
        for step,changes in sorted(refinements.items(),key=lambda item:int(item[0])):
            n=int(step)
            if not stage<n<=5 or not set(changes)<=allowed:
                raise ValueError("invalid refinement stage or field: "+name)
            if n<=level:
                part.update(changes)
                applied.append(n)
        method=part.get("method")
        if method:
            selected=METHODS[method]
            if "shape" in part and part["shape"]!=selected:
                raise ValueError("recipe and shape disagree: "+name)
            part["shape"]=selected
        if "shape" not in part:
            raise ValueError("part has no recipe or shape")
        if part.get("parent") is not None and part["parent"] not in {p["name"] for p in active}:
            raise ValueError("active part parent must precede it and be active: "+name)
        row={"role":part.get("role","unspecified"),"level":stage,"shape":part["shape"],
             "method":method,"refinement_levels":applied,"dimension_fit":fit_dimensions(part)}
        report["parts"][name]=row
        active.append(part)
    if not active:
        raise ValueError("empty level")
    active_names={p["name"] for p in active}
    for line in cfg.get("lines",[]):
        kind=line["kind"]
        action=LINE_TYPES[kind]
        if line["part"] not in names:
            raise ValueError("line references unknown part")
        if line["part"] not in active_names:
            continue
        if len(line["pixels"])<2 or any(len(p)!=2 or not all(math.isfinite(float(v)) for v in p) for p in line["pixels"]):
            raise ValueError("invalid semantic polyline")
        report["lines"].append({**line,"route":action})
    spec["parts"]=active
    # Explicitly skip observations and sweeps for omitted stage nodes.
    spec["landmarks"]={k:v for k,v in spec.get("landmarks",{}).items() if v["node"] in active_names}
    for view,fit in spec.get("camera_fits",{}).items():
        if not set(fit["landmarks"])<=set(spec["landmarks"]):
            raise ValueError("camera fit references landmarks omitted by level: "+view)
    spec["intentional_overlaps"]=[x for x in spec.get("intentional_overlaps",[]) if set(x["parts"])<=active_names]
    # Motion sweeps are not silently removed: author a level-specific list.
    if not set(cfg.get("part_targets",{}))<=names:
        raise ValueError("part target references unknown part")
    report["part_targets"]={k:v for k,v in cfg.get("part_targets",{}).items() if k in active_names}
    return spec,report

def repeat_closed_path(part):
    """Closed planar polyline, equal arc-length pitch, rigid independent tread-like blocks.
    XY plane: block local X follows tangent. YZ plane: block local Y follows tangent.
    """
    plane=part["plane"]
    if plane not in ("xy","yz"):
        raise ValueError("repeat plane must be xy or yz")
    path=[tuple(float(v) for v in p) for p in part["path"]]
    if len(path)<3 or any(len(p)!=2 or not all(math.isfinite(v) for v in p) for p in path):
        raise ValueError("invalid closed path")
    edges=[(a,b,math.dist(a,b)) for a,b in zip(path,path[1:]+path[:1])]
    if any(n<1e-8 for a,b,n in edges):
        raise ValueError("duplicate repeat path points")
    count=int(part["count"])
    if not 3<=count<=512:
        raise ValueError("repeat count must be 3..512")
    length=sum(n for a,b,n in edges)
    half=[positive(v)/2 for v in part["size"]]
    if len(half)!=3 or 2*half[0 if plane=="xy" else 1]>length/count:
        raise ValueError("repeat block exceeds nominal pitch")
    verts=[]
    faces=[]
    for i in range(count):
        dist=(i+.5)*length/count
        for a,b,n in edges:
            if dist<=n:
                t=dist/n
                u,v=(a[j]+(b[j]-a[j])*t for j in range(2))
                angle=math.atan2(b[1]-a[1],b[0]-a[0])
                break
            dist-=n
        c,s=math.cos(angle),math.sin(angle)
        x,y,z=half
        base=len(verts)
        for h in (-z,z):
            for X,Y in ((-x,-y),(x,-y),(x,y),(-x,y)):
                if plane=="xy":
                    verts.append((u+c*X-s*Y,v+s*X+c*Y,h))
                else:
                    verts.append((X,u+c*Y-s*h,v+s*Y+c*h))
        faces.extend(tuple(base+k for k in f) for f in ((3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)))
    return verts,faces

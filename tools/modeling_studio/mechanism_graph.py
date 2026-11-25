"""Compile an authored mechanical intent graph into ordinary Modeling Studio parts.
The graph can contain incomplete reference observations; it is not an image-to-CAD solver.
"""
import copy
import math

RECIPES={
    "chassis":(("section",("rings",)),("solid",("size",))),
    "armor":(("outline",("wireframe",)),("section",("rings",)),("solid",("size",))),
    "housing":(("section",("rings",)),("solid",("size",))),
    "bearing":(("revolution",("profile",)),("joint",("radius","depth"))),
    "shaft":(("joint",("radius","depth")),),
    "wheel":(("revolution",("profile",)),("joint",("radius","depth"))),
    "tread":(("repeat",("plane","path","count","size")),),
    "link":(("variable_section",("path","sections")),("section",("rings",)),("solid",("size",))),
    "claw":(("variable_section",("path","sections")),),
    "support":(("solid",("size",)),("joint",("radius","depth"))),
    "panel":(("solid",("size",)),),
    "emission":(("solid",("size",)),),
    "pivot":(("pivot",()),),
}

def vector(v):
    if len(v)!=3 or not all(math.isfinite(float(x)) for x in v):
        raise ValueError("invalid vector")
    return list(map(float,v))

def compile_graph(source):
    spec=copy.deepcopy(source)
    cfg=spec.get("mechanism")
    if cfg is None: return spec,None
    if spec.get("parts"): raise ValueError("mechanism graph and ordinary parts must not be mixed")
    nodes={}; entries={}; order=[]
    for raw in cfg["nodes"]:
        n=copy.deepcopy(raw)
        name=n["name"]; role=n["role"]
        if not isinstance(name,str) or not name or name in nodes or role not in RECIPES:
            raise ValueError("invalid node name or role")
        reason=n.pop("reason","")
        evidence=n.pop("evidence",[])
        origin=n.pop("provenance","inferred")
        if not reason.strip() or origin not in ("reference","inferred","explicit"):
            raise ValueError("node needs design rationale and provenance: "+name)
        if not isinstance(evidence,list) or not all(isinstance(x,str) and x.strip() for x in evidence):
            raise ValueError("invalid evidence")
        if origin=="reference" and not evidence: raise ValueError("reference feature needs source")
        n["location"]=vector(n.get("location",[0,0,0]))
        n["rotation_deg"]=vector(n.get("rotation_deg",[0,0,0]))
        candidates=[m for m,required in RECIPES[role] if all(k in n for k in required)]
        if not candidates: raise ValueError("no compatible recipe: "+name)
        method=n.get("method",candidates[0])
        if method not in candidates: raise ValueError("incompatible recipe: "+name)
        n["method"]=method
        joint=n.pop("joint",None)
        if joint is not None:
            if role!="pivot" or joint["type"]!="revolute": raise ValueError("joint requires revolute pivot")
            axis=vector(joint["axis_local"])
            length=math.sqrt(sum(x*x for x in axis))
            if length<1e-9: raise ValueError("zero joint axis")
            lo,hi=map(float,joint["range_deg"])
            if not math.isfinite(lo) or not math.isfinite(hi) or not -360<=lo<=0<=hi<=360:
                raise ValueError("invalid joint range")
            joint={"type":"revolute","axis_local":[x/length for x in axis],"range_deg":[lo,hi]}
        nodes[name]=n;order.append(name)
        entries[name]={"role":role,"method":method,"recipe_candidates":candidates,"reason":reason,
                       "provenance":origin,"evidence":evidence,"joint":joint}
    # Reflect selected nodes in their parent-local X plane. Require the full mirrored parent chain.
    mirrors=cfg.get("mirror_x",{})
    if not isinstance(mirrors,dict) or not set(mirrors)<=set(nodes) or len(set(mirrors.values()))!=len(mirrors):
        raise ValueError("invalid mirror mapping")
    for old in list(order):
        if old not in mirrors: continue
        new=mirrors[old]
        if not isinstance(new,str) or not new or new in nodes: raise ValueError("duplicate mirrored node")
        n=copy.deepcopy(nodes[old]); n["name"]=new
        parent=n.get("parent")
        if parent in mirrors: n["parent"]=mirrors[parent]
        elif parent is not None:
            # A shared parent must be centered and unrotated in its own frame.
            p=nodes[parent]
            if abs(p["location"][0])>1e-9 or any(abs(x)>1e-9 for x in p["rotation_deg"]):
                raise ValueError("shared mirror parent is not centered/aligned")
        method=n["method"]
        if method not in ("solid","joint","revolution","repeat","pivot","variable_section") or n.get("cuts") or n.get("refinements"):
            raise ValueError("mirror recipe not supported: "+old)
        n["location"][0]*=-1
        n["rotation_deg"][1]*=-1;n["rotation_deg"][2]*=-1
        if method=="repeat" and n["plane"]!="yz": raise ValueError("mirror repeat requires YZ path")
        if method=="variable_section":
            n["path"]=[[-x,y,z] for x,y,z in map(vector,n["path"])]
            if "up" in n:
                x,y,z=vector(n["up"]);n["up"]=[-x,y,z]
        nodes[new]=n;order.append(new)
        e=copy.deepcopy(entries[old]);e["provenance"]="inferred";e["mirrored_from"]=old
        e["reason"]="Bilateral counterpart of "+old+"; "+e["reason"]
        if e["joint"]:
            # Axis is axial vector under reflection, not a polar direction.
            x,y,z=e["joint"]["axis_local"];e["joint"]["axis_local"]=[x,-y,-z]
        entries[new]=e
    # Stable topological order and graph validation.
    remaining=list(order);parts=[];done=set()
    while remaining:
        ready=[k for k in remaining if nodes[k].get("parent") is None or nodes[k]["parent"] in done]
        if not ready: raise ValueError("missing parent or cycle")
        for k in ready:
            n=nodes[k]
            if n.get("parent") is None: n.pop("parent",None)
            parts.append(n);done.add(k);remaining.remove(k)
            entries[k]["parent"]=n.get("parent")
    spec["parts"]=parts
    samples=cfg.get("joint_review_samples")
    if samples is not None:
        if not isinstance(samples,int) or isinstance(samples,bool) or not 2<=samples<=13 or spec.get("motion_sweeps"):
            raise ValueError("invalid or conflicting graph joint review samples")
        level=spec.get("hard_surface",{}).get("level",5)
        spec["motion_sweeps"]=[{"node":k,"axis":e["joint"]["axis_local"],"degrees":e["joint"]["range_deg"],"samples":samples}
            for k,e in entries.items() if e["joint"] and nodes[k].get("level",1)<=level]
    spec.setdefault("hard_surface",{})["level"]=spec.get("hard_surface",{}).get("level",5)
    report={"format":"SERA_MECHANISM_GRAPH_V1","nodes":entries,"order":[n["name"] for n in parts],
            "reference_policy":"Soft reference evidence; authored intent and physical plausibility prioritized.",
            "limits":"Role labels, dimensions, parent edges and axes are authored hypotheses. Recipe choice and bilateral generation are automatic; joint limits are metadata, not runtime constraints. No automatic hidden geometry or image semantic recognition."}
    return spec,report

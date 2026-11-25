"""Rigid model inventory and explicitly role-seeded topology discovery."""
import json, math, unicodedata
from copy import deepcopy

FOOT_ROLES=("FrontFoot_L","FrontFoot_R","RearFoot_L","RearFoot_R")

def normalized(name):
    return "".join(c for c in unicodedata.normalize("NFKC",str(name)).casefold() if c.isalnum())

def resolve(nodes,spec):
    by_obj={o.name:uid for uid,o in nodes.items()}
    parent={uid:by_obj.get(o.parent.name) if o.parent else None for uid,o in nodes.items()}
    groups={uid for uid,o in nodes.items() if o.type=="EMPTY"}
    meshes={uid for uid,o in nodes.items() if o.type=="MESH"}
    names={uid:str(o.get("bb_name",o.name)) for uid,o in nodes.items()}
    def path(uid):
        seen=set();result=[]
        while uid is not None:
            if uid in seen: raise ValueError("cyclic model hierarchy")
            seen.add(uid);result.append(uid);uid=parent[uid]
        return result
    children={uid:[] for uid in nodes}
    for uid,p in parent.items():
        if p is not None: children[p].append(uid)
    def low(uid):
        o=nodes[uid]
        return min((o.matrix_world@v.co).z for v in o.data.vertices)
    inventory=[]
    for uid in sorted(nodes):
        o=nodes[uid]
        inventory.append({"id":uid,"name":names[uid],"type":o.type,"parent":parent[uid],
                          "children":sorted(children[uid]),"world_pivot_m":list(o.matrix_world.translation),
                          "depth":len(path(uid))-1})
    leaves=[]
    for uid in sorted(groups):
        direct=[v for v in children[uid] if v in meshes and len(nodes[v].data.vertices)>0]
        if direct and not any(v in groups for v in children[uid]):
            leaves.append({"id":uid,"name":names[uid],"path":list(reversed(path(uid))),
                           "mesh_candidates":direct,"min_z_m":min(low(v) for v in direct)})
    leaves.sort(key=lambda v:(v["min_z_m"],v["id"]))
    report={"version":18,"inventory":inventory,"roots":[u for u,p in parent.items() if p is None],
            "terminal_geometry_candidates":leaves,"mode":spec.get("mode","inventory"),
            "scope":"rigid hierarchy; leaf/ground suggestions do not establish anatomical role"}
    if spec.get("mode","inventory")=="inventory": return None,report
    if spec.get("mode")!="quadruped": raise ValueError("unsupported discovery mode")
    aliases=spec.get("roles",{})
    required={"Body","Head",*FOOT_ROLES}
    if set(aliases)!=required: raise ValueError("explicit body/head/four foot role selectors required")
    def choose(role):
        selector=aliases[role]
        if isinstance(selector,str): selector=[selector]
        if not selector or not all(isinstance(x,str) and normalized(x) for x in selector):
            raise ValueError("empty selector "+role)
        matches=[uid for uid in sorted(groups) if uid in selector or normalized(names[uid]) in {normalized(x) for x in selector}]
        if len(matches)!=1: raise ValueError("ambiguous or missing role "+role+": "+str(matches))
        return matches[0]
    roles={role:choose(role) for role in sorted(required)}
    if len(set(roles.values()))!=len(roles): raise ValueError("overlapping roles")
    root=roles["Body"]
    if parent[root] is not None or parent[roles["Head"]]!=root:
        raise ValueError("expected root body and direct head")
    chains={};sole={};used=set()
    for role in FOOT_ROLES:
        uid=roles[role];ancestry=path(uid)
        if root not in ancestry: raise ValueError("foot not under body: "+role)
        chain=list(reversed(ancestry[:ancestry.index(root)]))
        if not 2<=len(chain)<=8 or any(v not in groups for v in chain) or used.intersection(chain) or roles["Head"] in chain:
            raise ValueError("unsupported or shared leg chain "+role)
        used.update(chain);chains[role]=chain
        options=[v for v in children[uid] if v in meshes and len(nodes[v].data.vertices)>0]
        explicit=spec.get("sole_mesh_selectors",{}).get(role)
        if explicit is not None:
            options=[v for v in options if v==explicit or normalized(names[v])==normalized(explicit)]
        if len(options)!=1: raise ValueError("ambiguous/missing sole mesh "+role+": "+str(options))
        sole[role]=options[0]
    # Scale based on the mean lateral span of front/rear foot pivots.
    span=sum((nodes[roles[l]].matrix_world.translation-nodes[roles[r]].matrix_world.translation).length
             for l,r in (("FrontFoot_L","FrontFoot_R"),("RearFoot_L","RearFoot_R")))/2.
    ref=float(spec.get("reference_span_m",span))
    if not math.isfinite(span+ref) or min(span,ref)<=1e-5: raise ValueError("invalid rig span")
    factor=span/ref
    if not .25<=factor<=2.5: raise ValueError("size factor outside supported range")
    strike=spec.get("strike_role")
    if strike not in FOOT_ROLES: raise ValueError("explicit strike role required")
    # Preserve stable canonical markers for existing diagnostics.
    markers={n:{"node":uid,"local":[0,0,0]} for n,uid in roles.items()}
    for role,chain in chains.items():
        side=role.replace("Foot","Leg")
        lower=role.replace("Foot","LowerLeg")
        markers[side]={"node":chain[0],"local":[0,0,0]}
        markers[lower]={"node":chain[-2],"local":[0,0,0]}
    result={"markers":markers,"root":root,"chains":chains,"sole_meshes":sole,
            "support_roles":[n for n in FOOT_ROLES if n!=strike],"strike_role":strike,
            "span_m":span,"reference_span_m":ref,"scale_factor":factor}
    report["resolved"]=result
    return result,report

def configure(d,nodes,out):
    spec=d.get("rig_discovery")
    if not spec: return
    import bpy
    bpy.context.view_layer.update()
    resolved,report=resolve(nodes,spec)
    if resolved is None:
        (out/"rig_discovery_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False));return
    r=resolved; mode=spec.get("apply","verify")
    if mode not in ("verify","generate"): raise ValueError("invalid discovery apply mode")
    s=deepcopy(d.get("support_lock",{})); ik=deepcopy(d.get("multifoot_ik",{}))
    dynamic=deepcopy(d.get("dynamic_refinement",{}))
    # Existing explicit settings must agree; no silent remapping.
    if mode=="verify":
        if not {"Body","Head",*FOOT_ROLES}.issubset(d.get("markers",{})):
            raise ValueError("missing explicit role markers")
        for name,point in d.get("markers",{}).items():
            if name in r["markers"] and point!=r["markers"][name]:
                raise ValueError("explicit marker mismatch "+name)
        for k,v in (("root",r["root"]),("sole_meshes",r["sole_meshes"]),("strike_marker",r["strike_role"])):
            if s.get(k)!=v: raise ValueError("explicit support mismatch "+k)
        if set(s.get("markers",[]))!=set(r["support_roles"]) or ik.get("chains")!=r["chains"]:
            raise ValueError("explicit support/chain mismatch")
        # Keep exact marker ordering and coverage for reproducibility.
        report["configuration_status"]="verified_existing"
    else:
        if d.get("markers") or s.get("root") or s.get("sole_meshes") or ik.get("chains") or dynamic.get("joint_delta_deg"):
            raise ValueError("generate mode requires no conflicting explicit UUID configuration")
        d["markers"]=r["markers"]
        factor=r["scale_factor"]
        s.update(root=r["root"],markers=r["support_roles"],body_marker="Body",strike_marker=r["strike_role"],sole_meshes=r["sole_meshes"])
        s.setdefault("max_shift_m",min(.5,.25*factor))
        s.setdefault("sole_band_m",.005*factor)
        s.setdefault("impact_xy_tolerance_m",.01*factor)
        ik["chains"]=r["chains"]
        dynamic["joint_delta_deg"]={uid:([2]*3 if i==len(chain)-1 else [4]*3)
                                     for chain in r["chains"].values() for i,uid in enumerate(chain)}
        d.update(support_lock=s,multifoot_ik=ik,dynamic_refinement=dynamic)
        report["configuration_status"]="generated"
    # Explicit opt-in to scaling, leaving the reference candidate unchanged.
    if spec.get("scale_secondary"):
        factor=r["scale_factor"]
        sec=deepcopy(d.get("secondary_refinement",{}))
        for p in sec.get("profiles",[]):
            p["sink_m"]=min(.05,float(p["sink_m"])*factor)
        for k in ("max_support_path_error_m","max_strike_path_error_m"):
            if k in sec: sec[k]=float(sec[k])*factor
        if sec:d["secondary_refinement"]=sec
    report["effective_settings"]={k:d.get(k) for k in ("markers","support_lock","multifoot_ik","dynamic_refinement","secondary_refinement")}
    (out/"rig_discovery_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))

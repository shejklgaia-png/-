"""Non-destructive whole-clip IK candidate selection and post-bake quality guard."""
import json,math
import numpy as np
from mathutils import Vector
from ik import bake_ik,commit_ik
from spatial import audit

STRATEGIES=("legacy","forward_cartesian","backward_cartesian","forward_joint","backward_joint")
METRICS=("speed","acceleration","jerk")
def motion_metrics(samples,fps):
    p=np.asarray(samples,dtype=float)
    result={}
    for order,name in enumerate(METRICS,1):
        v=np.linalg.norm(np.diff(p,n=order,axis=0)*fps**order,axis=1)
        result[name]=float(v.max()) if len(v) else 0.
        result[name+"_frame"]=int(v.argmax()+order+1) if len(v) else 1
    return result

def evaluate(scene,nodes,markers,design,end,out,label,baked=None):
    names=design["ik_refinement"]["markers"]
    samples={n:[] for n in names}; contacts={}
    objects={o.name:o for o in nodes.values()}
    def hook(frame):
        if baked is not None:
            for n,values in baked.items(): objects[n].rotation_euler=values[frame-1][1]
            scene.view_layers[0].update()
        for n in names: samples[n].append(list(markers[n].matrix_world.translation))
        for i,c in enumerate(design.get("contacts",[])):
            if c["frames"][0]<=frame<=c["frames"][1]:
                p=markers[c["marker"]].matrix_world.translation
                t=markers[c["target_marker"]].matrix_world.translation if "target_marker" in c else Vector(c["target"])
                contacts[i]=max(contacts.get(i,0.),(p-t).length)
    # Audit invokes hook once per frame before reading geometry. Without spatial config sample directly.
    spatial=design.get("spatial")
    if spatial:
        report=audit(scene,nodes,markers,spatial,end,out,frame_hook=hook,filename=f"refine_spatial_{label}.json")
    else:
        report={"violations":[],"counts":{},"frames":[]}
        for f in range(1,end+1):
            scene.frame_set(f);scene.view_layers[0].update();hook(f)
    return {"metrics":{n:motion_metrics(p,int(design.get("fps",60))) for n,p in samples.items()},
            "contacts":contacts,"spatial":report}

def summarize(e,rows,baked,fps):
    max_angle=0.; max_angle_accel=0.
    for values in baked.values():
        q=np.asarray([v for _,v in values],dtype=float)*180/math.pi
        if len(q)>1: max_angle=max(max_angle,float(np.max(np.abs(np.diff(q,axis=0))))*fps)
        if len(q)>2: max_angle_accel=max(max_angle_accel,float(np.max(np.abs(np.diff(q,n=2,axis=0))))*fps**2)
    return {"metrics":e["metrics"],"contact_max_m":e["contacts"],"spatial_counts":e["spatial"]["counts"],
        "full_weight_residual_m":max((r["residual_m"] for r in rows if r["weight"]>=.999),default=0.),
        "blend_residual_m":max((r["residual_m"] for r in rows if r["weight"]<.999),default=0.),
        "joint_speed_deg_s":max_angle,"joint_acceleration_deg_s2":max_angle_accel}

def violations(report):
    return {(v["frame"],v["kind"],str(v.get("mesh",v.get("marker",v.get("nodes",""))))) for v in report["violations"]}

def spatial_ok(a,b):
    if violations(b)-violations(a): return False
    for x,y in zip(a["frames"],b["frames"]):
        for n,v in y["floor"].items():
            if v["penetration_m"]>x["floor"][n]["penetration_m"]+.0001: return False
        for u,v in zip(x["supports"],y["supports"]):
            if abs(v["height_m"])>abs(u["height_m"])+.0001 or v["horizontal_drift_m"]>u["horizontal_drift_m"]+.0001: return False
        m0,m1=x.get("static_margin_m"),y.get("static_margin_m")
        # Static margin may change as the limb moves; forbid crossing the support boundary,
        # not all harmless movement inside it.
        if m0 is not None and (m1 is None or m1<min(0.,m0)-.0001): return False
    return True

def refine_ik(scene,nodes,markers,design,end,out):
    spec=design.get("ik_refinement")
    if not spec: return bake_ik(scene,nodes,markers,design.get("ik",[]),end,out)
    if not design.get("ik") or not spec.get("markers") or any(n not in markers for n in spec["markers"]):
        raise ValueError("refinement requires IK and explicit monitored markers")
    fps=int(design.get("fps",60))
    # Reset every involved node after candidate preview; never edit original curves until selection.
    affected={j["node"] for chain in design["ik"] for j in chain["joints"]}
    scene.frame_set(1);scene.view_layers[0].update()
    rest={n:tuple(nodes[n].rotation_euler) for n in affected}
    def restore():
        for n,r in rest.items(): nodes[n].rotation_euler=r
        scene.frame_set(1);scene.view_layers[0].update()
    candidates={}
    for strategy in STRATEGIES:
        restore()
        try:
            baked,rows=bake_ik(scene,nodes,markers,design["ik"],end,out,strategy=strategy,preview=True)
            e=evaluate(scene,nodes,markers,design,end,out,strategy,baked)
            s=summarize(e,rows,baked,fps)
            candidates[strategy]=(baked,rows,e,s)
        finally:
            restore()
    base=candidates["legacy"]; bs=base[3]; summaries={}
    def eligible(item):
        _,_,e,s=item
        reasons=[]
        if not spatial_ok(base[2]["spatial"],e["spatial"]): reasons.append("spatial_regression")
        for i,v in e["contacts"].items():
            limit=float(design["contacts"][i].get("tolerance_m",.01))
            if v>limit or v>base[2]["contacts"][i]+.0001: reasons.append(f"contact_{i}")
        if s["full_weight_residual_m"]>min(.002,bs["full_weight_residual_m"]+.0001): reasons.append("full_weight_residual")
        if s["blend_residual_m"]>bs["blend_residual_m"]+.002: reasons.append("blend_residual")
        ratios=[]
        for n,values in s["metrics"].items():
            for m in METRICS:
                before=bs["metrics"][n][m]; after=values[m]
                if after>before*1.001+1e-5: reasons.append(n+"_"+m+"_regression")
                ratios.append(after/max(before,1e-5))
        for m in ("joint_speed_deg_s","joint_acceleration_deg_s2"):
            if s[m]>bs[m]*1.001+.01: reasons.append(m+"_regression")
        return reasons,sum(ratios)/len(ratios)
    valid=[]
    for label,item in candidates.items():
        reasons,score=eligible(item)
        summaries[label]={**item[3],"score":score,"eligible":not reasons,"rejection_reasons":reasons}
        if not reasons and label!="legacy" and score<.999: valid.append((score,label))
    selected=min(valid)[1] if valid else "legacy"
    result={"strategy":selected,"improved":bool(valid),"candidates":summaries,"post_bake_pass":False,
        "scope":"independent rigid chains; sampled position/kinematics/spatial guards; no artistic approval"}
    path=out/"ik_refinement_report.json";path.write_text(json.dumps(result,indent=2))
    if not valid and (spec.get("require_improvement") or not summaries["legacy"]["eligible"]):
        raise ValueError("no eligible IK improvement; see ik_refinement_report.json")
    baked,rows,e,s=candidates[selected]
    changed=commit_ik(nodes,baked,rows,out,selected)
    actual=evaluate(scene,nodes,markers,design,end,out,"post_bake")
    post=summarize(actual,rows,baked,fps)
    reasons,_=eligible((baked,rows,actual,post))
    # Compare baked marker kinematics to the selected preview, not just legacy.
    for n,m in post["metrics"].items():
        for k in METRICS:
            if abs(m[k]-s["metrics"][n][k])>max(1e-4,s["metrics"][n][k]*.002):
                reasons.append(n+"_"+k+"_bake_mismatch")
    result.update({"post_bake":post,"post_bake_pass":not reasons,"post_bake_rejections":reasons})
    path.write_text(json.dumps(result,indent=2))
    if reasons: raise ValueError("IK refinement bake regression; export refused")
    return changed

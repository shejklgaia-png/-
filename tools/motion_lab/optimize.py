"""Guarded sampled floor correction. Only explicit root vertical translation is edited."""
import json,math
from mathutils import Vector
from spatial import audit

def optimize(scene,nodes,markers,design,end,out):
    spec=design.get("optimize")
    if not spec: return set()
    spatial=design["spatial"]; floor=spatial["floor"]
    root=nodes[spec["root"]]
    if root.parent or root.constraints or root.animation_data and root.animation_data.nla_tracks:
        raise ValueError("V6 requires unconstrained unparented root without NLA")
    if root.delta_location.length>1e-8: raise ValueError("root delta location unsupported")
    cap=float(spec.get("max_lift_m",.2))
    if not math.isfinite(cap) or not 0<cap<=2: raise ValueError("invalid max lift")
    affected=[]
    for n in floor["meshes"]:
        o=nodes[n]
        while o and o!=root: o=o.parent
        if o==root: affected.append(n)
    if not affected: raise ValueError("root has no audited floor mesh")
    positions=[]; before_contacts={}
    def contacts(frame):
        values={}
        for i,c in enumerate(design.get("contacts",[])):
            if c["frames"][0]<=frame<=c["frames"][1]:
                p=markers[c["marker"]].matrix_world.translation
                target=markers[c["target_marker"]].matrix_world.translation if "target_marker" in c else Vector(c["target"])
                values[(frame,i)]=(p-target).length
        return values
    def baseline_hook(frame):
        positions.append(root.location.copy())
        before_contacts.update(contacts(frame))
    baseline=audit(scene,nodes,markers,spatial,end,out,frame_hook=baseline_hook,filename="spatial_before.json")
    depths=[max(r["floor"][n]["penetration_m"] for n in affected) for r in baseline["frames"]]
    def loss(report):
        return sum(v["penetration_m"] for r in report["frames"] for v in r["floor"].values())
    def violations(report):
        return {(v["frame"],v["kind"],str(v.get("nodes",v.get("marker",v.get("mesh",""))))) for v in report["violations"]}
    old=violations(baseline); old_loss=loss(baseline)
    candidates=[]; accepted=[]
    # Raised-cosine envelopes anticipate the floor correction instead of popping.
    for radius in (0,4,8):
        lifts=[]
        for i in range(end):
            lift=max(depths[j]*(.5+.5*math.cos(math.pi*abs(i-j)/(radius+1))) for j in range(max(0,i-radius),min(end,i+radius+1)))
            lifts.append(min(cap,lift))
        current={}
        def hook(frame):
            root.location=positions[frame-1]+Vector((0,0,lifts[frame-1]))
            scene.view_layers[0].update()
            current.update(contacts(frame))
        try:
            report=audit(scene,nodes,markers,spatial,end,out,frame_hook=hook,filename=f"spatial_candidate_{radius}.json")
        finally:
            root.location=positions[-1];scene.view_layers[0].update()
        added=violations(report)-old
        contact_bad=[k for k,v in current.items() if v>before_contacts[k]+.0001 or v>float(design["contacts"][k[1]].get("tolerance_m",.01))]
        # Do not allow an existing floor penetration or support/COM metric to worsen.
        worsened=False
        for a,b in zip(baseline["frames"],report["frames"]):
            for n,v in b["floor"].items():
                if v["penetration_m"]>a["floor"][n]["penetration_m"]+.0001: worsened=True
            for x,y in zip(a["supports"],b["supports"]):
                if abs(y["height_m"])>abs(x["height_m"])+.0001 or y["horizontal_drift_m"]>x["horizontal_drift_m"]+.0001: worsened=True
            m0,m1=a.get("static_margin_m"),b.get("static_margin_m")
            if m0 is not None and (m1 is None or m1<m0-.0001): worsened=True
        new_loss=loss(report)
        curvature=sum((lifts[i-1]-2*lifts[i]+lifts[i+1])**2 for i in range(1,end-1))
        score=curvature+sum(v*v for v in lifts)*.001
        row={"radius_frames":radius,"max_lift_m":max(lifts),"floor_loss_m_sum":new_loss,"new_violations":len(added),"contact_regressions":len(contact_bad),"metric_regression":worsened,"smoothness_cost":score,"eligible":not added and not contact_bad and not worsened and new_loss<old_loss-1e-6}
        candidates.append(row)
        if row["eligible"]: accepted.append((new_loss,score,radius,lifts))
    result={"before_floor_loss_m_sum":old_loss,"candidates":candidates,"accepted":False,"scope":"root vertical translation, sampled floor correction only"}
    if not accepted:
        (out/"optimization_report.json").write_text(json.dumps(result,indent=2))
        if spec.get("require_improvement") and old_loss>1e-6: raise ValueError("no safe correction candidate")
        return set()
    # Choose smoothest candidate among virtually equal minimum residuals.
    best=min(x[0] for x in accepted)
    _,_,radius,lifts=min((x for x in accepted if x[0]<=best+1e-5),key=lambda x:x[1])
    # No candidate altered authored animation curves. Bake only accepted root location.
    if root.animation_data and root.animation_data.action:
        for layer in root.animation_data.action.layers:
            for strip in layer.strips:
                bag=strip.channelbag(root.animation_data.action_slot)
                if bag:
                    for fc in list(bag.fcurves):
                        if fc.data_path=="location": bag.fcurves.remove(fc)
    for f,p in enumerate(positions,1):
        root.location=p+Vector((0,0,lifts[f-1]));root.keyframe_insert(data_path="location",frame=f,group=root.name)
    for layer in root.animation_data.action.layers:
        for strip in layer.strips:
            bag=strip.channelbag(root.animation_data.action_slot)
            if bag:
                for fc in bag.fcurves:
                    if fc.data_path=="location":
                        for k in fc.keyframe_points: k.interpolation="LINEAR"
    result.update({"accepted":True,"selected_radius_frames":radius,"lift_by_frame_m":lifts})
    actual_contacts={}
    def final_hook(frame): actual_contacts.update(contacts(frame))
    final=audit(scene,nodes,markers,spatial,end,out,frame_hook=final_hook,filename="spatial_after_bake.json")
    result["after_floor_loss_m_sum"]=loss(final)
    expected=next(r for r in candidates if r["radius_frames"]==radius)
    valid=abs(loss(final)-expected["floor_loss_m_sum"])<1e-4 and not violations(final)-old and all(v<=before_contacts[k]+.0001 and v<=float(design["contacts"][k[1]].get("tolerance_m",.01)) for k,v in actual_contacts.items())
    result["post_bake_pass"]=valid
    (out/"optimization_report.json").write_text(json.dumps(result,indent=2))
    if not valid: raise ValueError("post-bake regression; do not export")
    return {(root.name,"translation")} if any((p+Vector((0,0,lifts[i]))-positions[0]-Vector((0,0,lifts[0]))).length>1e-7 for i,p in enumerate(positions)) else set()

"""Read-only Bittaran authored clip sampling, in runtime local coordinates.
Candidate keeps authored key values and times; changes interpolation and entry/exit.
No gameplay solver, aim, hit windows, or source writes."""
import json,math
import bpy
from pathlib import Path
from mathutils import Vector
from bbmodel import vec,rot

def channel(keys,name):
    values=[]
    for k in keys:
        if k.get("channel","rotation")!=name or not k.get("data_points"): continue
        v=k["data_points"][0]
        values.append((float(k["time"]),Vector(tuple(float(v.get(a,0)) for a in "xyz"))))
    values.sort(key=lambda v:v[0])
    if any(b[0]<=a[0] for a,b in zip(values,values[1:])): raise ValueError("duplicate source key time")
    return values

def slope(a,b,c,axis):
    h0=b[0]-a[0];h1=c[0]-b[0]
    d0=(b[1][axis]-a[1][axis])/h0;d1=(c[1][axis]-b[1][axis])/h1
    if d0*d1<=0: return 0.
    w0=2*h1+h0;w1=h1+2*h0
    return (w0+w1)/(w0/d0+w1/d1)

def sample(keys,t,smooth):
    if not keys: return Vector((0,0,0))
    if t<=keys[0][0]: return keys[0][1].copy()
    if t>=keys[-1][0]: return keys[-1][1].copy()
    for i,(tb,b) in enumerate(keys[1:],1):
        if t<=tb:
            ta,a=keys[i-1];h=tb-ta;u=(t-ta)/h
            if not smooth: return a.lerp(b,u)
            # Monotone cubic Hermite component interpolation, zero end tangents.
            # No overshoot beyond each pair of authored Euler/position keys.
            m0=Vector(tuple(slope(keys[i-2],keys[i-1],keys[i],j) if i>1 else 0. for j in range(3)))
            m1=Vector(tuple(slope(keys[i-1],keys[i],keys[i+1],j) if i+1<len(keys) else 0. for j in range(3)))
            cubic=(2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*h*m0+(-2*u**3+3*u*u)*b+(u**3-u*u)*h*m1
            return a.lerp(b,u).lerp(cubic,float(smooth))
    raise ValueError("sample interval")

def _compile_clip(scene,d,nodes,end,out,blend=None):
    spec=d.get("bb_clip")
    if not spec:return
    if d["source_bbmodel"]!="models/bosses/Bittaran.bbmodel" or float(d["bb_unit_m"])!=.145:
        raise ValueError("V10 Bittaran runtime unit required")
    if d.get("tracks"):raise ValueError("do not mix source clip and explicit tracks")
    repo=Path(__file__).resolve().parents[2]
    model=json.loads((repo/d["source_bbmodel"]).read_text())
    clips={a["name"]:a for a in model["animations"]}
    wait=clips["Wait"];attack=clips[spec["name"]]
    fps=int(d["fps"]);duration=float(attack["length"])
    entry=int(spec["entry_frames"]);exit=int(spec["exit_frames"]);middle=round(duration*fps)
    if abs(middle/fps-duration)>1e-5 or entry<1 or exit<1 or end!=1+entry+middle+exit:raise ValueError("source clip frame timing")
    smooth=float(spec["mode"]=="candidate") if blend is None else blend
    if spec["mode"] not in ("baseline","candidate","guarded"):raise ValueError("invalid mode")
    unit=float(d["bb_unit_m"]);tracks={}
    for g in model["groups"]:
        uid=g["uuid"];o=nodes[uid];bind_p=o.location.copy();bind_q=o.rotation_euler.to_quaternion()
        w=wait.get("animators",{}).get(uid,{}).get("keyframes",[])
        a=attack.get("animators",{}).get(uid,{}).get("keyframes",[])
        if g["name"]=="Head":a=w # Head remains fixed at authored Wait, not a simulated live target.
        wr,wp=channel(w,"rotation"),channel(w,"position")
        ar,ap=channel(a,"rotation"),channel(a,"position")
        def pose(r,p,t,s):
            return bind_q @ rot(sample(r,t,s)).to_quaternion(),bind_p+vec(sample(p,t,s),unit)
        q0,p0=pose(wr,wp,0,False);qa,pa=pose(ar,ap,0,smooth);qb,pb=pose(ar,ap,duration,smooth)
        previous=None;rk=[];pk=[];rotations=[]
        for f in range(1,end+1):
            k=f-1
            if k<entry:
                u=k/entry;u=u+smooth*(u*u*(3-2*u)-u)
                q=q0.slerp(qa,u);p=p0.lerp(pa,u)
            elif k<=entry+middle:
                q,p=pose(ar,ap,(k-entry)/fps,smooth)
            else:
                u=(k-entry-middle)/exit;u=u+smooth*(u*u*(3-2*u)-u)
                q=qb.slerp(q0,u);p=pb.lerp(p0,u)
            q=q.normalized();rotations.append(tuple(q))
            e=q.to_euler("XYZ",previous) if previous is not None else q.to_euler("XYZ")
            previous=e.copy()
            rk.append({"frame":f,"value":[round(math.degrees(v),6) for v in e],"interpolation":"LINEAR"})
            pk.append({"frame":f,"value":[round(v,7) for v in p],"interpolation":"LINEAR"})
        # Keep all static channels as explicit endpoint keys for exact Wait pose;
        # avoid spurious dynamic channels from floating-point noise.
        tracks[uid]={}
        for name,keys in (("rotation_deg",rk),("location",pk)):
            if name=="rotation_deg":
                # Euler-compatible representations can vary for identical orientations.
                first=Vector(rotations[0])
                static=all(min((Vector(q)-first).length,(Vector(q)+first).length)<1e-6 for q in rotations)
            else:
                static=max((Vector(k["value"])-Vector(keys[0]["value"])).length for k in keys)<1e-6
            if static:
                keys=[keys[0],dict(keys[-1],value=keys[0]["value"])]
            tracks[uid][name]=keys
    d["tracks"]=tracks
    d["events"].update({"wait":1,"attack_start":entry+1,"apex":entry+61,"hold_end":entry+76,"impact_authored":entry+91,"attack_end":entry+middle+1,"recovered":end})
    (out/"source_clip_report.json").write_text(json.dumps({"clip":spec["name"],"mode":spec["mode"],"blend":smooth,"unit_m":unit,"source_duration":duration,"entry_frames":entry,"exit_frames":exit,"source_sha256":json.loads((out/"rig_report.json").read_text())["sha256"],"scope":"authored local pose + preview entry/exit; no runtime battle IK, aim, collision or gameplay timing; candidate not approved"},indent=2,ensure_ascii=False))


def _evaluate_tracks(d,nodes,end):
    """Read-only rigid FK sampling before animation insertion; restore bind pose."""
    fps=int(d["fps"])
    tracks=d["tracks"]
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in tracks}
    meshes=[o for o in nodes.values() if o.type=="MESH"]
    if not meshes or not d.get("markers"): raise ValueError("guard needs geometry and markers")
    points={name:[] for name in d["markers"]}; minima=[]
    try:
        for i in range(end):
            for uid,channels in tracks.items():
                o=nodes[uid]
                for prop,keys in channels.items():
                    if len(keys)==end: v=keys[i]["value"]
                    elif len(keys)==2 and keys[0]["value"]==keys[-1]["value"]: v=keys[0]["value"]
                    else: raise ValueError("unexpected guarded track")
                    if prop=="location": o.location=v
                    else: o.rotation_euler=[math.radians(x) for x in v]
            bpy.context.view_layer.update()
            for name,point in d["markers"].items():
                points[name].append(nodes[point["node"]].matrix_world @ Vector(point.get("local",[0,0,0])))
            # Exact minimum of rigid preview mesh vertices, not a bounding box.
            minima.append(min((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices))
    finally:
        for uid,(p,q) in saved.items():
            nodes[uid].location=p; nodes[uid].rotation_euler=q
        bpy.context.view_layer.update()
    metrics={}
    for name,p in points.items():
        v=[(b-a)*fps for a,b in zip(p,p[1:])]
        a=[(y-x)*fps for x,y in zip(v,v[1:])]
        j=[(y-x)*fps for x,y in zip(a,a[1:])]
        metrics[name]={"speed":max((x.length for x in v),default=0.),
                       "acceleration":max((x.length for x in a),default=0.),
                       "jerk":max((x.length for x in j),default=0.),
                       "loop_velocity":(v[-1]-v[0]).length}
    depth=[max(0.,minima[0]-z) for z in minima]
    result={"markers":metrics,"wait_min_z_m":minima[0],
            "max_relative_floor_depth_m":max(depth),"mean_relative_floor_depth_m":sum(depth)/end}
    if not all(math.isfinite(x) for m in metrics.values() for x in m.values()) or not all(math.isfinite(x) for x in minima):
        raise ValueError("nonfinite guarded evaluation")
    return result


def _compare(reference,candidate):
    """Conservative no-regression guard; baseline retained if none improve."""
    tolerances={"speed":.001,"acceleration":.05,"jerk":3.,"loop_velocity":.001}
    reasons=[]; ratios=[]
    for name,base in reference["markers"].items():
        for metric,b in base.items():
            c=candidate["markers"][name][metric]; tol=tolerances[metric]
            if c>b+tol: reasons.append(name+":"+metric)
            if b>tol: ratios.append(c/b)
    for metric in ("max_relative_floor_depth_m","mean_relative_floor_depth_m"):
        b=reference[metric];c=candidate[metric]
        if c>b+.0001: reasons.append(metric)
        if b>.0001: ratios.append(c/b)
    if abs(candidate["wait_min_z_m"]-reference["wait_min_z_m"])>.0001:
        reasons.append("wait_pose_floor")
    return reasons,sum(ratios)/len(ratios) if ratios else 1.


def compile_clip(scene,d,nodes,end,out):
    spec=d.get("bb_clip")
    if not spec or spec["mode"]!="guarded":
        return _compile_clip(scene,d,nodes,end,out)
    if d.get("tracks"): raise ValueError("do not mix source clip and explicit tracks")
    rows=[]; selected=None; best=1.; baseline=None
    for blend in (0.,.125,.25,.375,.5,.625,.75,.875,1.):
        d["tracks"]={}
        _compile_clip(scene,d,nodes,end,out,blend)
        result=_evaluate_tracks(d,nodes,end)
        if baseline is None: baseline=result
        reasons,score=_compare(baseline,result)
        rows.append({"blend":blend,"metrics":result,"rejections":reasons,"score":score})
        if selected is None or (not reasons and score<best-1e-6):
            selected=(blend,d["tracks"],(out/"source_clip_report.json").read_text())
            best=score
    blend,tracks,report=selected
    d["tracks"]=tracks
    (out/"source_clip_report.json").write_text(report)
    baked=_evaluate_tracks(d,nodes,end)
    reasons,score=_compare(baseline,baked)
    if reasons or abs(score-best)>1e-6: raise ValueError("guard selection changed")
    (out/"clip_guard_report.json").write_text(json.dumps({
        "version":11,"selected_blend":blend,"fallback_to_linear":blend==0.,
        "candidates":rows,"selected_metrics":baked,
        "scope":"sampled rigid preview; Wait-relative floor only, no gameplay contact correction; no automatic adoption"
    },indent=2,ensure_ascii=False))

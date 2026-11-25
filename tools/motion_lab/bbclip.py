"""Read-only Bittaran authored clip sampling, in runtime local coordinates.
Candidate keeps authored key values and times; changes interpolation and entry/exit.
No gameplay solver, aim, hit windows, or source writes."""
import json,math
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
            return (2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*h*m0+(-2*u**3+3*u*u)*b+(u**3-u*u)*h*m1
    raise ValueError("sample interval")

def compile_clip(scene,d,nodes,end,out):
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
    smooth=spec["mode"]=="candidate"
    if spec["mode"] not in ("baseline","candidate"):raise ValueError("invalid mode")
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
        previous=None;rk=[];pk=[]
        for f in range(1,end+1):
            k=f-1
            if k<entry:
                u=k/entry;u=u*u*(3-2*u) if smooth else u
                q=q0.slerp(qa,u);p=p0.lerp(pa,u)
            elif k<=entry+middle:
                q,p=pose(ar,ap,(k-entry)/fps,smooth)
            else:
                u=(k-entry-middle)/exit;u=u*u*(3-2*u) if smooth else u
                q=qb.slerp(q0,u);p=pb.lerp(p0,u)
            e=q.to_euler("XYZ",previous) if previous is not None else q.to_euler("XYZ")
            previous=e.copy()
            rk.append({"frame":f,"value":[round(math.degrees(v),6) for v in e],"interpolation":"LINEAR"})
            pk.append({"frame":f,"value":[round(v,7) for v in p],"interpolation":"LINEAR"})
        # Keep all static channels as explicit endpoint keys for exact Wait pose;
        # avoid spurious dynamic channels from floating-point noise.
        tracks[uid]={}
        for name,keys in (("rotation_deg",rk),("location",pk)):
            if max((Vector(k["value"])-Vector(keys[0]["value"])).length for k in keys)<1e-5:
                keys=[keys[0],dict(keys[-1],value=keys[0]["value"])]
            tracks[uid][name]=keys
    d["tracks"]=tracks
    d["events"].update({"wait":1,"attack_start":entry+1,"apex":entry+61,"hold_end":entry+76,"impact_authored":entry+91,"attack_end":entry+middle+1,"recovered":end})
    (out/"source_clip_report.json").write_text(json.dumps({"clip":spec["name"],"mode":spec["mode"],"unit_m":unit,"source_duration":duration,"entry_frames":entry,"exit_frames":exit,"source_sha256":json.loads((out/"rig_report.json").read_text())["sha256"],"scope":"authored local pose + preview entry/exit; no runtime battle IK, aim, collision or gameplay timing; candidate not approved"},indent=2,ensure_ascii=False))

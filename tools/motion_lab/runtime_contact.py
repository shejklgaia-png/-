"""V20 per-contact sidecar and independent FK/IK replay diagnostics.
The authored action is never rejected merely for a correctable planted-foot slip.
"""
import json,math
from mathutils import Vector,Quaternion,Euler
from bisect import bisect_right

ROLE_IDS={"FrontFoot_L":"leg_fl","FrontFoot_R":"leg_fr","RearFoot_L":"leg_rl","RearFoot_R":"leg_rr"}

def smooth(x):
    x=max(0.,min(1.,x))
    return x*x*(3-2*x)

def intervals(phases,frames,end):
    result={n:[] for n in ROLE_IDS}
    for n in result:
        for i,(a,b) in enumerate(zip(phases,phases[1:])):
            if n not in a["support"] or n not in b["support"]:continue
            if (a["feet"][n]-b["feet"][n]).length>1e-7 or abs(a["foot_yaws"][n]-b["foot_yaws"][n])>1e-7:continue
            lo,hi=frames[i:i+2]
            rows=result[n]
            if rows and rows[-1]["end_frame"]==lo:
                rows[-1]["end_frame"]=hi
            else:
                rows.append({"start_frame":lo,"end_frame":hi,"planned_anchor_m":list(a["feet"][n])})
        for i,r in enumerate(result[n]):
            r["id"]=i+1
            r["ramp_frames"]=min(4,max(1,(r["end_frame"]-r["start_frame"])//2))
    return result

def weight(r,f,end):
    if not r["start_frame"]<=f<=r["end_frame"]:return 0.
    a=1. if r["start_frame"]==1 else smooth((f-r["start_frame"])/r["ramp_frames"])
    b=1. if r["end_frame"]==end else smooth((r["end_frame"]-f)/r["ramp_frames"])
    return min(a,b)

def sample(keys,f):
    i=max(0,bisect_right([x["frame"] for x in keys],f)-1)
    a=keys[i]; b=keys[min(i+1,len(keys)-1)]
    t=(f-a["frame"])/(b["frame"]-a["frame"]) if b["frame"]!=a["frame"] else 0.
    return [x+(y-x)*t for x,y in zip(a["value"],b["value"])]

def compile_contact_layer(d,nodes,end,out,phases,frames,geom,span):
    import bpy
    spec=d["procedural_motion"]
    cap=float(spec.get("max_contact_offset_m",.30))
    if not math.isfinite(cap) or not .01<=cap<=.60:raise ValueError("contact correction cap")
    contacts=intervals(phases,frames,end)
    packet={"format":"SERA_MOTION_CONTACT_V1","fps":int(d["fps"]),"end_frame":end,
            "action":spec["action"],"max_contact_offset_m":cap,
            "anchor_policy":"capture_rendered_world_contact_at_interval_start",
            "coordinate_note":"planned_anchor_m is Blender Z-up diagnostic only; runtime captures world-space anchors, never imports these coordinates",
            "legs":{ROLE_IDS[n]:rows for n,rows in contacts.items()}}
    (out/"runtime_contact_ik.json").write_text(json.dumps(packet,indent=2))
    tracks=d["tracks"];meshes=[o for o in nodes.values() if o.type=="MESH"]
    by_name={o.name:uid for uid,o in nodes.items()}
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in tracks}
    dense={uid:{p:[] for p in c} for uid,c in tracks.items()}
    anchors={};rows=[];previous={}
    def update():bpy.context.view_layer.update()
    def set_world(o,q):
        o.rotation_euler=(o.parent.matrix_world.to_quaternion().inverted()@q).to_euler("XYZ",o.rotation_euler)
        update()
    def lowest(o):return min((o.matrix_world@v.co).z for v in o.data.vertices)
    try:
        for f in range(1,end+1):
            for uid,c in tracks.items():
                o=nodes[uid]
                o.location=sample(c["location"],f)
                o.rotation_euler=Euler([math.radians(v) for v in sample(c["rotation_deg"],f)],"XYZ")
            update()
            before_floor=min(lowest(o) for o in meshes);feet={}
            for n,(hip,knee,foot,_,local,a,b) in geom.items():
                r=next((r for r in contacts[n] if r["start_frame"]<=f<=r["end_frame"]),None)
                if r is None:
                    feet[n]={"weight":0.,"state":"free"};continue
                k=(n,r["id"]);pos=foot.matrix_world@local;rot=foot.matrix_world.to_quaternion()
                mesh=nodes[d["support_lock"]["sole_meshes"][n]]
                if k not in anchors:
                    target=pos.copy();target.z-=lowest(mesh);anchors[k]=(target,rot.copy())
                target,q=anchors[k];w=weight(r,f,end)
                delta=target-pos;before=delta.length
                requested=delta*w
                if requested.length>cap:requested=requested.normalized()*cap
                goal=pos+requested;desired=rot.slerp(q,w)
                reach_error=0.
                if w>0:
                    h=hip.matrix_world.translation.copy();knee_p=knee.matrix_world.translation.copy()
                    v=goal-desired@local-h;dist=v.length;l1=a.length;l2=b.length
                    if min(dist,l1,l2)>1e-5:
                        direction=v.normalized();rlen=max(abs(l1-l2)+1e-5,min(l1+l2-1e-5,dist))
                        along=(l1*l1-l2*l2+rlen*rlen)/(2*rlen)
                        pole=knee_p-h;pole-=direction*pole.dot(direction)
                        if pole.length<1e-5:
                            pole=Vector((0,0,1));pole-=direction*pole.dot(direction)
                        if pole.length<1e-5:
                            pole=Vector((1,0,0));pole-=direction*pole.dot(direction)
                        bend=math.sqrt(max(0.,l1*l1-along*along))
                        hk=h+direction*along+pole.normalized()*bend
                        hr=hip.matrix_world.to_quaternion()
                        set_world(hip,(hr@a).rotation_difference(hk-h)@hr)
                        kr=knee.matrix_world.to_quaternion();kp=knee.matrix_world.translation.copy()
                        set_world(knee,(kr@b).rotation_difference(h+direction*rlen-kp)@kr)
                        set_world(foot,desired)
                        reach_error=abs(dist-rlen)
                    else:reach_error=dist
                after=(foot.matrix_world@local-target).length
                feet[n]={"weight":w,"before_m":before,"after_m":after,"reach_clamp_m":reach_error,
                         "offset_capped":delta.length*w>cap,"state":"planted" if w>=.999 else "transition"}
            after_floor=min(lowest(o) for o in meshes)
            for uid,c in dense.items():
                o=nodes[uid];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",previous[uid]) if uid in previous else q.to_euler("XYZ")
                previous[uid]=e.copy()
                c["location"].append({"frame":f,"value":list(o.location),"interpolation":"LINEAR"})
                c["rotation_deg"].append({"frame":f,"value":[math.degrees(v) for v in e],"interpolation":"LINEAR"})
            rows.append({"frame":f,"feet":feet,"floor_off_m":max(0.,-before_floor),"floor_on_m":max(0.,-after_floor)})
    finally:
        for uid,(loc,rot) in saved.items():nodes[uid].location=loc;nodes[uid].rotation_euler=rot
        update()
    planted=[v for row in rows for v in row["feet"].values() if v["weight"]>=.999]
    summary={"max_planted_error_off_m":max((v["before_m"] for v in planted),default=0.),
             "max_planted_error_on_m":max((v["after_m"] for v in planted),default=0.),
             "max_floor_off_m":max(r["floor_off_m"] for r in rows),
             "max_floor_on_m":max(r["floor_on_m"] for r in rows),
             "capped_planted_samples":sum(v["offset_capped"] for v in planted),
             "unreachable_planted_samples":sum(v["reach_clamp_m"]>.005 for v in planted)}
    (out/"runtime_ik_preview_report.json").write_text(json.dumps({"scope":"offline analogue of existing runtime two-link solver; not actual Godot replay","summary":summary,"frames":rows},indent=2))
    (out/"runtime_ik_preview_tracks.json").write_text(json.dumps({"format":"SERA_MOTION_TRACKS_V1","tracks":dense},separators=(",",":")))
    # Default GLB retains the authored FK; a separate explicit review export can bake IK.
    if spec.get("preview_ik",False):d["tracks"]=dense

"""V19 geometry-only key-pose generator. Never reads an animation clip."""
import math,json
from mathutils import Vector,Quaternion
from spatial import hull,margin
from sole import mass_proxy

ROLES=("FrontFoot_L","FrontFoot_R","RearFoot_L","RearFoot_R")
ACTIONS=("idle","walk_forward","walk_backward","turn_left","turn_right","stomp","sweep","hit","down_recover")

def mean(vs): return sum(vs,Vector((0,0,0)))/len(vs)
def horizontal(v): return Vector((v.x,v.y,0))
def yaw(a): return Quaternion((0,0,1),a)
def deg(v): return [round(math.degrees(x),6) for x in v]

def plan(action,root,feet,forward,span,strike,performance=False):
    """Sparse world-space task goals; stance contacts are explicit per pose."""
    if action not in ACTIONS: raise ValueError("unsupported procedural action")
    keys=[]; side=Vector((forward.y,-forward.x,0))
    def add(t,name,body=None,goals=None,air=(),angle=0.,tilt=0.,nod=0.,foot_yaws=None,foot_pitch=0.):
        p=root.copy() if body is None else body.copy()
        q={n:v.copy() for n,v in (feet if goals is None else goals).items()}
        support=[n for n in ROLES if n not in air]
        keys.append(dict(t=t,event=name,body=p,feet=q,support=support,yaw=angle,tilt=tilt,head=nod,
                         foot_yaws=dict(foot_yaws) if foot_yaws is not None else {n:0. for n in ROLES},foot_pitch=foot_pitch))
    add(0.,"ready")
    def shift(body,goals,air):
        p=body.copy(); stable=mean([goals[n] for n in ROLES if n not in air])
        p+=(.55 if performance else .33)*horizontal(stable-p);return p
    if action=="idle":
        add(.30,"compress",root+Vector((0,0,-.005*span)),nod=1.)
        add(.68,"release",root+Vector((0,0,.003*span)),nod=-.5)
        add(1.,"recovered")
    elif action.startswith(("walk_","turn_")):
        distance=(.20 if performance else .08)*span*(1 if action=="walk_forward" else -1) if action.startswith("walk_") else 0.
        angle=math.radians(45 if performance else 12)*(1 if action=="turn_left" else -1) if action.startswith("turn_") else 0.
        travel=forward*distance;final={n:root+yaw(angle)@(v-root)+travel for n,v in feet.items()}
        q={n:v.copy() for n,v in feet.items()}
        foot_yaws={n:0. for n in ROLES}
        order=("RearFoot_L","FrontFoot_L","RearFoot_R","FrontFoot_R") if angle>=0 else ("RearFoot_R","FrontFoot_R","RearFoot_L","FrontFoot_L")
        cycles=2 if performance and action.startswith("turn_") else 1
        steps=4*cycles
        dt=.92/steps
        for j,n in enumerate(order*cycles):
            t=j*dt;old=q[n].copy();body=root+travel*(j/steps)
            fraction=(j//4+1)/cycles
            dest=root+yaw(angle*fraction)@(feet[n]-root)+travel*fraction
            add(t+dt*(.04/.23),f"shift_{j+1}",shift(body,q,(n,)),q,angle=angle*j/steps,foot_yaws=foot_yaws)
            q[n]=(old+dest)*.5+Vector((0,0,(.10 if performance else .055)*span))
            foot_yaws[n]=angle*(fraction-.5/cycles)
            add(t+dt*(.12/.23),f"swing_{j+1}",shift(body,q,(n,)),q,(n,),angle=angle*(j+.5)/steps,foot_yaws=foot_yaws)
            q[n]=dest.copy()
            foot_yaws[n]=angle*fraction
            add(t+dt*(.21/.23),f"land_{j+1}",root+travel*((j+1)/steps),q,angle=angle*(j+1)/steps,foot_yaws=foot_yaws)
        add(1.,"recovered",root+travel,final,angle=angle,foot_yaws=foot_yaws)
    elif action in ("stomp","sweep"):
        q={n:v.copy() for n,v in feet.items()}; body=shift(root,q,(strike,))
        add(.16,"anticipation",body+Vector((0,0,-.015*span)),q,nod=-2.)
        lift=(.48 if action=="stomp" else .22) if performance else (.13 if action=="stomp" else .065)
        inward=horizontal(root-feet[strike]).normalized()*.11*span if performance else Vector((0,0,0))
        q[strike]=feet[strike]+Vector((0,0,lift*span))+inward-forward*(.07 if performance else .025)*span
        add(.38,"apex",body,q,(strike,),tilt=math.radians(-9 if performance else 0),nod=-8. if performance else -3.,foot_pitch=math.radians(80 if performance else 0))
        add(.50,"hold_end",body,q,(strike,),tilt=math.radians(-9 if performance else 0),nod=-8. if performance else -3.,foot_pitch=math.radians(80 if performance else 0))
        if action=="sweep":
            q[strike]=feet[strike]+forward*.075*span+side*(.045*span if strike.endswith("_R") else -.045*span)+Vector((0,0,.055*span))
            swing_body=body+horizontal(feet[strike]-root).normalized()*.06*span if performance else body
            add(.61,"sweep_pass",swing_body,q,(strike,),angle=math.radians((20 if strike.endswith("_L") else -20) if performance else 0),tilt=math.radians(8 if performance else 0),nod=4. if performance else 1.,foot_pitch=math.radians(45 if performance else 0))
        q[strike]=feet[strike]+forward*(.13 if performance else .045)*span
        add(.68,"impact",body+Vector((0,0,-(.035 if performance else .009)*span)),q,tilt=math.radians(7 if performance else 0),nod=6. if performance else 2.)
        q[strike]=(q[strike]+feet[strike])*.5+Vector((0,0,.035*span))
        add(.83,"return_swing",body,q,(strike,))
        add(1.,"recovered")
    elif action=="hit":
        add(.18,"hit_recoil",root-forward*(.06 if performance else .02)*span+Vector((0,0,-(.035 if performance else .012)*span)),tilt=math.radians(15 if performance else 5),nod=10. if performance else 4.)
        add(.46,"counter_recoil",root+forward*(.02 if performance else .008)*span,tilt=math.radians(-6 if performance else -2),nod=-5. if performance else -2.)
        add(1.,"recovered")
    elif action=="down_recover":
        # A supported collapse prototype; not a physical fall or side roll.
        add(.22,"collapse",root+Vector((0,0,-.09*span)),tilt=math.radians(7),nod=5.)
        add(.53,"down_hold",root+Vector((0,0,-.10*span)),tilt=math.radians(7),nod=5.)
        add(.78,"rise",root+Vector((0,0,-.035*span)),tilt=math.radians(2),nod=2.)
        add(1.,"recovered")
    return keys

def compile_procedural(d,nodes,end,out):
    spec=d.get("procedural_motion")
    if not spec:return
    if d.get("tracks") or d.get("bb_clip") or d.get("pose_sequence") or d.get("events"):
        raise ValueError("procedural motion cannot consume an existing animation")
    if d.get("rig_discovery",{}).get("mode")!="quadruped":raise ValueError("quadruped role discovery required")
    import bpy
    chains=d["multifoot_ik"]["chains"]; stance=d["support_lock"]
    if set(chains)!=set(ROLES) or any(len(c)!=3 for c in chains.values()):
        raise ValueError("V19 expects two links plus a terminal foot per leg")
    root=nodes[stance["root"]];head=nodes[d["markers"]["Head"]["node"]]
    if root.parent is not None or head.parent!=root:raise ValueError("unsupported body hierarchy")
    objects=[root,head]+[nodes[u] for c in chains.values() for u in c]
    meshes=[o for o in nodes.values() if o.type=="MESH"]
    if any(o.constraints or o.rotation_mode!="XYZ" or any(abs(s-1)>1e-5 for s in o.scale) for o in objects):
        raise ValueError("V19 requires unit-scale unconstrained rigid XYZ groups")
    bpy.context.view_layer.update()
    saved={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in objects}
    ref={o.name:o.matrix_world.to_quaternion() for o in objects}
    rb=root.matrix_world.translation.copy();rq=ref[root.name]
    ankle={n:nodes[c[-1]].matrix_world.translation.copy() for n,c in chains.items()}
    span=sum((ankle[l]-ankle[r]).length for l,r in (("FrontFoot_L","FrontFoot_R"),("RearFoot_L","RearFoot_R")))/2
    if not math.isfinite(span) or span<.1:raise ValueError("invalid model span")
    forward=horizontal(mean([ankle[n] for n in ROLES[:2]])-mean([ankle[n] for n in ROLES[2:]])).normalized()
    if forward.length<.9:raise ValueError("degenerate front/back")
    side=Vector((forward.y,-forward.x,0))
    center=mean(list(ankle.values()))
    geom={};feet={}
    for n,c in chains.items():
        hip,knee,foot=[nodes[u] for u in c];mesh=nodes[stance["sole_meshes"][n]]
        if knee.parent!=hip or foot.parent!=knee or hip.parent!=root or mesh.parent!=foot:
            raise ValueError("V19 direct two-link hierarchy required")
        # Determine the terminal contact face from the direction of the foot
        # geometry relative to its pivot, rather than a hard-coded BB angle.
        relative=foot.matrix_world.inverted()@mesh.matrix_world
        vs=[relative@v.co for v in mesh.data.vertices]
        v=mean(vs)
        if v.length<.001:raise ValueError("ambiguous foot extension; explicit contact axis needed")
        q=(ref[foot.name]@v).rotation_difference(Vector((0,0,-1)))@ref[foot.name]
        low=min((q@p).z for p in vs)
        patch=[p for p in vs if (q@p).z<=low+.001*span]
        anchor=mean(patch)
        # Contract the wide bind stance to leave room for knee flexion.
        offset=horizontal(ankle[n]-center)
        target=horizontal(center)+side*(offset.dot(side)*.70)+forward*offset.dot(forward)
        feet[n]=target
        geom[n]=(hip,knee,foot,q,anchor,knee.location.copy(),foot.location.copy())
        d["markers"][n+"_Sole"]={"node":c[-1],"local":list(anchor)}
    base=Vector((rb.x,rb.y,.24*span))
    performance=spec.get("profile")=="performance_v20"
    phases=plan(spec["action"],base,feet,forward,span,stance["strike_marker"],performance)
    frame_ids=[1+round(p["t"]*(end-1)) for p in phases]
    if len(set(frame_ids))!=len(frame_ids) or frame_ids[-1]!=end:raise ValueError("insufficient frames")
    from dynamics import Interference
    interference=Interference(meshes)
    mass=[(o,*mass_proxy(o)) for o in meshes];total=sum(w for _,w,_,_ in mass)
    if total<=0:raise ValueError("empty geometry mass")
    tracks={uid:{"location":[],"rotation_deg":[]} for uid,o in nodes.items() if o in objects}
    previous={};reports=[]
    def update():bpy.context.view_layer.update()
    def set_world(o,q):
        local=o.parent.matrix_world.to_quaternion().inverted()@q if o.parent else q
        o.rotation_euler=local.to_euler("XYZ",previous[o.name]) if o.name in previous else local.to_euler("XYZ")
        update()
    try:
        for f,p in zip(frame_ids,phases):
            turn=yaw(p["yaw"])
            root.location=p["body"]
            root.rotation_euler=(Quaternion(side,p["tilt"])@turn@rq).to_euler("XYZ")
            head.rotation_euler=(saved[head.name][1].to_quaternion()@Quaternion((1,0,0),math.radians(p["head"]))).to_euler("XYZ")
            update()
            errors={};reach={}
            for n,(hip,knee,foot,fq,anchor,a,b) in geom.items():
                desired=yaw(p["foot_yaws"][n])@fq
                if n==stance["strike_marker"] and n not in p["support"] and p["foot_pitch"]:
                    desired=Quaternion(side,p["foot_pitch"])@desired
                target=p["feet"][n]-desired@anchor
                h=hip.matrix_world.translation.copy();v=target-h
                l1,l2=a.length,b.length
                if min(l1,l2)<.001 or v.length<.001:raise ValueError("degenerate two-link chain")
                direction=v.normalized();r=max(abs(l1-l2)+1e-5,min(l1+l2-1e-5,v.length))
                outward=horizontal(h-root.matrix_world.translation)
                pole=Vector((0,0,1))+.35*outward.normalized()
                pole-=direction*pole.dot(direction)
                if pole.length<1e-5:
                    pole=forward-direction*forward.dot(direction)
                if pole.length<1e-5:raise ValueError("degenerate knee pole")
                proj=(l1*l1-l2*l2+r*r)/(2*r)
                bend=math.sqrt(max(0.,l1*l1-proj*proj))
                knee_target=h+direction*proj+pole.normalized()*bend
                hip_ref=turn@ref[hip.name];knee_ref=turn@ref[knee.name]
                set_world(hip,(hip_ref@a).rotation_difference(knee_target-h)@hip_ref)
                k=knee.matrix_world.translation.copy();ankle_target=h+direction*r
                set_world(knee,(knee_ref@b).rotation_difference(ankle_target-k)@knee_ref)
                set_world(foot,desired)
                errors[n]=(foot.matrix_world@anchor-p["feet"][n]).length
                reach[n]=abs(v.length-r)
            com=sum((w*(o.matrix_world@v) for o,w,v,_ in mass),Vector((0,0,0)))/total
            actual={n:geom[n][2].matrix_world@geom[n][4] for n in ROLES}
            lows={n:min((nodes[stance["sole_meshes"][n]].matrix_world@v.co).z for v in nodes[stance["sole_meshes"][n]].data.vertices) for n in ROLES}
            support_margin=margin(hull([actual[n] for n in p["support"]]),com)
            floor=min((o.matrix_world@v.co).z for o in meshes for v in o.data.vertices)
            interference.sample()
            hits=interference.frames[-1]
            # Measurements, not quality guarantees or automatic adoption.
            flags=[]
            if max(errors.values())>.005:flags.append("unreached_foot_target")
            if floor<-.002:flags.append("floor_penetration")
            if hits:flags.append("interference_candidate")
            if any(abs(lows[n])>.005 for n in p["support"]):flags.append("support_height")
            if support_margin is None or support_margin<0:flags.append("static_support_margin")
            for uid,channels in tracks.items():
                o=nodes[uid];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",previous[o.name]) if o.name in previous else q.to_euler("XYZ")
                previous[o.name]=e.copy()
                channels["location"].append({"frame":f,"value":list(o.location),"interpolation":"LINEAR"})
                channels["rotation_deg"].append({"frame":f,"value":deg(e),"interpolation":"LINEAR"})
            reports.append({"frame":f,"event":p["event"],"support":p["support"],
                            "targets_m":{n:list(v) for n,v in p["feet"].items()},"actual_m":{n:list(v) for n,v in actual.items()},
                            "foot_error_m":errors,"reach_clamp_m":reach,"foot_yaw_deg":{n:math.degrees(v) for n,v in p["foot_yaws"].items()},"foot_min_z_m":lows,
                            "min_mesh_z_m":floor,"com_proxy_m":list(com),"support_margin_m":support_margin,"interference_candidates":hits,"flags":flags})
    finally:
        for o in objects:o.location,o.rotation_euler=saved[o.name]
        update()
    d["tracks"]=tracks;d["events"]={p["event"]:f for p,f in zip(phases,frame_ids)}
    d["export_poses"]=[{"id":p["event"],"frame":f} for p,f in zip(phases,frame_ids)]
    d["pose_export_channels"]={uid:list(c) for uid,c in tracks.items()}
    # Every interval with unchanged planned support is checked by the existing
    # sampled contact diagnostics. No auto-approval when interpolation slips.
    contacts=[]
    for i,(a,b) in enumerate(zip(phases,phases[1:])):
        for n in ROLES:
            if n in a["support"] and n in b["support"] and (a["feet"][n]-b["feet"][n]).length<1e-7:
                contacts.append({"marker":n+"_Sole","frames":[frame_ids[i],frame_ids[i+1]],"target":list(a["feet"][n]),"tolerance_m":.005})
    d["contacts"]=contacts
    d.setdefault("spatial",{}).setdefault("floor",{"z":0.,"tolerance_m":.002,"meshes":[uid for uid,o in nodes.items() if o.type=="MESH"]})
    if performance:
        from runtime_contact import compile_contact_layer
        compile_contact_layer(d,nodes,end,out,phases,frame_ids,geom,span)
    (out/"procedural_pose_report.json").write_text(json.dumps({
        "version":20 if performance else 19,"action":spec["action"],"source_animation_used":False,"span_m":span,
        "forward_world":list(forward),"key_poses":reports,"tracks":tracks,"planned_contact_intervals":contacts,
        "key_pose_flag_count":sum(len(r["flags"]) for r in reports),
        "interference":interference.report(),
        "status":"review_required","scope":"geometry-derived analytic two-link IK, approximate sole axis, sparse poses only; no swept collision, verified joint limits, physical fall, or dynamic trajectory optimization"
    },indent=2,ensure_ascii=False))

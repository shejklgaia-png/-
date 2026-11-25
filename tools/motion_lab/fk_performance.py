"""V21 explicit joint-direction authoring, then optional planted-leg IK.
Bittaran rigid chains only. No existing animation data consumed.
"""
import json,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler
from bisect import bisect_right

# Authoring angles use right-handed Y-up (GLTF), convert to Blender Z-up.
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
ROLES=("FrontFoot_L","FrontFoot_R","RearFoot_L","RearFoot_R")

def direction(sign,front,elevation,bearing):
    e,b=map(math.radians,(elevation,bearing))
    return C@Vector((sign*math.cos(e)*math.cos(b),math.sin(e),-front*math.cos(e)*math.sin(b)))

def rotation(angles):
    return (C@Euler(tuple(math.radians(v) for v in angles),"XYZ").to_matrix()@C.transposed()).to_quaternion()

def pchip(times,values,x):
    """Shape-preserving cubic Hermite interpolation; componentwise angle curves."""
    h=[b-a for a,b in zip(times,times[1:])]
    delta=[(b-a)/dt for a,b,dt in zip(values,values[1:],h)]
    def endpoint(h0,h1,d0,d1):
        m=((2*h0+h1)*d0-h0*d1)/(h0+h1)
        if m*d0<=0:return 0.
        if d0*d1<0 and abs(m)>3*abs(d0):return 3*d0
        return m
    slopes=[endpoint(h[0],h[1],delta[0],delta[1])]
    for i in range(1,len(times)-1):
        a,b=delta[i-1],delta[i]
        if a*b<=0:slopes.append(0.)
        else:
            w1=2*h[i]+h[i-1];w2=h[i]+2*h[i-1]
            slopes.append((w1+w2)/(w1/a+w2/b))
    slopes.append(endpoint(h[-1],h[-2],delta[-1],delta[-2]))
    i=max(0,min(len(h)-1,bisect_right(times,x)-1))
    u=max(0.,min(1.,(x-times[i])/h[i]));u2=u*u;u3=u2*u
    return (2*u3-3*u2+1)*values[i]+(u3-2*u2+u)*h[i]*slopes[i]+(-2*u3+3*u2)*values[i+1]+(u3-u2)*h[i]*slopes[i+1]

def compile_fk(d,nodes,end,out):
    import bpy
    from runtime_contact import compile_contact_layer
    spec=d["fk_performance"]
    if d.get("tracks") or d.get("bb_clip") or d.get("pose_sequence") or d.get("procedural_motion") or d.get("events"):
        raise ValueError("FK authoring requires exclusive new pose data")
    version=int(spec.get("version",21))
    if version not in (21,22,25):raise ValueError("unsupported FK performance version")
    library="fk_attack_poses_v25.json" if version==25 else f"fk_stomp_poses_v{version}.json"
    lib=json.loads((Path(__file__).resolve().parent/library).read_text())
    fmt=3 if version==25 else version-20
    if lib["format"]!=f"SERA_FK_PERFORMANCE_V{fmt}" or d["source_bbmodel"]!="models/bosses/Bittaran.bbmodel":
        raise ValueError("FK library requires calibrated Bittaran geometry")
    variant=spec.get("variant","sweep" if version==25 else "chain" if version==22 else "extended")
    whip_revision=4 if spec.get("contact_policy")=="whip_flick_v25_r4" else 3
    if variant=="sweep_reverse" and not (version==25 and whip_revision==4):raise ValueError("reverse sweep requires revision 4")
    selected=lib["variants"]["sweep" if variant=="sweep_reverse" else variant];keys=selected["keys"]
    duration=selected["duration"] if version==25 else lib["duration"]
    whip=spec.get("contact_policy") in ("whip_flick_v25","whip_flick_v25_r4")
    whip_rows=None
    if whip:
        if version!=25:raise ValueError("whole-chain attack requires V25")
        from whip_flick import WholeChain,rows_for,source_keys
        whip_rows=rows_for(variant,whip_revision)
        keys=source_keys(whip_rows,lib["neutral"],keys[0][6])
        duration=whip_rows[-1][0]/60
    support_order=lib.get("support_order",[])
    if version in (22,25) and support_order!=["FrontFoot_R","RearFoot_L","RearFoot_R"]:raise ValueError("invalid support role order")
    if version in (22,25) and any(len(k)!=7 or len(k[6])!=9 or any(len(v)!=3 for v in k[6]) for k in keys):raise ValueError("invalid authored support keys")
    fps=int(d["fps"])
    if len(keys)<3 or keys[0][0]!=0 or keys[-1][0]!=duration or any(b[0]<=a[0] for a,b in zip(keys,keys[1:])):raise ValueError("invalid FK time keys")
    if version==25 and (keys[-2][1]!="settle" or keys[-1][1]!="recovered" or keys[0][2:]!=keys[-2][2:] or keys[0][2:]!=keys[-1][2:]):raise ValueError("V25 requires exact stable landing/rest keys")
    if fps!=lib["fps"] or end!=round(duration*fps)+1:raise ValueError("V21 sample range mismatch")
    stance=d["support_lock"];chains=d["multifoot_ik"]["chains"]
    if set(chains)!=set(ROLES) or any(len(c)!=3 for c in chains.values()) or stance["strike_marker"]!="FrontFoot_L":
        raise ValueError("V21 expects four direct three-joint chains and front-left striker")
    root=nodes[stance["root"]];head=nodes[d["markers"]["Head"]["node"]]
    objects=[root,head]+[nodes[u] for c in chains.values() for u in c]
    if root.parent or head.parent!=root or any(o.constraints or any(abs(x-1)>1e-5 for x in o.scale) for o in objects):
        raise ValueError("unsupported rigid topology")
    meshes=[o for o in nodes.values() if o.type=="MESH"]
    saved={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in objects}
    ids={o.name:k for k,o in nodes.items()};tracks={ids[o.name]:{"location":[],"rotation_deg":[]} for o in objects}
    geom={};feet={};previous={}
    def update():bpy.context.view_layer.update()
    def low(o):return min((o.matrix_world@v.co).z for v in o.data.vertices)
    def flat(row):
        v=[*row[2],*row[3],row[4],*[x for pair in row[5] for x in pair]]
        if version in (22,25):v.extend(x for triple in row[6] for x in triple)
        if not all(math.isfinite(x) for x in v):raise ValueError("nonfinite pose key")
        return v
    t=[row[0] for row in keys];columns=list(zip(*(flat(row) for row in keys)))
    base=0.;rb=saved[root.name][0].copy()
    def apply(row,neutral_support=False):
        root.location=Vector((rb.x+row[0],rb.y+row[1],base+row[2]))
        root.rotation_euler=rotation(row[3:6]).to_euler("XYZ")
        head.rotation_euler=rotation((row[6],0,0)).to_euler("XYZ")
        for n,c in chains.items():
            hip,knee,foot=[nodes[u] for u in c];mesh=nodes[stance["sole_meshes"][n]]
            if hip.parent!=root or knee.parent!=hip or foot.parent!=knee or mesh.parent!=foot:raise ValueError("unsupported chain")
            if version in (22,25) and n in support_order and not neutral_support:
                j=13+9*support_order.index(n)
                for i,o in enumerate((hip,knee,foot)):
                    o.rotation_euler=rotation(row[j+3*i:j+3*i+3]).to_euler("XYZ")
                continue
            sign=-1 if n.endswith("_L") else 1;front=1 if n.startswith("Front") else -1
            angles=[row[7:9],row[9:11],row[11:13]] if n=="FrontFoot_L" else lib["neutral"]
            # Explicit link orientations relative to Body, NOT a target-point solve.
            a=knee.location.copy();b=foot.location.copy()
            q1=a.rotation_difference(direction(sign,front,*angles[0]))
            q2=b.rotation_difference(direction(sign,front,*angles[1]))
            q3=Vector((sign,0,0)).rotation_difference(direction(sign,front,*angles[2]))
            hip.rotation_euler=q1.to_euler("XYZ")
            knee.rotation_euler=(q1.inverted()@q2).to_euler("XYZ")
            foot.rotation_euler=(q2.inverted()@q3).to_euler("XYZ")
        update()
    try:
        apply(flat(keys[0]),neutral_support=True);base=-min(low(o) for o in meshes);apply(flat(keys[0]),neutral_support=whip)
        for n,c in chains.items():
            hip,knee,foot=[nodes[u] for u in c];mesh=nodes[stance["sole_meshes"][n]]
            verts=[mesh.matrix_world@v.co for v in mesh.data.vertices];z=min(v.z for v in verts)
            patch=[v for v in verts if v.z<z+.003]
            anchor=sum(patch,Vector((0,0,0)))/len(patch)
            local=foot.matrix_world.inverted()@anchor
            feet[n]=anchor
            geom[n]=(hip,knee,foot,foot.matrix_world.to_quaternion(),local,knee.location.copy(),foot.location.copy())
            d["markers"][n+"_Sole"]={"node":c[-1],"local":list(local)}
        whole=WholeChain(root,head,geom,meshes,whip_rows) if whip else None
        for f in range(1,end+1):
            apply([pchip(t,col,(f-1)/fps) for col in columns],neutral_support=whip)
            if whole:whole.apply(f)
            for uid,ch in tracks.items():
                o=nodes[uid];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",previous[uid]) if uid in previous else q.to_euler("XYZ")
                previous[uid]=e.copy()
                ch["location"].append({"frame":f,"value":list(o.location),"interpolation":"LINEAR"})
                ch["rotation_deg"].append({"frame":f,"value":[math.degrees(v) for v in e],"interpolation":"LINEAR"})
        if whole:whole.finish(out,variant,whip_revision)
    finally:
        for o in objects:o.location,o.rotation_euler=saved[o.name]
        update()
    d["tracks"]=tracks
    d["events"]={k[1]:1+round(k[0]*fps) for k in keys}
    if len(set(d["events"].values()))!=len(keys):raise ValueError("duplicate event frame")
    if spec.get("contact_policy")=="heavy_landing_v24":
        if version!=22:raise ValueError("V24 requires V22 whole-body poses")
        from heavy_landing import bake_heavy_landing
        bake_heavy_landing(d,nodes,end,out,geom)
    if spec.get("contact_policy")=="ground_drag_v25":
        if version!=25:raise ValueError("ground drag requires V25 attack library")
        from ground_drag import bake_ground_drag
        bake_ground_drag(d,nodes,end,out,geom)
    d["export_poses"]=[{"id":n,"frame":f} for n,f in d["events"].items()]
    d["pose_export_channels"]={uid:list(ch) for uid,ch in tracks.items()}
    d.setdefault("spatial",{}).setdefault("floor",{"z":0.,"tolerance_m":.002,"meshes":[uid for uid,o in nodes.items() if o.type=="MESH"]})
    # The three sibling legs receive optional runtime-style correction.
    # V23 additionally enables bounded strike IK; V24 bakes its deliberate
    # recovery into the authored strike chain instead.
    support=[n for n in ROLES if n!="FrontFoot_L"]
    phase={"support":support,"feet":feet,"foot_yaws":{n:0. for n in ROLES}}
    d["procedural_motion"]={"action":variant if version==25 else "stomp","max_contact_offset_m":.30,"preview_ik":bool(spec.get("preview_ik",False))}
    contact_policy=spec.get("contact_policy","support_only")
    if contact_policy in ("support_only","heavy_landing_v24","ground_drag_v25","whip_flick_v25","whip_flick_v25_r4"):
        phases,contact_frames=[phase,phase],[1,end]
    elif contact_policy=="post_impact_v23" and version==22:
        # Use the same V22 FK source, including all authored strike poses.
        # The runtime contact layer captures the actual visible strike
        # foot at impact, ramps in/out over up to four frames, and does
        # not touch the strike limb outside the explicit contact window.
        impact=d["events"]["impact"]; release=d["events"]["rebound"]
        if not 1<impact<release<end or release-impact<8:
            raise ValueError("invalid post-impact contact window")
        all_planted={**phase,"support":[*support,"FrontFoot_L"]}
        phases=[phase,all_planted,all_planted,phase]
        contact_frames=[1,impact,release,end]
    else:
        raise ValueError("unsupported FK contact policy")
    try:compile_contact_layer(d,nodes,end,out,phases,contact_frames,geom,5.539)
    finally:del d["procedural_motion"]
    (out/"fk_performance_report.json").write_text(json.dumps({"version":24 if contact_policy=="heavy_landing_v24" else version,"contact_policy":contact_policy,"variant":variant,"keys":keys,"source_animation_used":False,"neutral_root_z_m":base,"authored_tracks":tracks,"review_status":"review_required","scope":"explicit body-relative link directions, authored support-local rotation keys, and shape-preserving time curves; three support legs optional IK; no physical joint limits or collision approval"},indent=2,ensure_ascii=False))

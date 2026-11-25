"""Bounded multi-foot pose IK on rigid preview tracks, not runtime physics."""
import math
import numpy as np
from mathutils import Vector

def _dense(keys,end):
    if len(keys)==end: return [k["value"] for k in keys]
    if len(keys)==2 and keys[0]["value"]==keys[-1]["value"]: return [keys[0]["value"]]*end
    raise ValueError("IK requires dense or constant preview tracks")

def _smooth(x,radius):
    if not radius: return x.copy()
    w=np.array([radius+1-abs(i) for i in range(-radius,radius+1)],dtype=float)
    w/=w.sum()
    return np.convolve(np.pad(x,(radius,radius),mode="edge"),w,mode="valid")

def propose(nodes,d,end,base,spec):
    """Solve all configured feet as one stacked weighted pose task per frame."""
    import bpy
    stance=d["support_lock"]; names=[*stance["markers"],stance["strike_marker"]]
    if set(names)!=set(spec["chains"]) or "sole" not in base: raise ValueError("IK needs four explicit sole chains")
    meshes={n:nodes[stance["sole_meshes"][n]] for n in names}
    tracks=d["tracks"]; dense={uid:{p:_dense(k,end) for p,k in c.items()} for uid,c in tracks.items()}
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in tracks}
    axes=[];owned=set()
    for n in names:
        ancestor=meshes[n].parent; ancestors=set()
        while ancestor is not None: ancestors.add(ancestor.name);ancestor=ancestor.parent
        for uid in spec["chains"][n]:
            o=nodes[uid]
            if uid in owned or uid not in tracks or o.name not in ancestors or o.parent is None:
                raise ValueError("expected disjoint articulated foot chains")
            owned.add(uid)
            for axis in range(3): axes.append((uid,o,axis))
    cap=math.radians(float(spec.get("max_delta_deg",12.)))
    orient=float(spec.get("orientation_weight_m",.2))
    if not (0<cap<=math.pi/4 and 0<orient<=1): raise ValueError("invalid IK settings")
    fps=int(d["fps"]); rows=base["sole"]["frames"]; strike=stance["strike_marker"]
    # Raise the striking sole only where it goes below its own Wait level.
    lift=np.array([max(0.,-r["strike_low_delta_m"]) for r in rows])
    def update(): bpy.context.view_layer.update()
    def apply_frame(i):
        for uid,channels in dense.items():
            o=nodes[uid]
            o.location=channels["location"][i]
            o.rotation_euler=[math.radians(v) for v in channels["rotation_deg"][i]]
        update()
    points={};anchors={}; solutions=[]; diagnostics=[]
    try:
        apply_frame(0)
        for n,o in meshes.items():
            z=min((o.matrix_world@v.co).z for v in o.data.vertices)
            vs=[v.co.copy() for v in o.data.vertices if (o.matrix_world@v.co).z<=z+float(stance["sole_band_m"])]
            points[n]=sum(vs,Vector((0,0,0)))/len(vs)
            anchors[n]=np.array(o.matrix_world@points[n],dtype=float)
        def feature():
            values=[]
            for n,o in meshes.items():
                # Mesh-local sole point plus two normalized orientation axes.
                m=o.matrix_world.to_3x3()
                values.extend(o.matrix_world@points[n])
                values.extend(orient*m.col[0].normalized())
                values.extend(orient*m.col[1].normalized())
            return np.asarray(values,dtype=float)
        for i in range(end):
            apply_frame(i)
            fk=np.array([o.rotation_euler[k] for _,o,k in axes])
            start=feature(); goal=start.copy()
            # Preserve initial/final velocity samples; support correction is
            # released smoothly near the boundary rather than moving Wait.
            u=max(0.,min(1.,(i-1)/4.,(end-2-i)/4.)); ramp=u*u*(3-2*u)
            for j,n in enumerate(names):
                at=j*9
                if n==strike: goal[at+2]+=ramp*lift[i]
                else: goal[at:at+3]+=ramp*(anchors[n]-start[at:at+3])
            def apply(x):
                for (_,o,k),v,b in zip(axes,x,fk): o.rotation_euler[k]=float(b+v)
                update()
            x=np.zeros(len(axes));err=goal-start
            initial=float(np.linalg.norm(err))
            # All four position/orientation residuals are stacked. Damping and
            # a small posture penalty resolve redundant axes near singularities.
            if initial>1e-5:
                for _ in range(12):
                    y=feature(); err=goal-y
                    if np.linalg.norm(err)<.0002: break
                    jac=np.zeros((len(y),len(x))); h=1e-4
                    for k in range(len(x)):
                        t=x.copy(); t[k]=min(cap,x[k]+h)
                        if t[k]==x[k]: t[k]=max(-cap,x[k]-h)
                        apply(t);jac[:,k]=(feature()-y)/(t[k]-x[k])
                    apply(x)
                    step=np.linalg.solve(jac.T@jac+.003**2*np.eye(len(x)),jac.T@err-.003**2*x)
                    step=np.clip(step,-.08,.08)
                    loss=float(err@err+.003**2*(x@x)); accepted=False
                    for a in (1.,.5,.25,.125):
                        t=np.clip(x+a*step,-cap,cap);apply(t)
                        e=goal-feature()
                        if float(e@e+.003**2*(t@t))<loss-1e-12:
                            x=t;accepted=True;break
                    if not accepted: apply(x);break
            solutions.append(x.copy())
            diagnostics.append({"frame":i+1,"initial_pose_residual":initial,
                                "final_pose_residual":float(np.linalg.norm(goal-feature())),
                                "requested_strike_lift_m":float(ramp*lift[i])})
    finally:
        for uid,(p,q) in saved.items():
            nodes[uid].location=p;nodes[uid].rotation_euler=q
        update()
    corrections=np.asarray(solutions)
    if not np.isfinite(corrections).all(): raise ValueError("nonfinite multi-foot IK")
    candidates=[]
    for strength in (.5,1.):
        for radius in (0,2,4):
            delta=np.column_stack([_smooth(corrections[:,k],radius) for k in range(len(axes))])*strength
            delta[:2]=0.;delta[-2:]=0.
            # All candidate edits are local rotations; original location tracks
            # and source files remain untouched.
            track=dict(tracks)
            for uid in owned:
                ch=dict(tracks[uid]); v=np.array(dense[uid]["rotation_deg"],dtype=float)
                for k,(key,_,axis) in enumerate(axes):
                    if key==uid: v[:,axis]+=np.degrees(delta[:,k])
                keys=[{"frame":i+1,"value":[round(float(x),6) for x in v[i]],"interpolation":"LINEAR"} for i in range(end)]
                if np.max(np.abs(v-v[0]))<1e-6: keys=[keys[0],dict(keys[-1],value=keys[0]["value"])]
                ch["rotation_deg"]=keys;track[uid]=ch
            candidates.append((strength,radius,track,float(np.max(np.abs(np.degrees(delta))))))
    return candidates,diagnostics

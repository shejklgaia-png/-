"""Offline damped least-squares IK for rigid XYZ-Euler joints, with bounded axes."""
import math
import numpy as np
from mathutils import Vector

def bake_ik(scene,nodes,markers,specs,end,out, *, strategy="legacy", preview=False):
    import json
    if not specs: return set()
    owned=set(); plans=[]
    for s in specs:
        lo,hi=map(int,s["frames"])
        if not 1<=lo<=hi<=end: raise ValueError("IK interval")
        tip=markers[s["marker"]]
        ancestor=tip.parent; ancestry=set()
        while ancestor:
            ancestry.add(ancestor.name); ancestor=ancestor.parent
        axes=[]
        for j in s["joints"]:
            obj=nodes[j["node"]]
            if obj.name not in ancestry: raise ValueError("IK joint not an ancestor")
            if obj.name in owned: raise ValueError("V4 overlapping chains unsupported")
            owned.add(obj.name); obj.rotation_mode="XYZ"
            for axis,limits in j["limits_deg"].items():
                i="XYZ".index(axis)
                a,b=map(math.radians,limits)
                if not math.isfinite(a+b) or a>b: raise ValueError("invalid limits")
                axes.append((obj,i,a,b))
        if not axes: raise ValueError("empty IK axes")
        target=markers.get(s.get("target_marker"))
        if target is not None:
            a=target.parent
            while a:
                if a.name in {obj.name for obj,_,_,_ in axes}: raise ValueError("target depends on solved joint")
                a=a.parent
        elif "target" not in s: raise ValueError("unknown IK target")
        plans.append((s,lo,hi,tip,target,axes))
    baked={name:[] for name in owned}; reports=[]
    def update(): scene.view_layers[0].update()
    def point(obj): return np.array(obj.matrix_world.translation,dtype=float)
    history={}
    order=range(end,0,-1) if strategy.startswith("backward") else range(1,end+1)
    for f in order:
        scene.frame_set(f); update()
        original={name:tuple(o.rotation_euler) for name,o in ((o.name,o) for _,_,_,_,_,axes in plans for o,_,_,_ in axes)}
        for index,(s,lo,hi,tip,target,axes) in enumerate(plans):
            objects={o.name:o for o,_,_,_ in axes}
            if lo<=f<=hi:
                desired=point(target) if target else np.array(s["target"],dtype=float)
                start=point(tip)
                ramp=max(0,int(s.get("blend_frames",0)))
                w=min(1.,(f-lo+1)/(ramp+1),(hi-f+1)/(ramp+1)) if ramp else 1.
                w=w*w*(3-2*w)
                goal=start+(desired-start)*w
                fk=np.array([o.rotation_euler[i] for o,i,_,_ in axes])
                lower=np.array([a for _,_,a,_ in axes]); upper=np.array([b for _,_,_,b in axes])
                def apply(v):
                    for (o,i,_,_),val in zip(axes,v): o.rotation_euler[i]=float(val)
                    update()
                def solve(seed,objective):
                    x=np.clip(seed,lower,upper);apply(x)
                    for iteration in range(64):
                        pos=point(tip); err=objective-pos
                        if np.linalg.norm(err)<=0.0001: break
                        jac=np.zeros((3,len(x)))
                        for k in range(len(x)):
                            trial=x.copy()
                            h=1e-4 if x[k]+1e-4<=upper[k] else -1e-4
                            trial[k]=np.clip(x[k]+h,lower[k],upper[k])
                            if abs(trial[k]-x[k])<1e-10: continue
                            apply(trial);jac[:,k]=(point(tip)-pos)/(trial[k]-x[k])
                        apply(x)
                        step=jac.T @ np.linalg.solve(jac@jac.T+0.002**2*np.eye(3),err)
                        step=np.clip(step,-0.25,0.25)
                        improved=False
                        for alpha in (1.,.5,.25,.125):
                            trial=np.clip(x+step*alpha,lower,upper);apply(trial)
                            if np.linalg.norm(objective-point(tip))<np.linalg.norm(err)-1e-9:
                                x=trial;improved=True;break
                        if not improved:
                            apply(x);break
                    return x.copy(),float(np.linalg.norm(objective-point(tip)))
                apply(np.clip(fk,lower,upper))
                before=float(np.linalg.norm(goal-point(tip)))
                prior=history.get(index)
                angular=strategy.endswith("_joint")
                objective=desired if angular else goal
                if strategy=="legacy":
                    x,_=solve(fk,objective)
                    seed_name="fk"
                else:
                    seeds=[("fk",fk)]
                    if prior is not None: seeds.insert(0,("previous",prior))
                    # Deterministic restarts allow the solver to escape a straight-joint singularity.
                    if prior is None or not angular:
                        for k in range(len(fk)):
                            for sign in (-1,1):
                                alt=fk.copy();alt[k]+=sign*math.radians(20)
                                seeds.append((f"axis{k}_{sign}",alt))
                    trials=[]
                    ref=prior if prior is not None else fk
                    for label,seed in seeds:
                        q,err=solve(seed,objective)
                        trials.append((err,float(np.linalg.norm(q-ref)),label,q))
                    best=min(v[0] for v in trials)
                    _,_,seed_name,x=min((v for v in trials if v[0]<=best+.0001),key=lambda v:(v[1],v[0],v[2]))
                history[index]=x.copy()
                if angular:
                    x=np.clip(fk+(x-fk)*w,lower,upper)
                apply(x)
                after=float(np.linalg.norm(goal-point(tip)))
                reports.append({"frame":f,"marker":s["marker"],"weight":w,"initial_error_m":before,"residual_m":after,"target_error_m":float(np.linalg.norm(desired-point(tip))),"angles_deg":[math.degrees(v) for v in x],"seed":seed_name})
            for name,o in objects.items(): baked[name].append((f,tuple(o.rotation_euler)))
        # Restore FK before evaluating the next time, including unanimated axes.
        for _,_,_,_,_,axes in plans:
            for o,_,_,_ in axes: o.rotation_euler=original[o.name]
        update()
    for values in baked.values(): values.sort(key=lambda v:v[0])
    reports.sort(key=lambda r:(r["frame"],r["marker"]))
    if preview: return baked,reports
    return commit_ik(nodes,baked,reports,out,strategy)

def commit_ik(nodes,baked,reports,out,strategy):
    import json
    # Replace only rotation curves of solved nodes. Original design is retained.
    by_name={o.name:o for o in nodes.values()}
    for name,values in baked.items():
        o=by_name[name]
        if o.animation_data and o.animation_data.action:
            a=o.animation_data.action
            for layer in a.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(o.animation_data.action_slot)
                    if bag:
                        for fc in list(bag.fcurves):
                            if fc.data_path=="rotation_euler": bag.fcurves.remove(fc)
        for frame,rotation in values:
            o.rotation_euler=rotation;o.keyframe_insert(data_path="rotation_euler",frame=frame,group=name)
        for layer in o.animation_data.action.layers:
            for strip in layer.strips:
                bag=strip.channelbag(o.animation_data.action_slot)
                if bag:
                    for fc in bag.fcurves:
                        if fc.data_path=="rotation_euler":
                            for key in fc.keyframe_points: key.interpolation="LINEAR"
    (out/"ik_report.json").write_text(json.dumps({"method":"bounded damped least squares","strategy":strategy,"frames":reports,"max_full_weight_residual_m":max((r["residual_m"] for r in reports if r["weight"]>=.999),default=None),"scope":"independent rigid chains; no collision, shared-joint or orientation constraints"},indent=2))
    return {name for name,values in baked.items() if any(v!=values[0][1] for _,v in values[1:])}

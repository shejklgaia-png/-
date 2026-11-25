"""Opt-in V26 offline review adapter for the existing rigid quadruped FK rig.
No runtime or source animation writes. The detailed audit samples 60/120 Hz;
it is not continuous collision detection or a closed-volume containment test.
"""
import math,json,copy
import numpy as np
from mathutils import Vector,Euler,Quaternion
from mathutils.bvhtree import BVHTree
from runtime_contact import sample
from strike_clearance import StrikeClearance
from trajectory_refine import candidates,angular_metrics,choose

def refine_trajectory(d,nodes,end,out,geom):
    import bpy
    spec=d["fk_performance"];policy=spec.get("trajectory_refine")
    if not policy:return
    guard=bool(spec.get("subframe_guard",False))
    subdivisions=4 if guard else 2
    if policy not in ("heavy","medium","light"):raise ValueError("unknown trajectory profile")
    if d["fps"]!=60 or end<4 or end>601:raise ValueError("V26 requires 60 Hz")
    if spec.get("contact_policy") not in ("whip_flick_v25_r5","whip_flick_v25_r6"):
        raise ValueError("V26 currently calibrated for V25 revision 5/6")
    tracks=d["tracks"];source=copy.deepcopy(tracks);meshes=[m for m in nodes.values() if m.type=="MESH"]
    ids={o.name:uid for uid,o in nodes.items()}
    striker=d["support_lock"]["strike_marker"]
    strike=list(geom[striker][:3]);support=[o for n,g in geom.items() if n!=striker for o in g[:3]]
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in tracks}
    events=d["events"];locked=sorted(set([f-1 for f in events.values()]+list(range(events["settle"]-1,end))))
    lo=events["drive"]-1;hi=events["follow"]-1
    if not 0<=lo<hi<end:raise ValueError("attack event range")
    fidelity=np.ones(end);fidelity[lo:hi+1]={"heavy":5.,"medium":3.,"light":2.}[policy]
    broad=StrikeClearance(meshes,strike)
    pairs=[];local_verts={};triangles={}
    for m in meshes:
        m.data.calc_loop_triangles()
        local_verts[m]=[v.co.copy() for v in m.data.vertices]
        triangles[m]=[tuple(t.vertices) for t in m.data.loop_triangles]
    for i,a in enumerate(meshes):
        for b in meshes[i+1:]:
            if a.parent==b.parent:continue
            if a.parent and b.parent and (a.parent.parent==b.parent or b.parent.parent==a.parent):continue
            pairs.append((a,b))
    def update():bpy.context.view_layer.update()
    def pose(t,f):
        for uid,c in t.items():
            o=nodes[uid]
            o.location=sample(c["location"],f)
            o.rotation_euler=Euler([math.radians(v) for v in sample(c["rotation_deg"],f)],"XYZ")
        update()
    def array(t,objs):
        result=[]
        for f in range(1,end+1):
            row=[]
            for o in objs:
                q=Euler([math.radians(v) for v in t[ids[o.name]]["rotation_deg"][f-1]["value"]],"XYZ").to_quaternion()
                row.append((q.x,q.y,q.z,q.w))
            result.append(row)
        return np.array(result)
    def with_rot(t,objs,q):
        z=copy.deepcopy(t)
        for j,o in enumerate(objs):
            prev=None
            for i,r in enumerate(q[:,j]):
                Q=Quaternion((r[3],r[0],r[1],r[2]))
                e=Q.to_euler("XYZ",prev) if prev is not None else Q.to_euler("XYZ")
                prev=e.copy();z[ids[o.name]]["rotation_deg"][i]["value"]=[math.degrees(x) for x in e]
        return z
    def q_candidates(q,soft,weights):
        yield from candidates(q,locked,weights=weights,soft=soft)
        try:
            from scipy.spatial.transform import Rotation,RotationSpline
        except ImportError:
            return
        sample_idx=np.unique([*locked,*range(0,end,3)])
        qq=np.empty_like(q)
        for j in range(q.shape[1]):
            qq[:,j]=RotationSpline(sample_idx,Rotation.from_quat(q[sample_idx,j]))(np.arange(end)).as_quat()
        qq[locked]=q[locked]
        yield "rotation_spline",qq
    pose(source,1)
    anchors={}
    for n,(h,k,f,_,local,a,b) in geom.items():
        mesh=nodes[d["support_lock"]["sole_meshes"][n]]
        p=f.matrix_world@local
        p.z-=min((mesh.matrix_world@v.co).z for v in mesh.data.vertices)
        anchors[n]=(p,f.matrix_world.to_quaternion(),local)
    def reproject(t):
        # Exact two-link contact reconstruction with the smoothed knee plane.
        prev={}
        for f in range(1,end+1):
            pose(t,f)
            if f-1 not in locked:
                for n,(h,k,foot,_,local,a,b) in geom.items():
                    if n==striker:continue
                    target,q,_=anchors[n];H=h.matrix_world.translation.copy()
                    delta=target-q@local-H;dist=delta.length;l1=a.length;l2=b.length
                    if dist<1e-7:raise ValueError("degenerate support")
                    reach=max(abs(l1-l2)+1e-5,min(l1+l2-1e-5,dist))
                    u=delta.normalized();along=(l1*l1-l2*l2+reach*reach)/(2*reach)
                    pole=k.matrix_world.translation-H;pole-=u*pole.dot(u)
                    if pole.length<1e-7:raise ValueError("degenerate knee plane")
                    K=H+u*along+pole.normalized()*math.sqrt(max(0,l1*l1-along*along));A=H+u*reach
                    hr=h.matrix_world.to_quaternion();kr=k.matrix_world.to_quaternion()
                    qh=(hr@a).rotation_difference(K-H)@hr;qk=(kr@b).rotation_difference(A-K)@kr
                    h.rotation_euler=(h.parent.matrix_world.to_quaternion().inverted()@qh).to_euler("XYZ")
                    k.rotation_euler=(qh.inverted()@qk).to_euler("XYZ")
                    foot.rotation_euler=(qk.inverted()@q).to_euler("XYZ");update()
            for o in support:
                uid=ids[o.name];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",prev[uid]) if uid in prev else q.to_euler("XYZ")
                prev[uid]=e.copy();t[uid]["rotation_deg"][f-1]["value"]=[math.degrees(v) for v in e]
        return t
    def audit(t,objs):
        vertices=[];tips=[];floor=half_floor=slip=ob=0.;hits=0;hit_frames=0;hit_pairs=set()
        sub_slip=0.
        for j in range(subdivisions*(end-1)+1):
            pose(t,1+j/subdivisions)
            vs={m:[m.matrix_world@v for v in local_verts[m]] for m in meshes}
            low=max(0.,-min(v.z for vv in vs.values() for v in vv));half_floor=max(half_floor,low)
            sub_slip=max(sub_slip,max((g[2].matrix_world@anchors[n][2]-anchors[n][0]).length for n,g in geom.items() if n!=striker))
            if j%subdivisions==0:
                floor=max(floor,low)
                vertices.append([list(v) for m in meshes for v in vs[m]])
                foot=geom[striker][2];tips.append(list(foot.matrix_world@anchors[striker][2]))
                slip=max(slip,max((g[2].matrix_world@anchors[n][2]-anchors[n][0]).length for n,g in geom.items() if n!=striker))
                ob=max(ob,broad.measure()["nonadjacent_m"])
            bounds={m:([min(v[i] for v in vv) for i in range(3)],[max(v[i] for v in vv) for i in range(3)]) for m,vv in vs.items()}
            trees={};found=False
            for a,b in pairs:
                A,B=bounds[a],bounds[b]
                if any(A[1][i]<B[0][i]-1e-8 or B[1][i]<A[0][i]-1e-8 for i in range(3)):continue
                for m in (a,b):
                    if m not in trees:trees[m]=BVHTree.FromPolygons(vs[m],triangles[m],all_triangles=True,epsilon=0.)
                count=len(trees[a].overlap(trees[b]))
                if count:
                    hits+=count;found=True;hit_pairs.add(tuple(sorted((a.name,b.name))))
            hit_frames+=int(found)
        verts=np.array(vertices);tip=np.array(tips);vel=np.linalg.norm(np.diff(tip,axis=0),axis=1)*60
        m=angular_metrics(array(t,objs),60)
        m.update(floor=floor,subframe_floor=half_floor,support=slip,subframe_support=sub_slip,nonadj=ob,
                 surface_triangle_pairs=hits,intersecting_samples=hit_frames,
                 hit_pairs=[list(p) for p in sorted(hit_pairs)],
                 peak=float(vel[lo:hi].max()),path=float(np.linalg.norm(np.diff(tip[lo:hi+1],axis=0),axis=1).sum()),
                 end_delta=float(np.abs(verts[-1]-verts[0]).max()))
        return m,verts
    def stage(t,objs,kind):
        base,bv=audit(t,objs);records=[];best=None;best_name="baseline";best_score=float("inf")
        limit=.12 if kind=="strike" else .10
        q=array(t,objs)
        options=q_candidates(q,fidelity,(.15,.6,2.4)) if kind=="strike" else candidates(q,locked,weights=(.6,2.4,9.6))
        for label,qq in options:
            candidate=t if label=="baseline" else with_rot(t,objs,qq)
            if kind=="support" and label!="baseline":
                try:candidate=reproject(candidate)
                except ValueError as e:
                    records.append({"name":label,"eligible":False,"reason":str(e),"score":1e9});continue
            m,v=audit(candidate,objs);delta=float(np.linalg.norm(v-bv,axis=-1).max())
            gates={
                "floor":m["floor"]<=.002,
                "subframe_floor":m["subframe_floor"]<=max(.002,base["subframe_floor"]+.001),
                "support":m["support"]<=.005,
                "obb":m["nonadj"]<=min(.05,base["nonadj"]+.005),
                "surface":m["surface_triangle_pairs"]<=base["surface_triangle_pairs"] and set(map(tuple,m["hit_pairs"]))<=set(map(tuple,base["hit_pairs"])),
                "fidelity":delta<=limit,
                "speed":abs(m["peak"]-base["peak"])<=max(.001,.10*base["peak"]),
                "path":abs(m["path"]-base["path"])<=max(.001,.05*base["path"]),
                "endpoint":m["end_delta"]<=base["end_delta"]+.001
            }
            score=m["rms_jerk_rad_s3"]/max(base["rms_jerk_rad_s3"],1e-9)+.1*delta/limit
            eligible=all(gates.values())
            # Baseline is always a fallback, not a quality certificate.
            m.update(name=label,eligible=eligible,score=score,max_vertex_delta=delta,gates=gates)
            records.append(m)
            if label=="baseline" or (eligible and score<best_score):
                best=candidate;best_name=label;best_score=score
        return best,{"selected":best_name,"candidates":records}
    try:
        selected,strike_report=stage(source,strike,"strike")
        selected,support_report=stage(selected,support,"support")
        guard_report=None
        if guard:
            from trajectory_guard import repair_floor,minimum_path
            base,bv=audit(selected,strike)
            q=np.array([[np.radians(selected[ids[o.name]]["rotation_deg"][i]["value"]) for o in strike] for i in range(end)])
            attack_meshes=[m for m in meshes if m.parent in strike]
            if not attack_meshes:raise ValueError("missing striker meshes")
            def eval_floor(x,times):
                result=[]
                for t in times:
                    i=min(int(t),end-2);u=t-i
                    pose(selected,1+t)
                    for o,a in zip(strike,x[i]*(1-u)+x[i+1]*u):o.rotation_euler=Euler(a,"XYZ")
                    update()
                    result.append(min((m.matrix_world@v).z for m in attack_meshes for v in local_verts[m]))
                return result
            fixed,info=repair_floor(q,locked,eval_floor)
            trial=copy.deepcopy(selected)
            for j,o in enumerate(strike):
                for i,v in enumerate(fixed[:,j]):trial[ids[o.name]]["rotation_deg"][i]["value"]=np.degrees(v).tolist()
            m,v=audit(trial,strike);delta=float(np.linalg.norm(v-bv,axis=-1).max())
            def safe(before,after,delta):
                return (after["subframe_floor"]<=.002 and after["surface_triangle_pairs"]<=before["surface_triangle_pairs"] and set(map(tuple,after["hit_pairs"]))<=set(map(tuple,before["hit_pairs"])) and after["support"]<=.005 and after["subframe_support"]<=max(.005,before["subframe_support"]+.001) and after["nonadj"]<=min(.05,before["nonadj"]+.005) and delta<=.06 and abs(after["peak"]-before["peak"])<=max(.001,.10*before["peak"]) and abs(after["path"]-before["path"])<=max(.001,.05*before["path"]) and after["end_delta"]<=before["end_delta"]+.001)
            accepted=info["success"] and safe(base,m,delta) and m["rms_jerk_rad_s3"]<=base["rms_jerk_rad_s3"]*1.05
            if accepted:selected=trial
            guard_report={"floor_repair":info,"before":base,"candidate":m,"max_vertex_delta_m":delta,"accepted":accepted}
            # The second pass explores a small exact-contact bend-plane grid.
            from support_path import propose_support_path
            before,bv=audit(selected,support)
            trial,dp=propose_support_path(selected,geom,striker,anchors,locked,ids,pose,update,end)
            after,v=audit(trial,support);delta=float(np.linalg.norm(v-bv,axis=-1).max())
            ok=safe(before,after,delta) and after["subframe_support"]<before["subframe_support"]-.0001 and after["rms_jerk_rad_s3"]<=before["rms_jerk_rad_s3"]*1.05
            if ok:selected=trial
            guard_report["support_path"]={"states":dp,"before":before,"candidate":after,"max_vertex_delta_m":delta,"accepted":ok}
        (out/"trajectory_source_tracks.json").write_text(json.dumps(source,separators=(",",":")))
        (out/"trajectory_review.json").write_text(json.dumps({
            "version":27 if guard else 26,"profile":policy,"locked_frames":[x+1 for x in locked],
            "strike":strike_report,"support":support_report,"subframe_guard":guard_report,"audit_hz":60*subdivisions,
            "review_status":"visual_review_required",
            "scope":"sampled Euler track BVH triangle overlap, OBB and floor/contact; not containment, CCD, dynamics, runtime or artistic approval"
        },indent=2))
        d["tracks"]=selected
    finally:
        for uid,(pos,rot) in saved.items():nodes[uid].location=pos;nodes[uid].rotation_euler=rot
        update()

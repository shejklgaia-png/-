"""Optional V28 quaternion contact bake. Separate sidecar, not game output.
Retains all source integer-frame poses. Samples intermediate IK solutions
and selects the lowest rate meeting geometry/contact/fidelity gates.
"""
import math,json
import numpy as np
from mathutils import Vector,Euler,Quaternion
from mathutils.bvhtree import BVHTree
from chain_performance import knee_target,chain_descriptor,phase_plan

def bake_contact(d,nodes,end,out,geom,selected,pose,update,anchors,striker):
    meshes=[m for m in nodes.values() if m.type=="MESH"]
    ids={o.name:uid for uid,o in nodes.items()}
    objects=[nodes[uid] for uid in selected]
    index={o.name:i for i,o in enumerate(objects)}
    chain_descriptor({n:[ids[o.name] for o in g[:3]] for n,g in geom.items()})
    if d["fps"]!=60 or end>601:raise ValueError("V28 source range")
    saved=[(o.location.copy(),o.rotation_euler.copy(),o.rotation_mode) for o in objects]
    local={};tris={}
    for m in meshes:
        m.data.calc_loop_triangles()
        local[m]=[v.co.copy() for v in m.data.vertices]
        tris[m]=[tuple(t.vertices) for t in m.data.loop_triangles]
    pairs=[(a,b) for i,a in enumerate(meshes) for b in meshes[i+1:] if a.parent!=b.parent and not (a.parent and b.parent and (a.parent.parent==b.parent or b.parent.parent==a.parent))]
    def snapshot():
        return [o.location.copy() for o in objects],[o.rotation_euler.to_quaternion() for o in objects]
    def set_pose(p,q):
        for o,v,r in zip(objects,p,q):
            o.location=v;o.rotation_euler=r.to_euler("XYZ")
        update()
    def exact_support():
        for n,(h,k,f,_,contact,a,b) in geom.items():
            if n==striker:continue
            target,ori,_=anchors[n];H=h.matrix_world.translation.copy()
            A=target-ori@contact
            K=Vector(knee_target(H,A,k.matrix_world.translation,a.length,b.length))
            hr=h.matrix_world.to_quaternion();kr=k.matrix_world.to_quaternion()
            qh=(hr@a).rotation_difference(K-H)@hr
            qk=(kr@b).rotation_difference(A-K)@kr
            h.rotation_euler=(h.parent.matrix_world.to_quaternion().inverted()@qh).to_euler("XYZ")
            k.rotation_euler=(qh.inverted()@qk).to_euler("XYZ")
            f.rotation_euler=(qk.inverted()@ori).to_euler("XYZ")
            update()
    def build(rate):
        steps=rate//60;frames=[]
        for i in range((end-1)*steps+1):
            pose(selected,1+i/steps)
            if i%steps:exact_support()
            p,q=snapshot()
            if frames:
                for j,r in enumerate(q):
                    if frames[-1][1][j].dot(r)<0:r.negate()
            frames.append((p,q))
        return frames
    def inspect(frames=None,rate=60,reference=None):
        floor=slip=delta=key_delta=0.;hits=0;hit_pairs=set();vertices=[]
        steps=rate//60
        for j in range(8*(end-1)+1):
            t=j/8
            if frames is None:pose(selected,1+t)
            else:
                i=min(int(t*steps),len(frames)-2);u=t*steps-i
                p0,q0=frames[i];p1,q1=frames[i+1]
                set_pose([a.lerp(b,u) for a,b in zip(p0,p1)],[a.slerp(b,u) for a,b in zip(q0,q1)])
            vs={m:[m.matrix_world@v for v in local[m]] for m in meshes}
            v=np.array([list(p) for m in meshes for p in vs[m]])
            floor=max(floor,max(0.,-float(v[:,2].min())))
            slip=max(slip,max((g[2].matrix_world@anchors[n][2]-anchors[n][0]).length for n,g in geom.items() if n!=striker))
            if reference is None:vertices.append(v)
            else:
                diff=float(np.linalg.norm(v-reference[j],axis=1).max());delta=max(delta,diff)
                if j%8==0:key_delta=max(key_delta,diff)
            bounds={m:(np.min(vs[m],axis=0),np.max(vs[m],axis=0)) for m in meshes}
            trees={}
            for a,b in pairs:
                A,B=bounds[a],bounds[b]
                if np.any(A[1]<B[0]-1e-8) or np.any(B[1]<A[0]-1e-8):continue
                for m in (a,b):
                    if m not in trees:trees[m]=BVHTree.FromPolygons(vs[m],tris[m],all_triangles=True,epsilon=0.)
                count=len(trees[a].overlap(trees[b]))
                if count:
                    hits+=count;hit_pairs.add(tuple(sorted((a.name,b.name))))
        return {"floor_m":floor,"support_error_m":slip,"max_vertex_delta_m":delta,"source_key_delta_m":key_delta,
                "surface_triangle_pairs":hits,"hit_pairs":[list(p) for p in sorted(hit_pairs)],"audit_hz":480},vertices
    try:
        base,reference=inspect();records=[];winner=None
        for rate in (120,240,480):
            try:frames=build(rate)
            except ValueError as exc:
                records.append({"rate":rate,"eligible":False,"reason":str(exc)});continue
            m,_=inspect(frames,rate,reference)
            eligible=(m["floor_m"]<=.002 and m["support_error_m"]<=.005 and m["source_key_delta_m"]<=.00001 and
                      m["max_vertex_delta_m"]<=.06 and m["surface_triangle_pairs"]<=base["surface_triangle_pairs"] and
                      set(map(tuple,m["hit_pairs"]))<=set(map(tuple,base["hit_pairs"])))
            m.update(rate=rate,eligible=eligible,keys=len(frames));records.append(m)
            if winner is None and eligible:winner=(rate,frames)
        ev=d["events"];bounds=[0.,(ev["drive"]-1)/60,(ev["follow"]-1)/60,(ev["settle"]-1)/60,(end-1)/60]
        role_map={n:{"nodes":[ids[o.name] for o in g[:3]],"upper_length_m":g[5].length,"lower_length_m":g[6].length,"sole_local_m":list(g[4])} for n,g in geom.items()}
        # The model span is geometry-derived from the initial frame.
        pose(selected,1)
        verts=[m.matrix_world@v for m in meshes for v in local[m]]
        span=max(v.x for v in verts)-min(v.x for v in verts)
        profiles=[phase_plan(bounds,["anticipation","release","follow","recovery"],p,span) for p in ("light","medium","heavy")]
        report={"version":28,"baseline":base,"candidates":records,"selected_rate":winner[0] if winner else None,
                "roles":role_map,"weight_plans":profiles,"status":"review_required" if winner else "no_candidate",
                "scope":"480Hz sampled source-Euler and candidate quaternion surface/floor/contact comparison; not continuous collision, containment, physical limits, or game validation"}
        if winner:
            rate,frames=winner
            channels={}
            for j,o in enumerate(objects):
                channels[ids[o.name]]={"location_m":[list(p[j]) for p,q in frames],"rotation_xyzw":[[q[j].x,q[j].y,q[j].z,q[j].w] for p,q in frames]}
            packet={"format":"SERA_MOTION_CONTACT_BAKE_V28","coordinates":"Blender_Z_up_local","interpolation":"linear_translation_shortest_slerp","fps":rate,
                    "source_fps":60,"source_end_frame":end,"duration_s":(end-1)/60,"events_s":{n:(f-1)/60 for n,f in ev.items()},"channels":channels,"review_status":"not_game_approved"}
            (out/"contact_bake_v28.json").write_text(json.dumps(packet,separators=(",",":")))
        (out/"contact_bake_review_v28.json").write_text(json.dumps(report,indent=2))
    finally:
        for o,(p,r,mode) in zip(objects,saved):o.rotation_mode=mode;o.location=p;o.rotation_euler=r
        update()

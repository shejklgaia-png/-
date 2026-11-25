"""V25 revision 2: flat-sole ground-drag attack authoring.
The source FK body and support chains remain unchanged. Only the strike
chain is baked onto an explicit polar ground trajectory; never runtime-lock
a sliding attack as if it were a planted support foot.
"""
import json,math
from mathutils import Vector,Euler,Quaternion
from runtime_contact import sample
from fk_performance import pchip

# Frame numbers below are zero-based samples. Radius is hip-relative in metres.
# None radius/bearing means the geometry-derived neutral pose.
PATHS={
    "sweep":[(0,None,None,0),(8,None,None,0),(21,2.16,-27,.045),
        (32,2.22,-35,.001),(39,2.23,-22,.001),(46,2.25,54,.001),
        (54,2.22,108,.001),(64,2.06,108,.001),(75,1.96,55,.075),
        (88,None,None,0),(99,None,None,0)],
    "kick":[(0,None,None,0),(9,None,None,0),(21,.87,58,.075),
        (34,.65,69,.04),(41,.70,69,.001),(44,1.2,72,.001),
        (47,2.20,75,.001),(53,2.22,79,.001),(62,1.98,68,.001),
        (76,1.79,38,.075),(94,None,None,0),(108,None,None,0)]
}
def bake_ground_drag(d,nodes,end,out,geom):
    import bpy
    variant=d["fk_performance"]["variant"]
    rows=PATHS[variant]
    if rows[-1][0]!=end-1 or d["fps"]!=60:
        raise ValueError("ground attack sample range mismatch")
    n=d["support_lock"]["strike_marker"]
    hip,knee,foot,_,local,a,b=geom[n]
    mesh=nodes[d["support_lock"]["sole_meshes"][n]]
    tracks=d["tracks"]
    ids={o.name:uid for uid,o in nodes.items()}
    source={uid:{prop:[dict(k) for k in keys] for prop,keys in ch.items()} for uid,ch in tracks.items()}
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in tracks}
    def update():bpy.context.view_layer.update()
    def pose(f):
        for uid,ch in source.items():
            o=nodes[uid]
            o.location=sample(ch["location"],f)
            o.rotation_euler=Euler([math.radians(x) for x in sample(ch["rotation_deg"],f)],"XYZ")
        update()
    report=[];prev={}
    try:
        pose(1)
        world=[mesh.matrix_world@v.co for v in mesh.data.vertices]
        floor=min(v.z for v in world)
        patch=[i for i,v in enumerate(world) if v.z<floor+.003]
        if len(patch)<3:raise ValueError("insufficient sole plane vertices")
        vs=[foot.matrix_world.inverted()@v for v in world]
        home=foot.matrix_world@local;home.z-=floor
        h0=hip.matrix_world.translation.copy()
        hq0=hip.matrix_world.to_quaternion();kq0=knee.matrix_world.to_quaternion()
        fq0=foot.matrix_world.to_quaternion()
        offset=home-h0
        radius0=math.hypot(offset.x,offset.y)
        theta0=math.degrees(math.atan2(offset.y,-offset.x))
        v0=(home-fq0@local-h0).normalized()
        pole0=knee.matrix_world.translation-h0
        pole0=(pole0-v0*pole0.dot(v0)).normalized()
        if pole0.length<.99:raise ValueError("invalid neutral knee plane")
        p=[(r[0],radius0 if r[1] is None else r[1],theta0 if r[2] is None else r[2],r[3]) for r in rows]
        times=[r[0] for r in p];cols=list(zip(*(r[1:] for r in p)))
        l1,l2=a.length,b.length
        for f in range(1,end+1):
            pose(f)
            radius,theta,height=[pchip(times,c,f-1) for c in cols]
            yaw=Quaternion((0,0,1),math.radians(-(theta-theta0)))
            desired=yaw@fq0
            h=hip.matrix_world.translation.copy()
            target=h+Vector((-radius*math.cos(math.radians(theta)),radius*math.sin(math.radians(theta)),0))
            target.z=height-min((desired@(v-local)).z for v in vs)
            ankle=target-desired@local;delta=ankle-h
            dist=delta.length
            reach=max(abs(l1-l2)+.015,min(l1+l2-.015,dist))
            # Preserve whole-sole height even at the reach boundary.
            if abs(reach-dist)>1e-10:
                radial=math.hypot(delta.x,delta.y)
                available=reach*reach-delta.z*delta.z
                if radial<1e-8 or available<0:raise ValueError("unreachable ground attack height")
                factor=math.sqrt(available)/radial
                delta.x*=factor;delta.y*=factor
                ankle=h+delta;target=ankle+desired@local;dist=delta.length
            u=delta.normalized()
            along=(l1*l1-l2*l2+dist*dist)/(2*dist)
            pole=yaw@pole0;pole-=u*pole.dot(u)
            if pole.length<1e-8:raise ValueError("ground attack knee plane singular")
            kp=h+u*along+pole.normalized()*math.sqrt(max(0,l1*l1-along*along))
            hr=yaw@hq0;kr=yaw@kq0
            qh=(hr@a).rotation_difference(kp-h)@hr
            qk=(kr@b).rotation_difference(ankle-kp)@kr
            hip.rotation_euler=(hip.parent.matrix_world.to_quaternion().inverted()@qh).to_euler("XYZ")
            knee.rotation_euler=(qh.inverted()@qk).to_euler("XYZ")
            foot.rotation_euler=(qk.inverted()@desired).to_euler("XYZ")
            update()
            points=[mesh.matrix_world@v.co for v in mesh.data.vertices]
            sole=[points[i].z for i in patch]
            actual=foot.matrix_world@local
            residual=(actual-target).length
            if residual>.002 or min(v.z for v in points)<-.002:raise ValueError("ground attack contact residual")
            for o in (hip,knee,foot):
                uid=ids[o.name];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",prev[uid]) if uid in prev else q.to_euler("XYZ")
                prev[uid]=e.copy()
                tracks[uid]["rotation_deg"][f-1]["value"]=[math.degrees(x) for x in e]
            report.append({"frame":f,"sole_min_m":min(sole),"sole_max_m":max(sole),
                "sole_center_m":list(actual),"target_residual_m":residual,
                "radius_clamp_m":abs(radius-math.hypot(actual.x-h.x,actual.y-h.y))})
        lo=d["events"]["apex" if variant=="sweep" else "drive"]
        hi=d["events"]["follow"]
        active=report[lo-1:hi]
        if min(r["sole_min_m"] for r in active)<-.002 or max(r["sole_max_m"] for r in active)>.003:
            raise ValueError("active attack whole sole not on ground")
        settled=report[d["events"]["settle"]-1:]
        p0=Vector(settled[0]["sole_center_m"])
        drift=max((Vector(r["sole_center_m"])-p0).length for r in settled)
        if drift>.002 or max(abs(r["sole_max_m"]) for r in settled)>.003:
            raise ValueError("terminal attack contact not stable")
        travel=sum((Vector(b["sole_center_m"])-Vector(a["sole_center_m"])).length for a,b in zip(active,active[1:]))
        (out/"ground_drag_report.json").write_text(json.dumps({
            "version":25,"revision":2,"variant":variant,"active_frames":[lo,hi],
            "active_sole_min_m":min(r["sole_min_m"] for r in active),
            "active_sole_max_m":max(r["sole_max_m"] for r in active),
            "active_travel_m":travel,"terminal_drift_m":drift,
            "scope":"flat reference floor, baked strike chain; not terrain physics or hit validation",
            "frames":report},indent=2))
    finally:
        for uid,(pos,rot) in saved.items():nodes[uid].location=pos;nodes[uid].rotation_euler=rot
        update()

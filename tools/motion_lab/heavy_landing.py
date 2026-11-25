"""V24 heavy landing: author a pinned impact and a deliberate low return.
Only the strike chain is rebaked after impact. Body/head/support FK remains
untouched. Runtime IK remains a separate, optional support correction.
"""
import json,math
from mathutils import Vector,Euler
from runtime_contact import sample

def quint(u):return u**3*(10-15*u+6*u*u)

def bake_heavy_landing(d,nodes,end,out,geom):
    import bpy
    spec=d["fk_performance"]
    clearance=float(spec.get("return_clearance_m",.075))
    if not math.isfinite(clearance) or not .02<=clearance<=.10:
        raise ValueError("heavy return clearance must be within 2..10 cm")
    start=d["events"]["impact"]
    release=d["events"]["return_swing"]
    land=d["events"]["settle_contact"]
    if not 1<start<release<land<end or release-start<8 or land-release<8:
        raise ValueError("invalid heavy landing phases")
    n=d["support_lock"]["strike_marker"]
    hip,knee,foot,_,local,a,b=geom[n]
    mesh=nodes[d["support_lock"]["sole_meshes"][n]]
    ids={o.name:uid for uid,o in nodes.items()}
    track=d["tracks"]
    source={uid:{prop:[dict(k) for k in keys] for prop,keys in channels.items()} for uid,channels in track.items()}
    saved={uid:(nodes[uid].location.copy(),nodes[uid].rotation_euler.copy()) for uid in track}
    prev={}
    rows=[]
    def update():bpy.context.view_layer.update()
    def pose(f):
        for uid,ch in source.items():
            o=nodes[uid]
            o.location=sample(ch["location"],f)
            o.rotation_euler=Euler([math.radians(x) for x in sample(ch["rotation_deg"],f)],"XYZ")
        update()
    def low():return min((mesh.matrix_world@v.co).z for v in mesh.data.vertices)
    def capture(f):
        pose(f)
        p=foot.matrix_world@local;p.z-=low()
        return p,foot.matrix_world.to_quaternion()
    def set_world(o,q):
        o.rotation_euler=(o.parent.matrix_world.to_quaternion().inverted()@q).to_euler("XYZ",o.rotation_euler)
        update()
    def solve(goal,q):
        h=hip.matrix_world.translation.copy()
        k=knee.matrix_world.translation.copy()
        delta=goal-q@local-h
        dist=delta.length;l1=a.length;l2=b.length
        if min(dist,l1,l2)<1e-5:raise ValueError("degenerate strike chain")
        direction=delta.normalized()
        reach=max(abs(l1-l2)+1e-5,min(l1+l2-1e-5,dist))
        along=(l1*l1-l2*l2+reach*reach)/(2*reach)
        pole=k-h;pole-=direction*pole.dot(direction)
        if pole.length<1e-5:
            pole=Vector((0,0,1));pole-=direction*pole.dot(direction)
        if pole.length<1e-5:raise ValueError("degenerate strike knee plane")
        bend=math.sqrt(max(0.,l1*l1-along*along))
        hk=h+direction*along+pole.normalized()*bend
        hr=hip.matrix_world.to_quaternion()
        set_world(hip,(hr@a).rotation_difference(hk-h)@hr)
        kr=knee.matrix_world.to_quaternion()
        kp=knee.matrix_world.translation.copy()
        set_world(knee,(kr@b).rotation_difference(h+direction*reach-kp)@kr)
        set_world(foot,q)
        return (foot.matrix_world@local-goal).length
    try:
        anchor,orientation=capture(start)
        home,home_q=capture(end)
        # Mesh vertices expressed in the rigid foot frame. The contact
        # height is based on the actual lowest vertex, not the joint pivot.
        inv=foot.matrix_world.inverted()
        vertices=[inv@(mesh.matrix_world@v.co) for v in mesh.data.vertices]
        for f in range(1,end+1):
            pose(f)
            if f>=start:
                if f<=release:
                    goal=anchor.copy();desired=orientation;lift=0.
                    phase="impact_hold"
                elif f<land:
                    u=(f-release)/(land-release);s=quint(u)
                    goal=anchor.lerp(home,s);desired=orientation.slerp(home_q,s)
                    lift=clearance*64*u**3*(1-u)**3;phase="deliberate_return"
                else:
                    goal=home.copy();desired=home_q;lift=0.;phase="settled"
                goal.z=lift-min((desired@(v-local)).z for v in vertices)
                change=(goal-foot.matrix_world@local).length
                error=solve(goal,desired)
                if error>.005:raise ValueError(f"heavy landing unreachable: frame {f}: {error:.6f}m")
                point=foot.matrix_world@local
                rows.append({"frame":f,"phase":phase,"target_m":list(goal),
                             "actual_m":list(point),"lowest_mesh_z_m":low(),
                             "solver_residual_m":error,"authored_change_m":change})
            for o in (hip,knee,foot):
                uid=ids[o.name];q=o.rotation_euler.to_quaternion()
                e=q.to_euler("XYZ",prev[uid]) if uid in prev else q.to_euler("XYZ")
                prev[uid]=e.copy()
                if f>=start:
                    # FK source tracks are dense. No extra translation keys.
                    track[uid]["rotation_deg"][f-1]["value"]=[math.degrees(x) for x in e]
    finally:
        for uid,(pos,rot) in saved.items():
            nodes[uid].location=pos;nodes[uid].rotation_euler=rot
        update()
    hold=[r for r in rows if r["phase"]=="impact_hold"]
    movement=[r for r in rows if r["phase"]=="deliberate_return"]
    drift=max(math.hypot(r["actual_m"][0]-hold[0]["actual_m"][0],
                         r["actual_m"][1]-hold[0]["actual_m"][1]) for r in hold)
    height=max(abs(r["lowest_mesh_z_m"]) for r in hold)
    if drift>.005 or height>.005:raise ValueError("heavy landing contact invariant violated")
    (out/"heavy_landing_report.json").write_text(json.dumps({
        "version":24,"impact_frame":start,"return_start_frame":release,
        "settle_frame":land,"hold_seconds":(release-start)/d["fps"],
        "hold_max_horizontal_drift_m":drift,"hold_max_abs_height_m":height,
        "return_max_height_m":max(r["lowest_mesh_z_m"] for r in movement),
        "max_solver_residual_m":max(r["solver_residual_m"] for r in rows),
        "max_authored_change_m":max(r["authored_change_m"] for r in rows),
        "scope":"baked strike-only post-impact trajectory; not runtime physics",
        "frames":rows},indent=2))

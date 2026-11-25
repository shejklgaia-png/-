"""V25 revision 3: direct whole-chain ground-level FK overlap and crouch.
The attack links are posed independently in world-space directions and
converted into local FK rotations. Supporting legs are authored with
floor-aware bend-plane selection; no strike contact lock at runtime.
"""
import math,json
from mathutils import Vector,Quaternion
from fk_performance import C,pchip

# zero-based frame, event, body offset x/forward/up, pitch/yaw/roll,
# head pitch, laydown weight, upper/lower/tip bearings and elevations.
SWEEP=[
(0,"ready",0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10,"load",.10,-.02,-.38,5,8,-9,-4,.20,-24,-40,-50,-3,-7,-4),
(23,"windup",.24,-.06,-.88,8,17,-18,-9,.85,-36,-53,-58,-2,-4,-2),
(33,"apex",.20,-.01,-1.05,5,21,-21,-9,1,-30,-49,-62,-2,-3,-2),
(39,"drive",.14,.03,-1.06,2,10,-22,-4,1,12,-29,-52,-3,-2,-1),
(45,"strike",.08,.06,-1.03,-2,-9,-20,4,1,53,26,-8,-2,-2,-1),
(51,"whip_tip",.02,.10,-1.03,-4,-20,-17,7,1,91,71,43,-2,-2,0),
(57,"follow",.02,.10,-1.02,-5,-23,-15,9,1,97,111,112,-1,-1,0),
(65,"brake",.08,.07,-.95,-3,-16,-12,5,1,95,101,109,-1,0,0),
(76,"return_swing",.10,.03,-.52,0,-6,-6,0,.55,35,43,55,5,6,8),
(92,"settle",0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(108,"recovered",0,0,0,0,0,0,0,0,0,0,0,0,0,0)]
KICK=[
(0,"ready",0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10,"load",.12,-.03,-.40,6,-4,-8,-3,.25,30,100,50,3,-15,-8),
(23,"chamber",.20,-.09,-.89,8,-7,-16,-7,.9,20,155,-5,-3,-2,0),
(34,"apex",.20,-.11,-1.01,8,-8,-18,-8,1,22,157,-12,-3,-2,0),
(42,"drive",.16,-.07,-1.02,5,-3,-17,-6,1,36,152,-7,-3,-2,0),
(46,"strike",.06,.05,-1.03,-4,6,-14,5,1,74,77,80,-2,-1,0),
(50,"extension",.02,.12,-1.02,-6,9,-13,9,1,77,78,79,-1,-1,0),
(63,"follow",.02,.12,-1.02,-6,9,-13,7,1,77,78,79,-1,-1,0),
(72,"brake",.07,.08,-.9,-3,5,-10,3,1,73,75,77,-1,-1,0),
(85,"return_swing",.08,.02,-.45,0,0,-5,-1,.5,34,65,42,5,8,9),
(101,"settle",0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(116,"recovered",0,0,0,0,0,0,0,0,0,0,0,0,0,0)]

def rows_for(variant,revision=3):
    if revision==4 and variant=="sweep_reverse":
        # Reflect world bearings about 25 degrees; do not reverse time.
        # Proximal drive and distal lag are preserved, body yaw is reversed.
        rows=[(*r[:6],-r[6],r[7],r[8],r[9],*(50-v for v in r[10:13]),*r[13:]) for r in SWEEP]
    elif revision==4 and variant=="kick":
        # Equal bearings during chamber: curl in a vertical plane, not
        # a horizontal folded sweep. Open successive links over 12 frames.
        changes={
            10:(58,58,58,25,-75,100),
            23:(64,64,64,59,-135,150),
            34:(68,68,68,65,-137,155),
            42:(71,71,71,32,-86,105),
            46:(74,77,80,4,-22,34),
            50:(77,78,79,-1,-1,0),
            63:(77,78,79,-1,-1,0),
            72:(73,75,77,-1,-1,0),
            85:(44,44,44,15,-58,25)}
        rows=[(*r[:10],*changes.get(r[0],r[10:])) for r in KICK]
        rows.insert(4,(38,"release",.18,-.09,-1.02,6,-5,-17,-7,1,69,69,69,62,-128,150))
    else:
        rows={"sweep":SWEEP,"kick":KICK}[variant]
    # Lean toward the strike hip and lower the root, then apply geometry guard.
    return [(*r[:4],r[4]*1.16,-abs(r[5])*1.25,r[6],-r[7]*1.1,*r[8:]) for r in rows]

def source_keys(rows,neutral,support):
    return [[r[0]/60,r[1],list(r[2:5]),list(r[5:8]),r[8],neutral,support] for r in rows]

class WholeChain:
    def __init__(self,root,head,geom,meshes,rows):
        import bpy
        self.update=bpy.context.view_layer.update
        self.root=root;self.geom=geom;self.rows=rows
        self.meshes=meshes
        self.h,self.k,self.f,*_=geom["FrontFoot_L"]
        self.strike=(self.h,self.k,self.f)
        self.parts={o:[m for m in meshes if m.parent==o] for o in [root,head,*[o for g in geom.values() for o in g[:3]]]}
        self.vertices={o:[o.matrix_world.inverted()@(m.matrix_world@v.co) for m in ms for v in m.data.vertices] for o,ms in self.parts.items()}
        self.check_meshes=[m for o in (root,head,*self.strike) for m in self.parts[o]]
        self.neutral={o:o.rotation_euler.to_quaternion() for o in self.strike}
        self.anchors={}
        for n,(h,k,f,q,local,a,b) in geom.items():
            p=f.matrix_world@local
            sole=min((m.matrix_world@v.co).z for m in self.parts[f] for v in m.data.vertices)
            p.z-=sole
            self.anchors[n]=(p,q,local)
        self.times=[r[0] for r in rows]
        self.columns=list(zip(*(r[2:] for r in rows)))
        self.report=[]

    def low(self,objects):
        return min((m.matrix_world@v.co).z for m in objects for v in m.data.vertices)

    def world_rotation(self,bearing,elevation,axis):
        yaw=Quaternion((0,0,1),math.radians(-bearing))
        e=math.radians(elevation)
        direction=yaw@(C@Vector((-math.cos(e),math.sin(e),0)))
        return (yaw@axis).rotation_difference(direction)@yaw

    def support(self,n):
        h,k,f,_,local,a,b=self.geom[n]
        target,desired,_=self.anchors[n]
        H=h.matrix_world.translation.copy()
        v=target-desired@local-H
        dist=v.length;l1=a.length;l2=b.length
        if min(dist,l1,l2)<1e-6:raise ValueError("degenerate crouch support")
        reach=max(abs(l1-l2)+1e-5,min(l1+l2-1e-5,dist))
        u=v.normalized();A=H+u*reach
        along=(l1*l1-l2*l2+reach*reach)/(2*reach)
        bend=math.sqrt(max(0,l1*l1-along*along))
        pole=Vector((0,0,1));pole-=u*pole.dot(u)
        if pole.length<1e-6:raise ValueError("singular support bend plane")
        pole.normalize();cross=u.cross(pole)
        hr=h.matrix_world.to_quaternion();kr=k.matrix_world.to_quaternion()
        best=None
        for deg in range(-180,180,10):
            t=math.radians(deg)
            K=H+u*along+bend*(pole*math.cos(t)+cross*math.sin(t))
            qh=(hr@a).rotation_difference(K-H)@hr
            qk=(kr@b).rotation_difference(A-K)@kr
            z=min(min((qh@p+H).z for p in self.vertices[h]),
                  min((qk@p+K).z for p in self.vertices[k]))
            score=100*max(0,-z)+abs(t)*.04+max(0,.05-z)*.1
            if best is None or score<best[0]:best=(score,qh,qk)
        _,qh,qk=best
        h.rotation_euler=(h.parent.matrix_world.to_quaternion().inverted()@qh).to_euler("XYZ")
        k.rotation_euler=(qh.inverted()@qk).to_euler("XYZ")
        f.rotation_euler=(qk.inverted()@desired).to_euler("XYZ")
        self.update()
        return (f.matrix_world@local-target).length

    def apply(self,frame):
        # Input root/head/neutral chains have already been authored by compile_fk.
        row=[pchip(self.times,c,frame-1) for c in self.columns]
        blend=row[7];axes=(self.k.location.copy(),self.f.location.copy(),Vector((-1,0,0)))
        parent=self.root.matrix_world.to_quaternion()
        for i,o in enumerate(self.strike):
            world=self.world_rotation(row[8+i],row[11+i],axes[i])
            q=self.neutral[o].slerp(parent.inverted()@world,blend)
            o.rotation_euler=q.to_euler("XYZ")
            parent=parent@q
        self.update()
        low=self.low(self.check_meshes)
        if low<.008 and blend>1e-6:
            self.root.location.z+=.008-low
            self.update()
        errors=[self.support(n) for n in ("FrontFoot_R","RearFoot_L","RearFoot_R")]
        floor=self.low(self.meshes)
        if max(errors)>.005 or floor<-.005:
            raise ValueError(f"whole-chain crouch contact failure at frame {frame}: {floor}, {max(errors)}")
        self.report.append({"frame":frame,"root_z_m":self.root.location.z,
            "strike_link_min_z_m":[self.low(self.parts[o]) for o in self.strike],
            "floor_m":floor,"max_support_error_m":max(errors)})

    def finish(self,out,variant,revision=3):
        (out/"whip_flick_report.json").write_text(json.dumps({
            "version":25,"revision":revision,"variant":variant,"frames":self.report,
            "scope":"rigid link FK overlap and offline support pose selection; flat floor only; collision and runtime not certified"
        },indent=2))

"""Small bend-plane grid with exact support target and temporal transition costs."""
import copy,math
import numpy as np
from mathutils import Vector,Euler,Quaternion
from trajectory_guard import minimum_path

def propose_support_path(source,geom,striker,anchors,locked,ids,pose,update,end):
    out=copy.deepcopy(source);records=[]
    angles=np.array([0.,-1.,1.,-2.,2.]);count=len(angles)
    for n,(h,k,foot,_,local,a,b) in geom.items():
        if n==striker:continue
        goal,ori,_=anchors[n];A=goal-ori@local
        objects=(h,k,foot);uids=[ids[o.name] for o in objects]
        states=np.empty((end,count,3,3));knees=np.empty((end,count,3))
        unary=np.tile(.08*(angles/2)**2,(end,1))
        unary[list(locked),1:]=np.inf
        for i in range(end):
            pose(out,i+1)
            ref=[o.rotation_euler.copy() for o in objects]
            states[i]=np.array([list(e) for e in ref])[None]
            knees[i]=list(k.matrix_world.translation)
            if i in locked:continue
            H=h.matrix_world.translation.copy();delta=A-H;dist=delta.length;l1=a.length;l2=b.length
            if not abs(l1-l2)+1e-5<dist<l1+l2-1e-5:
                unary[i,1:]=np.inf;continue
            u=delta.normalized();along=(l1*l1-l2*l2+dist*dist)/(2*dist)
            pole=k.matrix_world.translation-H;pole-=u*pole.dot(u)
            if pole.length<1e-7:
                unary[i,1:]=np.inf;continue
            pole.normalize();bend=math.sqrt(max(0,l1*l1-along*along))
            hr=h.matrix_world.to_quaternion();kr=k.matrix_world.to_quaternion();pr=h.parent.matrix_world.to_quaternion()
            for j,deg in enumerate(angles[1:],1):
                K=H+u*along+(Quaternion(u,math.radians(deg))@pole)*bend
                qh=(hr@a).rotation_difference(K-H)@hr
                qk=(kr@b).rotation_difference(A-K)@kr
                qs=(pr.inverted()@qh,qh.inverted()@qk,qk.inverted()@ori)
                states[i,j]=[list(q.to_euler("XYZ",e)) for q,e in zip(qs,ref)]
                knees[i,j]=list(K)
        edges=[]
        for i in range(1,end):
            pose(out,i+.5)
            H=h.matrix_world.translation.copy();pr=h.parent.matrix_world.to_quaternion()
            edge=np.empty((count,count))
            for j in range(count):
                for l in range(count):
                    r=[Euler(v,"XYZ").to_quaternion() for v in (states[i-1,j]+states[i,l])*.5]
                    qh=pr@r[0];K=H+qh@a;qk=qh@r[1];F=K+qk@b;qf=qk@r[2]
                    error=(F+qf@local-goal).length
                    motion=np.linalg.norm(knees[i,l]-knees[i-1,j])
                    edge[j,l]=(error/.003)**2+(motion/.03)**2+2*((angles[j]-angles[l])/2)**2
            edges.append(edge)
        path=minimum_path(unary,lambda i:edges[i-1])
        for i,j in enumerate(path):
            if i in locked or j==0:continue
            for uid,v in zip(uids,states[i,j]):out[uid]["rotation_deg"][i]["value"]=np.degrees(v).tolist()
        records.append({"role":n,"offset_deg":angles[path].tolist(),"changed_frames":int(np.count_nonzero(path))})
    return out,records

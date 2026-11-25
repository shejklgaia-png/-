"""V31 contact-scheduled biped authoring, Y-up metres. Not physics."""
import json, math
import numpy as np
from scipy.spatial.transform import Rotation as R,Slerp
from gait_v30 import parse_bb,discover,align

def ease(t):
    u=np.clip(t,0,1);return u**3*(10-15*u+6*u*u)
def yaw(a):return R.from_euler('y',a).as_matrix()

def generate(model,action,gain=1.):
    names,parent,piv,parts=model;root,roles=discover(*model)
    if set(roles)!={'L','R'}:raise ValueError('biped only')
    if action not in ('walk','step','turn_left','turn_right') or not .2<=gain<=1:raise ValueError('action/gain')
    g=len(names);off=piv.copy()
    for j,p in enumerate(parent):
        if p>=0:off[j]-=piv[p]
    length=np.mean([np.linalg.norm(off[k])+np.linalg.norm(off[f]) for h,k,f in roles.values()]);sole={};home={}
    for r,(h,k,f) in roles.items():
        v=np.concatenate([v for j,n,v,tri in parts if j==f]);sole[r]=v[v[:,1]<v[:,1].min()+1e-5].mean(0);home[r]=piv[f]+sole[r]-piv[root];home[r][1]=0;home[r][0]+=(-1 if r=='L' else 1)*length*.065
    base_y=piv[root,1]-min(piv[f,1]+sole[r][1] for r,(_,_,f) in roles.items())-length*.22
    D={'walk':1.3,'step':1.45,'turn_left':1.7,'turn_right':1.7}[action];distance=length*gain*.65 if not action.startswith('turn') else 0.;angle=math.radians(90*gain)*(1 if action=='turn_left' else -1) if action.startswith('turn') else 0.
    schedules={r:[] for r in roles}
    def add(r,s,e,d,a):schedules[r].append((s,e,yaw(a)@home[r]+[0,0,-d],a))
    if action=='walk':add('L',.12,.43,distance,0);add('R',.57,.88,distance,0)
    elif action=='step':add('L',.19,.43,distance,0);add('R',.70,.92,distance,0)
    else:
        order=('L','R') if action=='turn_left' else ('R','L')
        for i,r in enumerate((*order,*order)):add(r,.08+i*.23,.25+i*.23,0,angle*(.5 if i<2 else 1))
    def foot(r,t):
        a=home[r].copy();ori=0.;lift=length*gain*(.16 if action=='step' else .10)
        for s,e,b,y in schedules[r]:
            if t<s-.055:break
            if t<e+.055:
                w=1-ease((t-s+.055)/.055) if t<s else 0 if t<=e else ease((t-e)/.055)
                if s<=t<=e:
                    u=(t-s)/(e-s);v=ease(u);p=a+(b-a)*v;p[1]+=lift*64*u**3*(1-u)**3;return p,ori+(y-ori)*v,float(w),False
                return (a,ori,float(w),True) if t<s else (b,y,float(w),True)
            a=b.copy();ori=y
        return a,ori,1.,True
    neutral=np.tile(np.eye(3),(g,1,1));arms={}
    for j,n in enumerate(names):
        if n.startswith('UpperArm'):
            child=next(k for k,p in enumerate(parent) if p==j);s=-1 if n.endswith('L') else 1;neutral[j]=align(off[child],[s*.50,-1.,-.12]);arms[j]=s
        elif n.startswith(('Forearm','Hand')):neutral[j]=neutral[parent[j]];arms[j]=-1 if n.endswith('L') else 1
    N=round(D*120)+1;X=[];Q=[];goals=[];states=[];proxy=[]
    for t in np.linspace(0,1,N):
        feet={r:foot(r,t) for r in roles};w=np.array([feet[r][2] for r in roles]);pts=np.array([feet[r][0] for r in roles]);mid=pts.mean(0);target=(pts*w[:,None]).sum(0)/w.sum()
        a=angle*ease(t);Y=yaw(a);p=mid*.50+target*.50-Y@np.mean(list(home.values()),axis=0);p[1]=base_y-length*(.045 if action=='step' else .02)*math.sin(math.pi*t)**2
        if action=='step':p[2]-=length*.065*gain*math.sin(math.pi*float(ease((t-.38)/.33)))**2
        side=float(np.dot(target-mid,Y[:,0])/length);roll=np.clip(-side*18,-6,6);pitch=(8 if action=='step' else 3)*math.sin(math.pi*t)**2*gain
        q=Y@neutral;q[root]=Y@R.from_euler('xz',[pitch,roll],degrees=True).as_matrix()
        for j,n in enumerate(names):
            if n=='Torso':q[j]=Y@R.from_euler('xz',[pitch*.55,-roll*.6],degrees=True).as_matrix()
            elif n=='Chest':q[j]=Y@R.from_euler('yxz',[-side*16,pitch*.25,-roll*.4],degrees=True).as_matrix()
            elif n.startswith('Shoulder'):q[j]=Y@R.from_euler('y',-side*10,degrees=True).as_matrix()
            elif j in arms:
                s=arms[j];sw=s*math.sin(2*math.pi*t)*18*gain
                if action=='step':sw+=(-18 if n.startswith('UpperArm') else -30)*math.sin(math.pi*t)**2*gain
                q[j]=Y@R.from_euler('x',sw,degrees=True).as_matrix()@neutral[j]
        x=np.zeros((g,3));x[root]=p
        for j,par in enumerate(parent):
            if par>=0:x[j]=x[par]+q[par]@off[j]
        for r,(h,k,f) in roles.items():
            goal,fy,_,_=feet[r];q[f]=yaw(fy);A=goal-q[f]@sole[r];H=x[h];v=A-H;d=np.linalg.norm(v);l1=np.linalg.norm(off[k]);l2=np.linalg.norm(off[f])
            if not abs(l1-l2)+1e-6<d<l1+l2-1e-6:raise ValueError('unreachable '+r+f' t={t:.3f} d={d:.3f} max={l1+l2:.3f}')
            u=v/d;z=(l1*l1-l2*l2+d*d)/(2*d);pole=Y@np.array([-.15 if r=='L' else .15,0,-1.]);pole-=u*(pole@u);K=H+u*z+pole/np.linalg.norm(pole)*np.sqrt(max(0,l1*l1-z*z));q[h]=align(Y@off[k],K-H)@Y;q[k]=align(Y@off[f],A-K)@Y;x[k]=K;x[f]=A
        X.append(x);Q.append(q);goals.append([feet[r][0] for r in roles]);states.append([feet[r][3] for r in roles]);proxy.append(np.linalg.norm((p-target)[[0,2]]))
    X=np.array(X);Q=np.array(Q);W=[np.einsum('nij,vj->nvi',Q[:,j],v)+X[:,j,None] for j,n,v,f in parts]
    m=dict(action=action,gain=gain,period_s=(N-1)/120,stride_m=float(distance),turn_deg=math.degrees(angle),frames=N,support_proxy_max_m=float(max(proxy)),pelvis_lateral_range_m=float(np.ptp(X[:,root,0])),pelvis_vertical_range_m=float(np.ptp(X[:,root,1])),min_support=int(np.min(np.sum(states,axis=1))),events={r:[dict(lift_s=s*D,plant_s=e*D) for s,e,_,_ in seq] for r,seq in schedules.items()})
    return X,Q,W,m,np.array(goals),np.array(states),sole

def audit(model,result):
    X,Q,W,m,goals,states,sole=result;names,parent,piv,parts=model;root,roles=discover(*model);n,g=X.shape[:2];t=np.arange(2*n-1)/2;A=np.empty((len(t),g,3));B=np.empty((len(t),g,3,3));A[:,root]=np.stack([np.interp(t,np.arange(n),X[:,root,j]) for j in range(3)],axis=1)
    for j,p in enumerate(parent):
        local=Q[:,j] if p<0 else Q[:,p].transpose(0,2,1)@Q[:,j];r=Slerp(np.arange(n),R.from_matrix(local))(t).as_matrix();B[:,j]=r if p<0 else B[:,p]@r
        if p>=0:A[:,j]=A[:,p]+np.einsum('nij,j->ni',B[:,p],piv[j]-piv[p])
    boxes=[];floor=0.;peak=0.;pair=None
    for j,name,v,f in parts:
        w=np.einsum('nij,vj->nvi',B[:,j],v)+A[:,j,None];floor=max(floor,max(0.,-float(w[:,:,1].min())));lo=v.min(0);hi=v.max(0);boxes.append((j,name,A[:,j]+np.einsum('nij,j->ni',B[:,j],(lo+hi)/2),B[:,j],(hi-lo)/2))
    for i,(j,name,a,U,ha) in enumerate(boxes):
        for k,name2,b,V,hb in boxes[i+1:]:
            if j==k or parent[j]==k or parent[k]==j:continue
            d=b-a;axes=[U[:,:,l] for l in range(3)]+[V[:,:,l] for l in range(3)]+[np.cross(U[:,:,u],V[:,:,v]) for u in range(3) for v in range(3)];over=np.full(len(t),np.inf)
            for u in axes:
                norm=np.linalg.norm(u,axis=1);valid=norm>1e-8;v=u/np.maximum(norm[:,None],1e-8);z=np.abs(np.einsum('ni,nij->nj',v,U))@ha+np.abs(np.einsum('ni,nij->nj',v,V))@hb-np.abs(np.sum(d*v,axis=1));over=np.minimum(over,np.where(valid,z,np.inf))
            mx=max(0.,float(over.max()))
            if mx>peak:peak=mx;pair=[name,name2,int(over.argmax())]
    slip=0.
    for j,(role,(_,_,f)) in enumerate(roles.items()):
        point=A[:,f]+np.einsum('nij,j->ni',B[:,f],sole[role]);idx=np.floor(t).astype(int);hi=np.ceil(t).astype(int);mask=states[idx,j]&states[hi,j]&(np.linalg.norm(goals[idx,j]-goals[hi,j],axis=1)<1e-8);slip=max(slip,float(np.max(np.linalg.norm(point[mask]-goals[idx[mask],j],axis=1),initial=0)))
    return dict(floor_240_m=floor,slip_240_m=slip,obb_nonadj_m=peak,obb_pair=pair,samples=len(t),eligible=bool(floor<=.002 and slip<=.005 and peak<=.05 and m['min_support']>=1))

def select(model,action):
    records=[];winner=None
    for gain in (1.,.85,.70,.55,.4):
        try:
            result=generate(model,action,gain);m=result[3];m.update(audit(model,result));records.append(m)
            if m['eligible'] and winner is None:winner=result
        except ValueError as e:records.append({'gain':gain,'eligible':False,'reason':str(e)})
    return winner,records

def main():
    import argparse
    from pathlib import Path
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('out',type=Path);p.add_argument('--unit',type=float,required=True);p.add_argument('--action',choices=('walk','step','turn_left','turn_right'),required=True);a=p.parse_args();model=parse_bb(json.loads(a.source.read_text()),a.unit);result,records=select(model,a.action);a.out.mkdir(parents=True,exist_ok=False);(a.out/'review.json').write_text(json.dumps({'version':31,'status':'review_required' if result else 'no_candidate','selected':result[3] if result else None,'candidates':records,'scope':'kinematic support proxy; not measured center of mass, dynamics or collision certification'},indent=2))
    if result:np.savez_compressed(a.out/'biped_world.npz',positions=result[0],rotations=result[1],fps=120,names=np.array(model[0]),parents=np.array(model[1]),pivots=model[2])
if __name__=='__main__':main()

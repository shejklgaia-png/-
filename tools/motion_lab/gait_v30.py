"""V30 rigid Blockbench biped/quadruped gait prototype. Y-up metres, offline."""
import json,re,math
import numpy as np
from scipy.spatial.transform import Rotation as R,Slerp

def align(a,b):
    a=np.asarray(a,float);b=np.asarray(b,float);a=a/np.linalg.norm(a);b=b/np.linalg.norm(b)
    c=np.clip(a@b,-1,1);v=np.cross(a,b);s=np.linalg.norm(v)
    if s<1e-9:
        if c>0:return np.eye(3)
        v=np.cross(a,np.eye(3)[np.argmin(abs(a))]);return R.from_rotvec(v/np.linalg.norm(v)*np.pi).as_matrix()
    return R.from_rotvec(v/s*np.arctan2(s,c)).as_matrix()

def parse_bb(d,unit):
    if d.get('meta',{}).get('model_format')!='free' or not 0<unit<=1:raise ValueError('unsupported model/unit')
    groups={g['uuid']:g for g in d['groups']};elements={e['uuid']:e for e in d['elements']};names=[];parent=[];piv=[];parts=[];seen=set()
    def visit(item,p):
        uid=item['uuid'] if isinstance(item,dict) else item
        if uid in seen:raise ValueError('duplicate hierarchy')
        seen.add(uid)
        if uid in groups:
            g=groups[uid];name=g['name']
            if re.match(r'^(Sword|Shield|Katana)',name,re.I):return
            if np.linalg.norm(g.get('rotation',[0,0,0]))>1e-8:raise ValueError('rotated group bind not supported')
            j=len(names);names.append(name);parent.append(p);piv.append(np.asarray(g['origin'])*unit)
            for c in item['children']:visit(c,j)
        else:
            e=elements[uid]
            if e.get('visibility',True) is False or e.get('export',True) is False:return
            if p<0 or e['type']!='mesh':raise ValueError('unsupported mesh')
            keys=list(e['vertices']);v=R.from_euler('xyz',e.get('rotation',[0,0,0]),degrees=True).apply([e['vertices'][k] for k in keys])*unit+np.asarray(e['origin'])*unit-piv[p]
            faces=[]
            for f in e['faces'].values():
                a=[keys.index(k) for k in f['vertices']]
                faces.extend([[a[0],a[i],a[i+1]] for i in range(1,len(a)-1)])
            parts.append((p,e['name'],v,faces))
    for x in d['outliner']:visit(x,-1)
    return names,parent,np.array(piv),parts

def discover(names,parent,piv,parts):
    roots=[i for i,p in enumerate(parent) if p<0];feet=[i for i,n in enumerate(names) if re.search(r'foot[_ -]?[lr]$',n,re.I)]
    if len(roots)!=1 or len(feet) not in (2,4):raise ValueError('ambiguous root or foot count')
    root=roots[0];roles={};used=set();mesh_nodes={p[0] for p in parts}
    for f in feet:
        k=parent[f];h=parent[k] if k>=0 else -1
        if min(h,k)<0 or parent[h]!=root or any(parent[j]==f for j in range(len(parent))) or f not in mesh_nodes:raise ValueError('unsupported terminal chain')
        chain=(h,k,f);side='L' if piv[f,0]<piv[root,0] else 'R';label=('F' if piv[h,2]<piv[root,2] else 'R')+side if len(feet)==4 else side
        if not names[f].upper().endswith(side) or abs(piv[f,0]-piv[root,0])<1e-6 or label in roles or used.intersection(chain):raise ValueError('ambiguous role')
        roles[label]=chain;used.update(chain)
    if set(roles)!=({'L','R'} if len(feet)==2 else {'FL','FR','RL','RR'}):raise ValueError('incomplete roles')
    return root,roles

def generate(model,stride_ratio=.36,lift_ratio=.12,period=1.4):
    names,parent,piv,parts=model;root,roles=discover(*model);g=len(names);quad=len(roles)==4;off=piv.copy()
    for j,p in enumerate(parent):
        if p>=0:off[j]-=piv[p]
    by=[np.concatenate([v for j,n,v,f in parts if j==i]) if any(j==i for j,n,v,f in parts) else np.empty((0,3)) for i in range(g)]
    length=np.mean([np.linalg.norm(off[k])+np.linalg.norm(off[f]) for h,k,f in roles.values()]);stride=length*stride_ratio;lift=length*lift_ratio;duty=.76 if quad else .62
    neutral=np.tile(np.eye(3),(g,1,1));base=piv[root].copy()
    if quad:
        for role,(h,k,f) in roles.items():
            sign=-1 if role.endswith('L') else 1;front=1 if role.startswith('F') else -1
            def direction(e,b):
                e,b=np.radians([e,b]);return np.array([sign*np.cos(e)*np.cos(b),np.sin(e),-front*np.cos(e)*np.sin(b)])
            neutral[h]=align(off[k],direction(12,12));neutral[k]=align(off[f],direction(-62,12));neutral[f]=align([sign,0,0],[0,-1,0])
    else:
        for j,n in enumerate(names):
            if n.startswith('UpperArm'):
                child=next(k for k,p in enumerate(parent) if p==j);sign=-1 if n.endswith('L') else 1;neutral[j]=align(off[child],[sign*.26,-1,.04])
            elif n.startswith(('Forearm','Hand')):neutral[j]=neutral[parent[j]]
    def fk(p,q):
        x=np.zeros((g,3));x[root]=p
        for j,par in enumerate(parent):
            if par>=0:x[j]=x[par]+q[par]@off[j]
        return x
    def low(x,q):return min((v@q[j].T+x[j])[:,1].min() for j,n,v,f in parts)
    x=fk(base,neutral);base[1]-=low(x,neutral);x=fk(base,neutral)
    sole={};home={}
    for role,(h,k,f) in roles.items():
        w=by[f]@neutral[f].T+x[f];mask=w[:,1]<w[:,1].min()+length*.004;sole[role]=by[f][mask].mean(0);home[role]=x[f]+neutral[f]@sole[role];home[role][1]=0
        if not quad:home[role][0]+=(-1 if role=='L' else 1)*length*.045
    base[1]-=length*(.02 if quad else .11)
    phases={'FL':0.,'RR':.25,'FR':.5,'RL':.75} if quad else {'L':0.,'R':.5}
    N=round(period*120)+1;positions=[];rotations=[];contacts=[]
    for t in np.linspace(0,1,N):
        q=neutral.copy();p=base.copy();p[2]-=stride*t;p[1]+=length*.009*np.cos(4*np.pi*t)
        if not quad:p[0]+=length*.035*np.sin(2*np.pi*t)
        for j,name in enumerate(names):
            if name.startswith(('UpperArm','Forearm','Hand')):
                s=1 if name.endswith('L') else -1;q[j]=R.from_euler('x',s*12*np.sin(2*np.pi*t),degrees=True).as_matrix()@neutral[j]
        x=fk(p,q);state={}
        for role,(h,k,f) in roles.items():
            phase=(t+phases[role])%1;u=np.clip((phase-duty)/(1-duty),0,1);s=u**3*(10-15*u+6*u*u);goal=home[role].copy();goal[2]-=stride*(t+duty/2-phase+s);goal[1]+=lift*64*u**3*(1-u)**3;state[role]=bool(phase<duty)
            A=goal-q[f]@sole[role];H=x[h];v=A-H;d=np.linalg.norm(v);a=np.linalg.norm(off[k]);b=np.linalg.norm(off[f])
            if not abs(a-b)+1e-6<d<a+b-1e-6:raise ValueError('unreachable '+role)
            direction=v/d;along=(a*a-b*b+d*d)/(2*d);pole=x[k]-H;pole-=direction*(pole@direction)
            if np.linalg.norm(pole)<1e-8:raise ValueError('ambiguous knee')
            K=H+direction*along+pole/np.linalg.norm(pole)*np.sqrt(max(0,a*a-along*along));q[h]=align(q[h]@off[k],K-H)@q[h];q[k]=align(q[k]@off[f],A-K)@q[k];x[k]=K;x[f]=A
        positions.append(x);rotations.append(q);contacts.append(state)
    X=np.array(positions);Q=np.array(rotations);W=[np.einsum('nij,vj->nvi',Q[:,j],v)+X[:,j,None] for j,n,v,f in parts];floor=max(0.,-min(w[:,:,1].min() for w in W));slip=0.
    for role,(_,_,f) in roles.items():
        p=X[:,f]+np.einsum('nij,j->ni',Q[:,f],sole[role]);mask=np.array([s[role] for s in contacts]);slip=max(slip,np.max(np.linalg.norm(np.diff(p,axis=0)[mask[:-1]&mask[1:]],axis=1),initial=0.))
    return X,Q,W,dict(topology='quadruped' if quad else 'biped',roles={r:[names[j] for j in c] for r,c in roles.items()},period_s=period,stride_m=float(stride),lift_m=float(lift),floor_m=float(floor),planted_step_error_m=float(slip),min_support=min(sum(s.values()) for s in contacts),frames=N,loop_delta_m=float(np.max(np.abs((X[-1]-X[0])-[0,0,-stride]))),status='review_required')

def audit(model,X,Q,report):
    names,parent,piv,parts=model;root,roles=discover(*model);n,g=X.shape[:2];t=np.arange(2*n-1)/2;A=np.empty((len(t),g,3));B=np.empty((len(t),g,3,3));B[:,root]=Slerp(np.arange(n),R.from_matrix(Q[:,root]))(t).as_matrix();A[:,root]=np.stack([np.interp(t,np.arange(n),X[:,root,j]) for j in range(3)],axis=1)
    for j,p in enumerate(parent):
        if p<0:continue
        local=Q[:,p].transpose(0,2,1)@Q[:,j];B[:,j]=B[:,p]@Slerp(np.arange(n),R.from_matrix(local))(t).as_matrix();A[:,j]=A[:,p]+np.einsum('nij,j->ni',B[:,p],piv[j]-piv[p])
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
    slip=0.;duty=.76 if len(roles)==4 else .62;phases={'FL':0.,'RR':.25,'FR':.5,'RL':.75} if len(roles)==4 else {'L':0.,'R':.5}
    for role,(_,_,f) in roles.items():
        v=np.concatenate([v for j,name,v,tri in parts if j==f]);w=v@Q[0,f].T+X[0,f];sole=v[w[:,1]<w[:,1].min()+.003].mean(0);point=A[:,f]+np.einsum('nij,j->ni',B[:,f],sole);phase=t/(n-1)+phases[role];cycle=np.floor(phase);phase%=1
        for c in np.unique(cycle):
            mask=(cycle==c)&(phase<duty);z=point[mask]
            if len(z):slip=max(slip,float(np.linalg.norm(z-z[0],axis=1).max()))
    return dict(floor_240_m=floor,slip_240_m=slip,obb_nonadj_m=peak,obb_pair=pair,samples=len(t),eligible=bool(floor<=.002 and slip<=.005 and peak<=.05 and report['loop_delta_m']<=.002))

def main():
    import argparse
    from pathlib import Path
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('out',type=Path);p.add_argument('--unit',required=True,type=float);p.add_argument('--period',type=float,default=1.4);a=p.parse_args()
    if not .3<=a.period<=5:raise ValueError('period')
    model=parse_bb(json.loads(a.source.read_text()),a.unit);root,roles=discover(*model)
    records=[];winner=None
    for sr in (.36,.28,.20,.14):
        for lr in (.12,.08,.05):
            try:
                X,Q,W,m=generate(model,sr,lr,a.period);m.update(stride_ratio=sr,lift_ratio=lr,**audit(model,X,Q,m));records.append(m)
                if m['eligible'] and winner is None:winner=(X,Q,m)
            except ValueError as e:records.append({'stride_ratio':sr,'lift_ratio':lr,'eligible':False,'reason':str(e)})
    a.out.mkdir(parents=True,exist_ok=False)
    (a.out/'review.json').write_text(json.dumps({'version':30,'source':str(a.source),'unit_m':a.unit,'status':'review_required' if winner else 'no_candidate','selected':winner[2] if winner else None,'candidates':records,'scope':'heuristic named feet, rigid zero-bind groups, sampled OBB proxy, no balance dynamics or game approval'},indent=2))
    if winner:
        X,Q,m=winner;np.savez_compressed(a.out/'gait_world.npz',positions=X,rotations=Q,fps=120,names=np.array(model[0]),parents=np.array(model[1]),pivots=model[2])
if __name__=='__main__':main()

"""V29 rigid three-joint chain transfer: explicit semantic slots, Y-up metres.
Standalone offline NumPy/SciPy adapter, not the existing game build path.
Source world rotation matrices and target geometry are supplied explicitly.
"""
import numpy as np
from scipy.spatial.transform import Rotation as R,Slerp

def align(a,b):
    a=np.array(a,float);b=np.array(b,float);a/=np.linalg.norm(a);b/=np.linalg.norm(b)
    v=np.cross(a,b);c=np.clip(a@b,-1,1);s=np.linalg.norm(v)
    if s<1e-9:
        if c>0:return np.eye(3)
        p=np.eye(3)[np.argmin(abs(a))];p=np.cross(a,p);p/=np.linalg.norm(p)
        return R.from_rotvec(p*np.pi).as_matrix()
    return R.from_rotvec(v/s*np.arctan2(s,c)).as_matrix()

def knee(h,a,k,l1,l2):
    v=a-h;d=np.linalg.norm(v)
    if not abs(l1-l2)+1e-6<d<l1+l2-1e-6:raise ValueError('unreachable support')
    u=v/d;p=k-h;p-=u*(u@p);n=np.linalg.norm(p)
    if n<1e-8:raise ValueError('singular bend plane')
    x=(l1*l1-l2*l2+d*d)/(2*d)
    return h+u*x+p/n*np.sqrt(max(0,l1*l1-x*x))

def retarget(source,rig,striker,scale,compression=1.,clearance=0.):
    """source root (N,3), rotation (N,G,3,3), at 120 Hz.
    rig: root/head slot, roles (three joint slots), local offsets, local
    vertices by slot, sole points, basis maps (target local -> source local).
    The role slot correspondence must be explicitly supplied by the caller.
    """
    pos=np.asarray(source['root'],float);rot=np.asarray(source['rotation'],float);n,g=rot.shape[:2]
    if pos.shape!=(n,3) or rot.shape!=(n,g,3,3) or n<2 or not np.isfinite(rot).all() or not np.isfinite(pos).all() or not np.isfinite([scale,compression,clearance]).all() or scale<=0 or compression<=0 or clearance<0:raise ValueError('invalid source')
    if np.max(abs(rot@rot.swapaxes(-1,-2)-np.eye(3)))>1e-4 or np.min(np.linalg.det(rot))<.999:raise ValueError('invalid source basis')
    root=rig['root'];head=rig['head'];roles=rig['roles'];off=np.asarray(rig['offsets'],float);verts=[np.asarray(v,float) for v in rig['vertices']];sole={k:np.asarray(v,float) for k,v in rig['sole'].items()}
    ids=[root,head]+[j for c in roles.values() for j in c]
    if len(ids)!=g or len(set(ids))!=g or set(ids)!=set(range(g)) or striker not in roles or any(len(c)!=3 for c in roles.values()) or len(roles)<2:raise ValueError('explicit disjoint 3-joint roles required')
    if off.shape!=(g,3) or not np.isfinite(off).all() or len(verts)!=g or any(v.ndim!=2 or v.shape[1]!=3 or not len(v) or not np.isfinite(v).all() for v in verts) or set(sole)!=set(roles) or any(v.shape!=(3,) or not np.isfinite(v).all() for v in sole.values()):raise ValueError('invalid target geometry')
    if any(min(np.linalg.norm(off[k]),np.linalg.norm(off[f]))<1e-6 for _,k,f in roles.values()):raise ValueError('zero length link')
    basis=np.asarray(rig.get('basis',np.tile(np.eye(3),(g,1,1))),float)
    if basis.shape!=(g,3,3) or not np.isfinite(basis).all() or np.max(abs(basis@basis.swapaxes(-1,-2)-np.eye(3)))>1e-5 or np.min(np.linalg.det(basis))<.999:raise ValueError('invalid semantic basis')
    rot=rot@basis;world=np.empty((n,g,3));outrot=rot.copy();anchors={};max_slip=0.;max_floor=0.;max_raise=0.
    def fk(p,q):
        x=np.empty((g,3));x[root]=p;x[head]=p+q[root]@off[head]
        for h,k,f in roles.values():x[h]=p+q[root]@off[h];x[k]=x[h]+q[h]@off[k];x[f]=x[k]+q[k]@off[f]
        return x
    def low(x,q,groups):return min((verts[j]@q[j].T+x[j])[:,1].min() for j in groups)
    start=pos[0]*scale;initial=fk(start,rot[0]);start[1]-=low(initial,rot[0],range(g));initial=fk(start,rot[0])
    for name,(h,k,f) in roles.items():
        a=initial[f]+rot[0,f]@sole[name];a[1]-=low(initial,rot[0],[f]);anchors[name]=(a,rot[0,f])
    attack=[root,head,*roles[striker]]
    for i in range(n):
        q=rot[i].copy();p=start+(pos[i]-pos[0])*scale;p[1]=start[1]+(pos[i,1]-pos[0,1])*scale*compression
        x=fk(p,q);margin=clearance*min(1.,i/8,(n-1-i)/8);raise_by=max(0.,margin-low(x,q,attack));p[1]+=raise_by;max_raise=max(max_raise,raise_by);x=fk(p,q)
        for name,(h,k,f) in roles.items():
            if name==striker:continue
            goal,ori=anchors[name];a=goal-ori@sole[name];K=knee(x[h],a,x[k],np.linalg.norm(off[k]),np.linalg.norm(off[f]));q[h]=align(q[h]@off[k],K-x[h])@q[h];q[k]=align(q[k]@off[f],a-K)@q[k];q[f]=ori;x[k]=K;x[f]=a
            max_slip=max(max_slip,np.linalg.norm(x[f]+q[f]@sole[name]-goal))
        max_floor=max(max_floor,max(0.,-low(x,q,range(g))));world[i]=x;outrot[i]=q
    return world,outrot,{'sample_floor_m':float(max_floor),'support_error_m':float(max_slip),'max_root_raise_m':float(max_raise),'samples':n,'status':'review_required'}

def audit_transfer(x,q,rig,striker):
    """240Hz check of 120Hz local quaternion playback. OBB is a proxy."""
    n,g=x.shape[:2];t=np.arange(2*n-1)/2;roles=rig['roles'];root=rig['root'];head=rig['head'];off=np.asarray(rig['offsets']);parent={root:None,head:root}
    for h,k,f in roles.values():parent.update({h:root,k:h,f:k})
    X=np.empty((len(t),g,3));Q=np.empty((len(t),g,3,3));X[:,root]=np.stack([np.interp(t,np.arange(n),x[:,root,i]) for i in range(3)],axis=1)
    for j in parent:
        p=parent[j];local=q[:,j] if p is None else q[:,p].transpose(0,2,1)@q[:,j]
        r=Slerp(np.arange(n),R.from_matrix(local))(t).as_matrix();Q[:,j]=r if p is None else Q[:,p]@r
        if p is not None:X[:,j]=X[:,p]+np.einsum('nij,j->ni',Q[:,p],off[j])
    vs=[np.asarray(v) for v in rig['vertices']];W=[np.einsum('nij,vj->nvi',Q[:,j],v)+X[:,j,None] for j,v in enumerate(vs)]
    boxes=[];covered={j:[] for j in range(g)}
    for j,indices in rig.get('parts',[(j,list(range(len(v)))) for j,v in enumerate(vs)]):
        if j not in covered or not len(indices) or any(i<0 or i>=len(vs[j]) for i in indices):raise ValueError('invalid part partition')
        covered[j].extend(indices)
        v=vs[j][indices];lo=v.min(0);hi=v.max(0);boxes.append((j,X[:,j]+np.einsum('nij,j->ni',Q[:,j],(lo+hi)/2),Q[:,j],(hi-lo)/2))
    if any(sorted(indices)!=list(range(len(vs[j]))) for j,indices in covered.items()):raise ValueError('parts must partition geometry')
    peak=0.;pair=None
    for i,(j,a,A,ha) in enumerate(boxes):
        for k,b,B,hb in boxes[i+1:]:
            if j==k or parent[j]==k or parent[k]==j:continue
            d=b-a;axes=[A[:,:,l] for l in range(3)]+[B[:,:,l] for l in range(3)]+[np.cross(A[:,:,u],B[:,:,v]) for u in range(3) for v in range(3)];over=np.full(len(t),np.inf)
            for u in axes:
                norm=np.linalg.norm(u,axis=1);valid=norm>1e-8;v=u/np.maximum(norm[:,None],1e-8);z=np.abs(np.einsum('ni,nij->nj',v,A))@ha+np.abs(np.einsum('ni,nij->nj',v,B))@hb-np.abs(np.sum(d*v,axis=1));over=np.minimum(over,np.where(valid,z,np.inf))
            mx=max(0.,float(over.max()))
            if mx>peak:peak=mx;pair=[j,k,int(over.argmax())]
    slip=0.
    for name,(_,_,f) in roles.items():
        if name==striker:continue
        p=X[:,f]+np.einsum('nij,j->ni',Q[:,f],np.asarray(rig['sole'][name]));slip=max(slip,float(np.linalg.norm(p-p[0],axis=1).max()))
    floor=max(0.,-min(float(w[:,:,1].min()) for w in W));terminal=max(float(np.linalg.norm(w[-1]-w[0],axis=1).max()) for w in W)
    return dict(floor_240_m=floor,slip_240_m=slip,obb_nonadj_m=peak,obb_pair=pair,terminal_delta_m=terminal,samples=len(t),eligible=bool(floor<=.002 and slip<=.005 and peak<=.05 and terminal<=.002))

def retime(source,boundaries,multipliers):
    """Resample a source clip at 120Hz using explicit phase duration factors."""
    pos=np.asarray(source['root']);rot=np.asarray(source['rotation']);b=np.asarray(boundaries,int);w=np.asarray(multipliers,float)
    if len(b)!=len(w)+1 or b[0]!=0 or b[-1]!=len(pos)-1 or np.any(np.diff(b)<=0) or not np.isfinite(w).all() or np.any(w<=0):raise ValueError('invalid phase plan')
    new=np.r_[0,np.cumsum(np.maximum(1,np.rint(np.diff(b)*w).astype(int)))];t=np.interp(np.arange(new[-1]+1),new,b);p=np.stack([np.interp(t,np.arange(len(pos)),pos[:,i]) for i in range(3)],axis=1);q=np.stack([Slerp(np.arange(len(pos)),R.from_matrix(rot[:,j]))(t).as_matrix() for j in range(rot.shape[1])],axis=1)
    return {'root':p,'rotation':q},new.tolist()

def select_transfer(source,rig,striker,scale,compression=1.):
    """Try bounded correction candidates, retain the requested geometry.
    No candidate is returned as eligible unless all sample gates pass."""
    records=[];winner=None
    for multiplier in (1.,.97,.93,.88,.82):
        try:
            x,q,r=retarget(source,rig,striker,scale,compression*multiplier,.005)
            a=audit_transfer(x,q,rig,striker);record={**r,**a,'compression_multiplier':multiplier};records.append(record)
            if a['eligible'] and winner is None:winner=(x,q,record)
        except ValueError as exc:
            records.append({'compression_multiplier':multiplier,'eligible':False,'reason':str(exc)})
    return winner,records

def main():
    import argparse,json
    from pathlib import Path
    from chain_performance import PROFILES
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path,help='NPZ root/rotation arrays, Y up, 120Hz')
    p.add_argument('rig',type=Path,help='Explicit target slot geometry JSON')
    p.add_argument('out',type=Path)
    p.add_argument('--strike',required=True);p.add_argument('--scale',type=float,required=True)
    p.add_argument('--profile',choices=tuple(PROFILES),default='medium')
    p.add_argument('--phases',nargs=5,type=int,help='Five zero-based sample boundaries: ready, drive, follow, settle, end')
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    with np.load(a.source,allow_pickle=False) as f:source={k:f[k] for k in ('root','rotation')}
    rig=json.loads(a.rig.read_text());pr=PROFILES[a.profile];boundaries=None
    if a.phases:source,boundaries=retime(source,a.phases,[pr[k] for k in ('anticipation','release','follow','recovery')])
    elif a.profile!='medium':raise ValueError('weight profile requires explicit phase boundaries')
    winner,records=select_transfer(source,rig,a.strike,a.scale,pr['compression'])
    report={'version':29,'status':'review_required' if winner else 'no_candidate','profile':a.profile,'phase_frames':boundaries,'candidates':records,'selected':winner[2] if winner else None,'scope':'240Hz sampled OBB proxy, closed stationary-support clips only; no automatic role discovery, exact mesh collision, joint limits, or runtime approval'}
    (a.out/'review.json').write_text(json.dumps(report,indent=2))
    if winner:
        x,q,_=winner;np.savez_compressed(a.out/'retargeted_world.npz',positions=x,rotations=q,fps=120)
if __name__=='__main__':main()

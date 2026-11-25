"""Offline quaternion trajectory refinement, numpy only, XYZW order."""
import numpy as np

def canonical(q):
    q=np.array(q,dtype=float,copy=True);n=np.linalg.norm(q,axis=-1,keepdims=True)
    if not np.isfinite(q).all() or np.min(n)<1e-10:raise ValueError('invalid rotations')
    q/=n
    for i in range(1,len(q)):
        q[i]*=np.where(np.sum(q[i]*q[i-1],axis=-1,keepdims=True)<0,-1.,1.)
    return q

def candidates(q,locked,weights=(.15,.6,2.4),soft=None):
    """Global locked-key least squares in quaternion embedding, normalize.
    Reference fidelity plus weighted acceleration/jerk; not physical dynamics."""
    q=canonical(q);n=len(q);locked=np.unique([0,n-1,*locked]);free=np.setdiff1d(np.arange(n),locked)
    if n<4 or np.any(locked<0) or np.any(locked>=n):raise ValueError('frame range')
    data=q.reshape(n,-1);D2=np.diff(np.eye(n),n=2,axis=0);D3=np.diff(np.eye(n),n=3,axis=0)
    w=np.ones(n) if soft is None else np.array(soft,dtype=float)
    if w.shape!=(n,) or not np.isfinite(w).all() or np.min(w)<=0:raise ValueError('invalid fidelity weights')
    yield 'baseline',q.copy()
    if not len(free):return
    for lam in weights:
        if not np.isfinite(lam) or lam<=0:raise ValueError('invalid regularization')
        H=np.diag(w)+lam*(D2.T@D2+.25*D3.T@D3)
        z=data.copy();z[free]=np.linalg.solve(H[np.ix_(free,free)],w[free,None]*data[free]-H[np.ix_(free,locked)]@data[locked]);z=canonical(z.reshape(q.shape));z[locked]=q[locked]
        yield 'lambda_'+str(lam),z

def angular_metrics(q,fps):
    q=canonical(q);a=q[:-1];b=q[1:];av=a[...,:3];bv=b[...,:3];aw=a[...,3:];bw=b[...,3:]
    v=aw*bv-bw*av-np.cross(av,bv);s=np.sum(a*b,axis=-1,keepdims=True);l=np.linalg.norm(v,axis=-1,keepdims=True)
    omega=v*(2*np.arctan2(l,np.maximum(s,0))/np.maximum(l,1e-12))*fps
    acceleration=np.diff(omega,axis=0)*fps;jerk=np.diff(acceleration,axis=0)*fps
    return {'rms_accel_rad_s2':float(np.sqrt(np.mean(acceleration**2))), 'rms_jerk_rad_s3':float(np.sqrt(np.mean(jerk**2))), 'peak_speed_rad_s':float(np.max(np.linalg.norm(omega,axis=-1)))}

def choose(records):
    ok=[r for r in records if r['eligible']]
    return min(ok,key=lambda r:(r['score'],r['name']))['name'] if ok else 'baseline'

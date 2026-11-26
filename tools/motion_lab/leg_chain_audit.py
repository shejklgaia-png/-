"""Sampled hip-to-ankle alignment audit, Y up, forward -Z, in metres.
Input NPZ: joints[N,2,3,3] = hip,knee,ankle; thigh_axis[N,2,3]
points hip->knee; thigh_center[N,2,3]; ankle_axis[N,2,3] points down
foot frame; contact[N,2]. Supply one periodic cycle, no duplicate endpoint,
120 equally spaced samples at the SERA RUN cycle of 0.5333 s for thresholds.
Thresholds are provisional diagnostics, not anatomical limits or artistic
approval. Includes worst frame indices.
"""
import argparse,json
import numpy as np

def audit(joints,thigh_axis,thigh_center,ankle_axis,contact):
    j=np.asarray(joints,float); t=np.asarray(thigh_axis,float); c=np.asarray(thigh_center,float); a=np.asarray(ankle_axis,float); ct=np.asarray(contact,bool)
    if j.ndim!=4 or j.shape[1:]!=(2,3,3) or len(j)!=120 or any(x.shape!=j.shape[:2]+(3,) for x in (t,c,a)) or ct.shape!=j.shape[:2] or not all(np.isfinite(x).all() for x in (j,t,c,a)): raise ValueError('invalid leg packet; expected 120 periodic samples')
    def norm(x):
        n=np.linalg.norm(x,axis=-1,keepdims=True)
        if np.any(n<1e-9): raise ValueError('degenerate axis')
        return x/n
    def angle(x,y): return np.degrees(np.arccos(np.clip(np.sum(norm(x)*norm(y),axis=-1),-1,1)))
    h,k,f=j[:,:,0],j[:,:,1],j[:,:,2]; upper=k-h; lower=f-k; u=norm(upper); offset=c-h; offset-=u*np.sum(offset*u,axis=-1,keepdims=True)
    pitch=np.degrees(np.arctan2(-upper[...,2],-upper[...,1])); swing=~ct
    core=swing.copy()
    for n in range(1,10): core &= np.roll(swing,n,axis=0)&np.roll(swing,-n,axis=0)
    d={'thigh_axis_error_deg':(angle(t,upper),5.),'thigh_center_offset_mm':(np.linalg.norm(offset,axis=-1)*1000,10.),'knee_lateral_mm':(np.abs(k[...,0]-h[...,0])*1000,10.),'thigh_forward_deg':(pitch,105.),'thigh_backward_deg':(-pitch,60.),'knee_flexion_deg':(angle(upper,lower),150.),'thigh_step_deg':(angle(upper,np.roll(upper,-1,axis=0)),12.),'ankle_swing_axis_error_deg':(np.where(core,angle(a,lower),0),35.)}
    result={}
    for name,(v,limit) in d.items():
        i,s=np.unravel_index(np.argmax(v),v.shape); result[name]={'max':float(v[i,s]),'limit':limit,'frame':int(i),'side':int(s),'flagged_samples':int(np.count_nonzero(v>limit))}
    return {'samples':len(j),'swing_core_samples':int(core.sum()),'checks':result,'pass_diagnostic':bool(core.any() and all(x['flagged_samples']==0 for x in result.values())), 'scope':'sampled, thresholds provisional, no artistic approval'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('input');args=p.parse_args()
    with np.load(args.input,allow_pickle=False) as v: r=audit(*(v[k] for k in ('joints','thigh_axis','thigh_center','ankle_axis','contact')))
    print(json.dumps(r,indent=2));raise SystemExit(0 if r['pass_diagnostic'] else 2)

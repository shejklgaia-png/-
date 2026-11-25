"""Offline bounded sample-space floor repair and minimum-cost state paths."""
import numpy as np

def minimum_path(cost, transitions):
    cost=np.asarray(cost,float)
    if cost.ndim!=2 or not len(cost) or not cost.shape[1] or np.isnan(cost).any():raise ValueError('cost shape')
    n,k=cost.shape;prev=cost[0].copy();back=[]
    for i in range(1,n):
        edge=np.asarray(transitions(i),float)
        if edge.shape!=(k,k) or np.isnan(edge).any():raise ValueError('transition shape')
        score=prev[:,None]+edge;idx=score.argmin(0);prev=cost[i]+score[idx,np.arange(k)];back.append(idx)
    if not np.isfinite(prev).any():raise ValueError('no feasible path')
    j=int(prev.argmin());path=[j]
    for idx in reversed(back):j=int(idx[j]);path.append(j)
    return np.array(path[::-1],int)

def repair_floor(rot,locked,evaluate,*,substeps=4,margin=.0005,tolerance=.002,max_delta_deg=2.,passes=8):
    """Evaluator receives dense Euler radians and zero-based fractional frame times.
    Only unlocked adjacent keys move; return source if sampled floor cannot pass."""
    base=np.array(rot,float,copy=True);x=base.copy();n=len(x)
    if base.ndim!=3 or base.shape[-1]!=3 or n<2 or not np.isfinite(base).all():raise ValueError('rotation shape')
    locked=set(locked)|{0,n-1};cap=np.radians(max_delta_deg);eps=1e-4
    times=np.arange((n-1)*substeps+1,dtype=float)/substeps
    old=np.asarray(evaluate(base,times));current=old.copy();trace=[]
    if old.shape!=times.shape or not np.isfinite(old).all():raise ValueError('invalid floor samples')
    for _ in range(passes):
        bad=np.where(current < -tolerance)[0]
        if not len(bad):break
        for j in sorted(bad,key=lambda j:current[j]):
            t=times[j];z=float(evaluate(x,[t])[0])
            if z>=-tolerance:continue
            ids=[i for i in sorted({int(np.floor(t)),int(np.ceil(t))}) if i not in locked]
            if not ids:continue
            grad=np.zeros_like(x)
            for i in ids:
                for a in range(x.shape[1]):
                    for b in range(3):
                        x[i,a,b]+=eps;h=float(evaluate(x,[t])[0]);x[i,a,b]-=eps
                        grad[i,a,b]=(h-z)/eps
            norm=float(np.sum(grad*grad))
            if norm<1e-12 or not np.isfinite(norm):continue
            x+=grad*((margin-z)/norm);x=base+np.clip(x-base,-cap,cap)
        current=np.asarray(evaluate(x,times))
        if not np.isfinite(current).all():raise ValueError('invalid candidate floor samples')
        trace.append(float(current.min()))
    success=bool(current.min()>=-tolerance)
    return (x if success else base),dict(success=success,baseline_min_m=float(old.min()),candidate_min_m=float(current.min()),max_delta_deg=float(np.degrees(np.abs(x-base)).max()),changed_frames=np.where(np.max(np.abs(x-base),axis=(1,2))>1e-9)[0].tolist(),trace=trace,substeps=substeps)

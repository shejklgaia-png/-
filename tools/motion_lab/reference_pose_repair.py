"""Experimental reference-first biped floor correction.
All inputs are sampled world transforms, Y-up metres. Does not infer contact
locks, author new gait cycles, or approve output. Preserve reference upper-body
rotation, travel, and foot orientation; smooth pelvis and solve two-link legs.
"""
import math
import numpy as np
from scipy.ndimage import gaussian_filter1d
from gait_v30 import align

def propose(X,Q,offsets,roles,foot_low,sigma=5.,blend=.65):
    X=np.asarray(X,float);Q=np.asarray(Q,float);off=np.asarray(offsets,float);low=np.asarray(foot_low,float)
    if X.ndim!=3 or X.shape[-1]!=3 or Q.shape!=(*X.shape[:2],3,3) or off.shape!=X.shape[1:] or low.shape!=(len(X),) or not all(np.isfinite(v).all() for v in (X,Q,off,low)) or sigma<=0 or not 0<=blend<=1:
        raise ValueError("invalid reference packet")
    if len(roles)!=2 or any(len(c)!=3 for c in roles.values()):raise ValueError("two disjoint three-joint legs required")
    ids=[j for c in roles.values() for j in c]
    if len(set(ids))!=6 or min(ids)<1 or max(ids)>=X.shape[1]:raise ValueError("invalid role slots")
    ground=-low;exact=X[:,0,1]+ground
    want=exact+(gaussian_filter1d(exact,sigma,mode="nearest")-exact)*blend
    Y=X.copy();B=Q.copy();goals=X.copy();goals[:,:,1]+=ground[:,None];count=0
    for i in range(len(X)):
        lower=-np.inf;upper=np.inf
        for h,k,f in roles.values():
            hrel=X[i,h]-X[i,0];v=goals[i,f]-X[i,h];horizontal=np.linalg.norm(v[[0,2]])
            reach=(np.linalg.norm(off[k])+np.linalg.norm(off[f]))*.997
            if horizontal>=reach:raise ValueError("unreachable horizontal span")
            hi=math.sqrt(reach*reach-horizontal*horizontal);a=goals[i,f,1]-hrel[1]
            lower=max(lower,a-hi);upper=min(upper,a+hi)
        if lower>upper:raise ValueError("no pelvis interval")
        py=np.clip(want[i],lower,upper);count+=int(abs(py-want[i])>1e-7)
        Y[i,:,1]+=py-X[i,0,1]
        for h,k,f in roles.values():
            H=Y[i,h];A=goals[i,f];v=A-H;d=np.linalg.norm(v);a=np.linalg.norm(off[k]);b=np.linalg.norm(off[f])
            if not abs(a-b)+1e-5<d<a+b:raise ValueError("unreachable bend")
            u=v/d;pole=X[i,k]-X[i,h];pole-=u*(pole@u)
            if np.linalg.norm(pole)<1e-7:raise ValueError("degenerate pole")
            along=(a*a-b*b+d*d)/(2*d);K=H+u*along+pole/np.linalg.norm(pole)*math.sqrt(max(0,a*a-along*along))
            B[i,h]=align(Q[i,h]@off[k],K-H)@Q[i,h]
            B[i,k]=align(Q[i,k]@off[f],A-K)@Q[i,k];Y[i,k]=K;Y[i,f]=A
    return Y,B,{"clamped_frames":count,"sigma":sigma,"blend":blend,"status":"experimental_not_approved","contact_lock_verified":False}

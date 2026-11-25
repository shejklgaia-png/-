"""V28 reusable geometry and performance profiles, no Blender dependency."""
import math
import numpy as np

def knee_target(hip,ankle,hint,l1,l2):
    """Exact two-link solve in a supplied coordinate system; fail on bad reach."""
    h,a,k=(np.asarray(x,float) for x in (hip,ankle,hint))
    if any(x.shape!=(3,) or not np.isfinite(x).all() for x in (h,a,k)) or not all(math.isfinite(x) and x>0 for x in (l1,l2)):
        raise ValueError("invalid chain geometry")
    v=a-h;d=float(np.linalg.norm(v))
    if not abs(l1-l2)+1e-8<d<l1+l2-1e-8:raise ValueError("unreachable or singular two-link chain")
    u=v/d;p=k-h;p-=u*np.dot(p,u);n=float(np.linalg.norm(p))
    if n<1e-8:raise ValueError("singular bend plane")
    along=(l1*l1-l2*l2+d*d)/(2*d)
    return h+u*along+(p/n)*math.sqrt(max(0,l1*l1-along*along))

# Authoring priors, not simulated mass or physics. Never applied implicitly.
PROFILES={
 "light":{"anticipation":.72,"release":.86,"follow":.72,"recovery":.80,"compression":.72,"overlap":.78},
 "medium":{"anticipation":1.,"release":1.,"follow":1.,"recovery":1.,"compression":1.,"overlap":1.},
 "heavy":{"anticipation":1.25,"release":.94,"follow":1.30,"recovery":1.25,"compression":1.15,"overlap":1.20}
}

def phase_plan(boundaries,phases,profile,span_m):
    """Explicit input phase intervals; time and amplitude priors for new designs.
    Output is a planning packet, not a retimed or validated clip."""
    if profile not in PROFILES or not math.isfinite(span_m) or span_m<=0:raise ValueError("profile/span")
    b=np.asarray(boundaries,float)
    if b.ndim!=1 or len(b)!=len(phases)+1 or not np.isfinite(b).all() or b[0]!=0 or np.any(np.diff(b)<=0):raise ValueError("phase boundaries")
    p=PROFILES[profile];new=[0.]
    for dt,phase in zip(np.diff(b),phases):
        if phase not in ("anticipation","release","follow","recovery"):raise ValueError("unknown phase")
        new.append(new[-1]+float(dt)*p[phase])
    return {"profile":profile,"source_boundaries_s":b.tolist(),"planned_boundaries_s":new,"phases":list(phases),
            "compression_multiplier":p["compression"],"overlap_multiplier":p["overlap"],"reference_span_m":span_m,
            "status":"planning_only"}

def chain_descriptor(roles):
    """Explicitly resolved role paths; no guesses from model names."""
    seen=set();result={}
    for role,ids in roles.items():
        ids=list(ids)
        if len(ids)!=3 or len(set(ids))!=3 or seen.intersection(ids):raise ValueError("expected disjoint three-joint chains")
        seen.update(ids);result[role]=ids
    if not result:raise ValueError("no chains")
    return result

"""Post-impact additive acting profiles; not a force or rigid-body simulation."""
import math
import numpy as np
from multifoot_ik import _dense,propose

def bump(t,start,duration):
    u=(t-start)/duration
    return 64*u**3*(1-u)**3 if 0<u<1 else 0.

def profile_curve(t,down_s,rebound_s,ratio):
    # Compact C2 lobes with diminishing rebound. No change at impact itself.
    return -bump(t,0.,down_s)+ratio*bump(t,down_s,rebound_s)

def build_profiles(d,nodes,end,base):
    spec=d["secondary_refinement"]
    root=d["support_lock"]["root"]; head=d["markers"]["Head"]["node"]
    if nodes[root].parent is not None or nodes[head].parent!=nodes[root]:
        raise ValueError("secondary profile requires verified root/head hierarchy")
    tracks=d["tracks"]; fps=int(d["fps"]); impact=d["events"]["impact_authored"]-1
    head_axis=int(spec.get("head_axis",0))
    if head_axis not in (0,1,2): raise ValueError("invalid local head axis")
    profiles=spec["profiles"]
    if not profiles or len(profiles)>6: raise ValueError("profile count")
    for p in profiles:
        name=p["name"]; sink=float(p["sink_m"]); angle=float(p["head_deg"])
        down=float(p["compression_s"]); rebound=float(p["rebound_s"])
        delay=float(p["head_delay_s"]); ratio=float(p["rebound_ratio"])
        if not all(math.isfinite(x) for x in (sink,angle,down,rebound,delay,ratio)):
            raise ValueError("nonfinite acting profile")
        if not (0<sink<=.05 and 0<angle<=4 and .08<=down<=.3 and .08<=rebound<=.4 and 0<=delay<=.12 and 0<=ratio<=.5):
            raise ValueError("acting profile out of bounds")
        if down+rebound+delay>(end-2-impact)/fps:
            raise ValueError("acting profile exceeds recovery interval")
        times=(np.arange(end)-impact)/fps
        body=np.array([sink*profile_curve(t,down,rebound,ratio) for t in times])
        tilt=np.array([angle*profile_curve(t-delay,down,rebound,ratio) for t in times])
        body[:impact+1]=0.;tilt[:impact+1]=0.
        body[-2:]=0.;tilt[-2:]=0.
        def edited(uid,prop,axis,curve):
            values=np.array(_dense(tracks[uid][prop],end),dtype=float)
            values[:,axis]+=curve
            return [{"frame":i+1,"value":[round(float(x),7 if prop=="location" else 6) for x in values[i]],"interpolation":"LINEAR"} for i in range(end)]
        raw=dict(tracks)
        raw[root]=dict(tracks[root],location=edited(root,"location",2,body))
        raw[head]=dict(tracks[head],rotation_deg=edited(head,"rotation_deg",head_axis,tilt))
        yield name,raw,{"profile":p,"body_offset_m":body.tolist(),"head_offset_deg":tilt.tolist(),
                        "max_sink_m":float(-body.min()),"max_rebound_m":float(body.max()),
                        "max_head_offset_deg":float(np.max(np.abs(tilt)))}

def compensated(d,nodes,end,base,raw,raw_report):
    # All four feet target their pre-acting trajectory, including swing foot.
    # Root is translated only, so foot world orientation targets are unchanged.
    ik=dict(d["multifoot_ik"])
    ik.update(d.get("dynamic_refinement",{}))
    d["tracks"]=raw
    candidates,diagnostics=propose(nodes,d,end,raw_report,ik,target_reference=base)
    return [(radius,track,max_angle) for strength,radius,track,max_angle in candidates if strength==1. and radius in (0,2)],diagnostics

def deviations(base,report):
    b=base["sole"]["frames"];a=report["sole"]["frames"]
    sup=0.;strike=0.;pre=0.
    for x,y in zip(b,a):
        for n,p in x["support_centers_m"].items():
            sup=max(sup,float(np.linalg.norm(np.asarray(p)-np.asarray(y["support_centers_m"][n]))))
        strike=max(strike,float(np.linalg.norm(np.asarray(x["strike_center_m"])-np.asarray(y["strike_center_m"]))))
    return sup,strike

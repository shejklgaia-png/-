"""Landmark-locked, coherent whole-rig timing experiments for authored clips."""
import math
import numpy as np
from mathutils import Quaternion, Euler

EVENTS=("wait","attack_start","apex","hold_end","impact_authored","attack_end","recovered")
PHASES=("entry","raise","hold","strike","settle","exit")

def landmarks(d,end):
    marks=[int(d["events"][n])-1 for n in EVENTS]
    if marks[0]!=0 or marks[-1]!=end-1 or any(b<=a for a,b in zip(marks,marks[1:])):
        raise ValueError("performance requires ordered explicit phase landmarks")
    return marks

def mapping(marks,shape):
    # t + a*t^3*(1-t)^3*64: endpoint value, first and second
    # derivatives match identity. No change to the hold or loop boundaries.
    result=np.arange(marks[-1]+1,dtype=float)
    for i,(lo,hi) in enumerate(zip(marks,marks[1:])):
        a=float(shape.get(PHASES[i],0.))
        if not math.isfinite(a) or abs(a)>.12: raise ValueError("timing amplitude")
        for f in range(lo,hi+1):
            t=(f-lo)/(hi-lo)
            result[f]=lo+(hi-lo)*(t+a*64*t**3*(1-t)**3)
    for m in marks: result[m]=m
    # Preserve the first/last velocity samples exactly, independently of easing.
    result[:2]=[0.,1.];result[-2:]=[len(result)-2.,len(result)-1.]
    if np.any(np.diff(result)<=0): raise ValueError("nonmonotonic timing map")
    return result

def resample(tracks,clock):
    end=len(clock); out={}
    for uid,channels in tracks.items():
        out[uid]={}
        for prop,keys in channels.items():
            if len(keys)==2 and keys[0]["value"]==keys[-1]["value"]:
                out[uid][prop]=keys;continue
            if len(keys)!=end or any(k["frame"]!=i+1 for i,k in enumerate(keys)):
                raise ValueError("performance requires dense or constant tracks")
            values=np.array([k["value"] for k in keys],dtype=float)
            if not np.isfinite(values).all(): raise ValueError("nonfinite track")
            new=[];prev=None
            for i,t in enumerate(clock):
                lo=int(t);hi=min(end-1,lo+1);u=t-lo
                if prop=="rotation_deg":
                    # Interpolate orientations, not wrapped Euler components.
                    q0=Euler(tuple(np.radians(values[lo])),"XYZ").to_quaternion()
                    q1=Euler(tuple(np.radians(values[hi])),"XYZ").to_quaternion()
                    q=q0.slerp(q1,u).normalized()
                    e=q.to_euler("XYZ",prev) if prev is not None else q.to_euler("XYZ")
                    prev=e.copy();v=np.degrees(tuple(e))
                elif prop=="location": v=(1-u)*values[lo]+u*values[hi]
                else: raise ValueError("unknown timing track property")
                if u==0.:
                    # Exact numeric landmark keys are retained; compatible Euler
                    # branches are already supplied by the original dense track.
                    v=values[lo]
                    if prop=="rotation_deg": prev=Euler(tuple(np.radians(v)),"XYZ")
                new.append({"frame":i+1,"value":[round(float(x),6 if prop=="rotation_deg" else 7) for x in v],"interpolation":"LINEAR"})
            out[uid][prop]=new
    return out

def evaluate(report,marks,fps):
    # Actual strike sole path, not the authored clock curve.
    p=np.array([r["strike_center_m"] for r in report["sole"]["frames"]])
    speed=np.linalg.norm(np.diff(p,axis=0),axis=1)*fps
    if not np.isfinite(speed).all(): raise ValueError("invalid performance path")
    def section(lo,hi): return speed[lo:hi]
    def mean(v): return float(np.mean(v)) if len(v) else 0.
    def ratio(x,y): return x/max(y,.01)
    _,start,apex,hold,impact,finish,_=marks
    raise_v=section(start,apex); strike=section(hold,impact); settle=section(impact,finish)
    third=lambda v:max(1,len(v)//3)
    # Prefer slowing the end of the raise, stronger late descent and a calm
    # recovery tail; all are heuristic readability measures, not physics.
    r=third(raise_v);s=third(strike);q=third(settle)
    metrics={"raise_tail_ratio":ratio(mean(raise_v[-r:]),mean(raise_v[:r])),
             "strike_late_ratio":ratio(mean(strike[-s:]),mean(strike[:s])),
             "settle_tail_ratio":ratio(mean(settle[-q:]),mean(settle[:q])),
             "hold_mean_speed_m_s":mean(section(apex,hold)),
             "impact_pre_speed_m_s":float(speed[impact-1]),
             "impact_post_speed_m_s":float(speed[impact]),
             "phase_mean_speed_m_s":{name:mean(section(lo,hi)) for name,lo,hi in zip(PHASES,marks,marks[1:])}}
    return metrics

def candidates(d,end):
    marks=landmarks(d,end)
    # Positive clock advance slows the second half of a segment; negative
    # advance delays the early part and catches up during its second half.
    for strength in (.025,.05,.10):
        for name,shape in (("raise_settle",{"raise":strength,"settle":strength}),
                           ("strike",{"strike":-strength}),
                           ("combined",{"raise":strength,"strike":-strength,"settle":strength})):
            clock=mapping(marks,shape)
            yield name,strength,clock,resample(d["tracks"],clock)

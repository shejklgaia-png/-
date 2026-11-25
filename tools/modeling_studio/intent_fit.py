"""Opt-in robust dimensional intent fitting: reference images are soft observations.
No claim of automatic aesthetics or semantic inference.
"""
import math

def finite(v):
    x=float(v)
    if not math.isfinite(x):
        raise ValueError("nonfinite intent value")
    return x

def solve_intent(current,low,high,spec):
    intent=finite(spec["target_m"])
    weight=finite(spec.get("intent_weight",2))
    delta=finite(spec.get("tolerance_m",.02))
    reason=spec.get("reason","")
    if not isinstance(reason,str) or not reason.strip() or intent<=0 or weight<=0 or delta<=0:
        raise ValueError("positive intent target/weight/tolerance and reason required")
    if not low<=intent<=high:
        raise ValueError("intent target must respect explicit bounds")
    observations=[]
    for row in spec.get("observations",[]):
        source=row["source"]
        value=finite(row["value_m"])
        confidence=finite(row["weight"])
        tolerance=finite(row.get("tolerance_m",delta))
        if not isinstance(source,str) or not source.strip() or value<=0 or not 0<=confidence<=1 or tolerance<=0:
            raise ValueError("invalid soft reference observation")
        observations.append({"source":source,"value_m":value,"weight":confidence,"tolerance_m":tolerance})
    # Convex scalar Huber objective; explicit design intent remains a quadratic prior.
    def derivative(x):
        return weight*(x-intent)+sum(r["weight"]*max(-r["tolerance_m"],min(r["tolerance_m"],x-r["value_m"])) for r in observations)
    def objective(x):
        cost=.5*weight*(x-intent)**2
        for r in observations:
            e=abs(x-r["value_m"]); d=r["tolerance_m"]
            cost+=r["weight"]*(.5*e*e if e<=d else d*(e-.5*d))
        return cost
    a,b=low,high
    for _ in range(64):
        mid=(a+b)/2
        if derivative(mid)<0:
            a=mid
        else:
            b=mid
    x=(a+b)/2
    return x,{"reason":reason,"intent_target_m":intent,"intent_weight":weight,"bounds_m":[low,high],
        "before_m":current,"after_m":x,"objective_before":objective(current),"objective_after":objective(x),
        "observations":[{**r,"residual_m":x-r["value_m"],"outlier":abs(x-r["value_m"])>r["tolerance_m"]} for r in observations],
        "limits":"Authored intent and calibrated dimension observations only. Soft fit is not visual quality approval; explicit dimensions are hard bounds."}

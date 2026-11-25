"""Conservative repeated-region hypotheses. Image-only; never uses truth to group."""
import math
import numpy as np
import cv2

def proposals(labels,image):
    lab=cv2.cvtColor(image,cv2.COLOR_BGR2LAB)
    ids=np.unique(labels)
    ids=ids[ids>0]
    if len(ids)>256:
        return [],"too_many_regions"
    regions={}
    for rid in ids:
        ys,xs=np.where(labels==rid)
        area=len(xs)
        if area<12:
            continue
        w,h=int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)
        regions[int(rid)]={"center":np.array([xs.mean(),ys.mean()]),"area":area,
            "size":np.array([w,h],dtype=float),"lab":lab[ys,xs].mean(axis=0)}
    def similar(a,b):
        return (.55<=a["area"]/b["area"]<=1/.55
                and np.all(a["size"]/b["size"]>=.55) and np.all(a["size"]/b["size"]<=1/.55)
                and np.linalg.norm(a["lab"]-b["lab"])<=28)
    keys=sorted(regions)
    found={}
    for i,a_id in enumerate(keys):
        a=regions[a_id]
        for b_id in keys[i+1:]:
            b=regions[b_id]
            if not similar(a,b):
                continue
            step=b["center"]-a["center"]
            pitch=float(np.linalg.norm(step))
            if not 4<=pitch<=3*max(a["size"]):
                continue
            unit=step/pitch
            group=[]
            for k in keys:
                r=regions[k]
                if not similar(a,r) or not similar(b,r):
                    continue
                d=r["center"]-a["center"]
                u=float(d@unit/pitch)
                slot=round(u)
                perp=float(np.linalg.norm(d-u*pitch*unit))
                err=abs(u-slot)*pitch+perp
                if abs(u-slot)<=.22 and perp<=max(2.,pitch*.20):
                    group.append((slot,err,k))
            # Best region per slot; require at least three consecutive visible instances.
            slots={}
            for slot,err,k in sorted(group,key=lambda x:(x[1],x[2])):
                slots.setdefault(slot,(err,k))
            run=[]
            def add_run(run):
                if len(run)<3:
                    return
                members=tuple(sorted(slots[s][1] for s in run))
                error=sum(slots[s][0] for s in run)/len(run)/pitch
                row={"members":list(members),"ordered_members":[slots[s][1] for s in run],
                     "pitch_px":pitch,"normalized_spacing_error":error,"status":"candidate",
                     "geometry_approved":False,"reason":"similar size/color and consecutive near-collinear pitch"}
                if members not in found or error<found[members]["normalized_spacing_error"]:
                    found[members]=row
            for slot in sorted(slots):
                if run and slot!=run[-1]+1:
                    add_run(run)
                    run=[]
                run.append(slot)
            add_run(run)
    rows=sorted(found.values(),key=lambda r:(-len(r["members"]),r["normalized_spacing_error"],r["members"]))
    return rows[:256],"ok"

def group_candidate(labels,rows):
    # Separate hypothetical map, no pixels filled or removed; non-overlapping rows only.
    lut=np.arange(int(labels.max())+1,dtype=np.uint16)
    used=set()
    accepted=[]
    for row in rows:
        ids=row["members"]
        if used.intersection(ids):
            continue
        for rid in ids:
            lut[rid]=min(ids)
        used.update(ids)
        accepted.append(row)
    return lut[labels],accepted

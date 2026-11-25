"""Curved near-periodic region sequences, preserving source labels."""
import math
import numpy as np
import cv2

def curved_proposals(labels,image):
    ids=[int(i) for i in np.unique(labels) if i>0]
    if len(ids)>128:
        return [],"too_many_regions"
    lab=cv2.cvtColor(image,cv2.COLOR_BGR2LAB)
    regions={}
    for i in ids:
        y,x=np.where(labels==i)
        if len(x)<12: continue
        regions[i]=(np.array([x.mean(),y.mean()]),len(x),max(x.max()-x.min()+1,y.max()-y.min()+1),lab[y,x].mean(axis=0))
    def similar(i,j):
        a,b=regions[i],regions[j]
        return .45<=a[1]/b[1]<=1/.45 and np.linalg.norm(a[3]-b[3])<=28 and .5<=a[2]/b[2]<=2
    def point(i): return regions[i][0]
    found={}
    for i in regions:
        for j in regions:
            if i>=j or not similar(i,j): continue
            pitch=float(np.linalg.norm(point(j)-point(i)))
            if not 4<=pitch<=3*min(regions[i][2],regions[j][2]): continue
            chain=[i,j]
            for side in (0,1):
                if side: chain.reverse()
                while len(chain)<32:
                    a,b=chain[-2:]
                    v=point(b)-point(a); vn=np.linalg.norm(v)
                    scores=[]
                    for k in regions:
                        if k in chain or not similar(i,k) or not similar(j,k): continue
                        w=point(k)-point(b); d=np.linalg.norm(w)
                        if not .65*pitch<=d<=1.35*pitch: continue
                        cosine=float(np.clip(v@w/(vn*d),-1,1))
                        if cosine<.4: continue
                        scores.append((abs(d/pitch-1)+.35*(1-cosine),k))
                    if not scores: break
                    chain.append(min(scores)[1])
            if len(chain)<4: continue
            pts=np.array([point(k) for k in chain])
            steps=np.diff(pts,axis=0); lengths=np.linalg.norm(steps,axis=1)
            angles=np.array([math.atan2(np.cross(a,b),a@b) for a,b in zip(steps,steps[1:])])
            # Require meaningful, consistent curvature; avoid zigzag chains.
            if abs(angles.sum())<.35 or abs(angles.sum())<.7*np.abs(angles).sum(): continue
            closure=np.linalg.norm(pts[0]-pts[-1])
            closed=bool(.65*pitch<=closure<=1.35*pitch and abs(angles.sum())>math.pi)
            if closed:
                w=pts[0]-pts[-1]
                if min(float(steps[-1]@w/(lengths[-1]*closure)),float(w@steps[0]/(closure*lengths[0])))<.4:
                    closed=False
            key=tuple(sorted(chain))
            err=float(np.mean(abs(lengths/pitch-1)))
            row={"members":list(key),"ordered_members":chain,"pitch_px":pitch,"normalized_spacing_error":err,
                 "closed_candidate":closed,"turn_radians":float(angles.sum()),"status":"candidate",
                 "geometry_approved":False,"reason":"similar regions with near-periodic spacing and consistent curvature"}
            if key not in found or err<found[key]["normalized_spacing_error"]: found[key]=row
    return sorted(found.values(),key=lambda r:(-len(r["members"]),r["normalized_spacing_error"],r["members"]))[:128],"ok"

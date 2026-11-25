"""Review-only region and structure candidates for hard-surface reference images.
Input: one cropped view and independent foreground mask. No 3D geometry is changed.
"""
import argparse
import json
import math
from pathlib import Path
import cv2
import numpy as np

def save(path,image):
    if not cv2.imwrite(str(path),image):
        raise IOError("cannot write "+str(path))

def region_candidates(image,foreground,clusters,min_area):
    # Reduce noise while preserving strong color boundaries; cluster in Lab.
    lab=cv2.cvtColor(cv2.bilateralFilter(image,5,18,4),cv2.COLOR_BGR2LAB)
    values=lab[foreground].astype(np.float32)
    if len(values)<clusters:
        raise ValueError("foreground too small for requested clusters")
    sample=values[::max(1,math.ceil(len(values)/60000))]
    cv2.setRNGSeed(42)
    _,_,centers=cv2.kmeans(sample,clusters,None,
        (cv2.TERM_CRITERIA_EPS+cv2.TERM_CRITERIA_MAX_ITER,40,.15),1,cv2.KMEANS_PP_CENTERS)
    # Assign in chunks to bound memory.
    assignments=np.empty(len(values),np.uint8)
    for i in range(0,len(values),32768):
        chunk=values[i:i+32768]
        assignments[i:i+len(chunk)]=np.argmin(((chunk[:,None,:]-centers[None,:,:])**2).sum(axis=2),axis=1)
    classes=np.full(foreground.shape,255,np.uint8)
    classes[foreground]=assignments
    labels=np.zeros(foreground.shape,np.int32)
    regions=[]
    for k in range(clusters):
        count,cc,stats,centroids=cv2.connectedComponentsWithStats((classes==k).astype(np.uint8),8)
        for j in range(1,count):
            x,y,w,h,area=map(int,stats[j])
            if area<min_area:
                continue
            if len(regions)>=4096:
                raise ValueError("too many regions; increase min_area")
            roi=cc[y:y+h,x:x+w]==j
            rid=len(regions)+1
            labels[y:y+h,x:x+w][roi]=rid
            contours,_=cv2.findContours(roi.astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
            contour=max(contours,key=cv2.contourArea)
            perimeter=cv2.arcLength(contour,True)
            circularity=min(1.,4*math.pi*cv2.contourArea(contour)/max(perimeter**2,1.))
            aspect=min(w,h)/max(w,h)
            outline=cv2.approxPolyDP(contour,1.5,True).reshape(-1,2)+[x,y]
            color=lab[y:y+h,x:x+w][roi].mean(axis=0).tolist()
            circular=circularity>=.72 and aspect>=.75 and len(outline)>=6
            regions.append({"id":rid,"bounds_px":[x,y,x+w,y+h],"area_px":area,
                "centroid_px":centroids[j].tolist(),"mean_lab":color,"outline_px":outline.tolist(),
                "circularity":circularity,"aspect":aspect,"shape_hint":"circular_region" if circular else "unknown",
                "status":"candidate","role":"unknown"})
    return labels,regions

def adjacency(labels,lab):
    # Four-neighbour contact counts and mean Lab color discontinuity.
    result={}
    for a,b,c,d in ((labels[:,:-1],labels[:,1:],lab[:,:-1],lab[:,1:]),
                     (labels[:-1,:],labels[1:,:],lab[:-1,:],lab[1:,:])):
        valid=(a>0)&(b>0)&(a!=b)
        lo=np.minimum(a[valid],b[valid]); hi=np.maximum(a[valid],b[valid])
        delta=np.linalg.norm(c[valid].astype(np.float32)-d[valid].astype(np.float32),axis=1)
        keys=lo.astype(np.int64)*8192+hi
        unique,inv=np.unique(keys,return_inverse=True)
        counts=np.bincount(inv); sums=np.bincount(inv,weights=delta)
        for k,n,s in zip(unique,counts,sums):
            key=(int(k//8192),int(k%8192))
            old=result.get(key,(0,0.))
            result[key]=(old[0]+int(n),old[1]+float(s))
    return [{"regions":list(k),"contact_px":n,"mean_lab_jump":s/n} for k,(n,s) in sorted(result.items())]

def classify_segments(image,foreground,labels,contacts):
    gray=cv2.cvtColor(image,cv2.COLOR_BGR2GRAY)
    edge=cv2.Canny(cv2.GaussianBlur(gray,(3,3),0),45,120)
    inner=cv2.erode(foreground.astype(np.uint8),np.ones((5,5),np.uint8))
    edge[inner==0]=0
    detected=cv2.HoughLinesP(edge,1,np.pi/180,threshold=18,minLineLength=10,maxLineGap=3)
    lookup={tuple(x["regions"]):x for x in contacts}
    lines=[]
    if detected is None:
        return lines,edge
    h,w=labels.shape
    for i,(x1,y1,x2,y2) in enumerate(detected.reshape(-1,4)[:4096]):
        dx=float(x2-x1); dy=float(y2-y1); length=math.hypot(dx,dy)
        if length<1:
            continue
        nx,ny=-dy/length,dx/length
        votes={}; valid=0
        for t in np.linspace(.1,.9,max(5,min(64,int(length/3)))):
            x=x1+t*dx;y=y1+t*dy
            a=(round(x+3*nx),round(y+3*ny)); b=(round(x-3*nx),round(y-3*ny))
            if not all(0<=p[0]<w and 0<=p[1]<h for p in (a,b)):
                continue
            ra,rb=int(labels[a[1],a[0]]),int(labels[b[1],b[0]])
            if not ra or not rb:
                continue
            valid+=1
            if ra!=rb:
                key=tuple(sorted((ra,rb)));votes[key]=votes.get(key,0)+1
        pair=max(votes,key=votes.get) if votes else None
        support=votes[pair]/valid if pair and valid else 0.
        contact=lookup.get(pair,{})
        strong=support>=.6 and contact.get("mean_lab_jump",0)>=12 and contact.get("contact_px",0)>=8
        lines.append({"id":"segment_"+str(i),"kind":"panel_boundary_candidate" if strong else "unknown",
            "pixels":[[int(x1),int(y1)],[int(x2),int(y2)]],"region_pair":list(pair) if pair else [],
            "boundary_support":support,"valid_samples":valid,"mean_lab_jump":contact.get("mean_lab_jump"),
            "status":"candidate","geometry_approved":False})
    return lines,edge

def analyze(image_path,mask_path,out,clusters=8,min_area=40):
    image=cv2.imread(str(image_path),cv2.IMREAD_COLOR)
    mask=cv2.imread(str(mask_path),cv2.IMREAD_GRAYSCALE)
    if image is None or mask is None or image.shape[:2]!=mask.shape:
        raise ValueError("image and mask dimensions must match")
    h,w=mask.shape
    if max(h,w)>2048 or min(h,w)<8 or not 2<=clusters<=16 or not 8<=min_area<=100000:
        raise ValueError("invalid analysis dimensions or parameters")
    foreground=mask>=128
    if not foreground.any() or foreground.all():
        raise ValueError("mask must include foreground and background")
    labels,regions=region_candidates(image,foreground,clusters,min_area)
    contacts=adjacency(labels,cv2.cvtColor(image,cv2.COLOR_BGR2LAB))
    segments,edge=classify_segments(image,foreground,labels,contacts)
    contours,hierarchy=cv2.findContours(foreground.astype(np.uint8),cv2.RETR_CCOMP,cv2.CHAIN_APPROX_SIMPLE)
    lines=[]
    for i,c in enumerate(contours):
        p=cv2.approxPolyDP(c,1.5,True).reshape(-1,2).tolist()
        if len(p)>=3 and cv2.contourArea(c)>=8:
            lines.append({"id":"mask_"+str(i),"kind":"silhouette_candidate" if hierarchy[0,i,3]<0 else "hole_candidate",
                          "pixels":p+[p[0]],"status":"candidate","geometry_approved":False})
    for r in regions:
        if r["shape_hint"]=="circular_region":
            p=r["outline_px"]
            lines.append({"id":"circle_region_"+str(r["id"]),"kind":"circular_candidate","pixels":p+[p[0]],
                          "region_id":r["id"],"circularity":r["circularity"],"status":"candidate","geometry_approved":False})
    lines+=segments
    out.mkdir(parents=True,exist_ok=False)
    save(out/"labels.png",labels.astype(np.uint16))
    rng=np.random.default_rng(42)
    palette=np.vstack((np.zeros((1,3),np.uint8),rng.integers(55,255,(len(regions),3),dtype=np.uint8)))
    overlay=image.copy()
    assigned=labels>0
    overlay[assigned]=(.45*image[assigned]+.55*palette[labels[assigned]]).astype(np.uint8)
    save(out/"regions.png",overlay)
    overlay=image.copy()
    colors={"silhouette_candidate":(255,220,50),"hole_candidate":(255,130,80),
            "circular_candidate":(100,230,70),"panel_boundary_candidate":(20,180,255),"unknown":(130,130,130)}
    for line in lines:
        cv2.polylines(overlay,[np.array(line["pixels"],np.int32)],False,colors[line["kind"]],1,cv2.LINE_AA)
    save(out/"structures.png",overlay)
    save(out/"internal_edges.png",edge)
    report={"format":"SERA_STRUCTURE_ANALYSIS_V1","size":[w,h],"parameters":{"clusters":clusters,"min_area":min_area},
            "regions":regions,"adjacency":contacts,"lines":lines,"foreground_px":int(foreground.sum()),
            "assigned_px":int(assigned.sum()),"unassigned_px":int((foreground&~assigned).sum()),
            "limits":"Color-connected region proposals, not actual mechanical parts. Boundary support is evidence, not calibrated confidence. Shading and markings may be classified as candidates. No line or region is approved for 3D."}
    (out/"structure.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("image",type=Path);p.add_argument("mask",type=Path);p.add_argument("out",type=Path)
    p.add_argument("--clusters",type=int,default=8);p.add_argument("--min-area",type=int,default=40)
    a=p.parse_args()
    analyze(a.image,a.mask,a.out,a.clusters,a.min_area)
if __name__=="__main__":
    main()

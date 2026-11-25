"""Conservative region merging and ellipse/arc proposals from V1 outputs."""
import argparse
import json
import math
from pathlib import Path
import cv2
import numpy as np
from structure_analysis import adjacency, classify_segments, save

def merge_regions(labels,regions,contacts,max_jump=9.,max_chroma=12.,max_light=48.):
    by_id={r["id"]:r for r in regions}
    parent={k:k for k in by_id}
    members={k:[k] for k in by_id}
    def root(k):
        while parent[k]!=k:
            parent[k]=parent[parent[k]]
            k=parent[k]
        return k
    decisions=[]
    for edge in sorted(contacts,key=lambda e:(e["mean_lab_jump"],-e["contact_px"],e["regions"])):
        a,b=map(root,edge["regions"])
        if a==b or edge["contact_px"]<6 or edge["mean_lab_jump"]>max_jump:
            continue
        group=members[a]+members[b]
        colors=np.array([by_id[k]["mean_lab"] for k in group])
        span=np.ptp(colors,axis=0)
        if np.linalg.norm(span[1:])>max_chroma or span[0]>max_light:
            continue
        # Complete-group color range prevents unbounded chaining.
        if any(by_id[k]["shape_hint"]=="circular_region" for k in group):
            continue
        keep,drop=min(a,b),max(a,b)
        parent[drop]=keep
        members[keep]=group
        del members[drop]
        decisions.append({"source_ids":edge["regions"],"boundary_jump":edge["mean_lab_jump"],
                          "contact_px":edge["contact_px"],"group_color_span":span.tolist()})
    lut=np.zeros(int(labels.max())+1,np.uint16)
    groups=[]
    for i,(r,ids) in enumerate(sorted(members.items()),1):
        for k in ids:
            lut[k]=i
        groups.append({"id":i,"source_ids":sorted(ids),"role":"unknown","status":"candidate"})
    return lut[labels],groups,decisions

def ellipse_candidates(edge,foreground):
    contours,_=cv2.findContours(edge,cv2.RETR_LIST,cv2.CHAIN_APPROX_NONE)
    distance=cv2.distanceTransform((edge==0).astype(np.uint8),cv2.DIST_L2,3)
    h,w=edge.shape
    candidates=[]
    for contour in sorted(contours,key=len,reverse=True)[:512]:
        if len(contour)<15:
            continue
        try:
            (cx,cy),(d1,d2),angle=cv2.fitEllipse(contour)
        except cv2.error:
            continue
        if not all(math.isfinite(v) for v in (cx,cy,d1,d2,angle)):
            continue
        if min(d1,d2)<8 or max(d1,d2)>min(h,w)*.85 or min(d1,d2)/max(d1,d2)<.24:
            continue
        a,b=d1/2,d2/2
        theta=math.radians(angle)
        c,s=math.cos(theta),math.sin(theta)
        p=contour.reshape(-1,2).astype(float)-[cx,cy]
        xx=(p[:,0]*c+p[:,1]*s)/a
        yy=(-p[:,0]*s+p[:,1]*c)/b
        error=float(np.median(abs(np.hypot(xx,yy)-1)))
        if error>.10:
            continue
        t=np.linspace(0,2*math.pi,96,endpoint=False)
        x=cx+a*np.cos(t)*c-b*np.sin(t)*s
        y=cy+a*np.cos(t)*s+b*np.sin(t)*c
        q=np.rint(np.column_stack((x,y))).astype(int)
        inside=(q[:,0]>=0)&(q[:,0]<w)&(q[:,1]>=0)&(q[:,1]<h)
        supported=np.zeros(len(q),bool)
        u=q[inside]
        supported[inside]=(distance[u[:,1],u[:,0]]<=2.0)&foreground[u[:,1],u[:,0]]
        support=float(supported.mean())
        if support<.48:
            continue
        # Keep only supported runs. An ellipse fit to a partial arc is not a complete contour.
        kind="circular_candidate" if support>=.85 and min(d1,d2)/max(d1,d2)>=.85 else ("ellipse_candidate" if support>=.85 else "arc_candidate")
        if any(math.hypot(cx-r["center_px"][0],cy-r["center_px"][1])<3 and
               abs(max(d1,d2)-max(r["diameters_px"]))<5 and
               abs(min(d1,d2)-min(r["diameters_px"]))<5 for r in candidates):
            continue
        if supported.all():
            runs=[q.tolist()+[q[0].tolist()]]
        else:
            start=int(np.flatnonzero(~supported)[0])
            runs=[]; run=[]
            for j in range(1,len(q)+1):
                i=(start+j)%len(q)
                if supported[i]:
                    run.append(q[i].tolist())
                elif run:
                    if len(run)>=3:
                        runs.append(run)
                    run=[]
        if not runs:
            continue
        candidates.append({"id":"ellipse_"+str(len(candidates)),"kind":kind,
            "center_px":[cx,cy],"diameters_px":[d1,d2],"angle_deg":angle,
            "median_normalized_radial_error":error,"edge_support":support,
            "supported_polylines":runs,"status":"candidate","geometry_approved":False})
    return candidates

def analyze_v2(image_path,mask_path,v1_dir,out):
    image=cv2.imread(str(image_path),cv2.IMREAD_COLOR)
    mask=cv2.imread(str(mask_path),cv2.IMREAD_GRAYSCALE)
    labels=cv2.imread(str(v1_dir/"labels.png"),cv2.IMREAD_UNCHANGED)
    v1=json.loads((v1_dir/"structure.json").read_text())
    if image is None or mask is None or labels is None or image.shape[:2]!=mask.shape or labels.shape!=mask.shape:
        raise ValueError("image/mask/labels mismatch")
    foreground=mask>=128
    if np.any((labels>0)&~foreground):
        raise ValueError("labels outside foreground")
    merged,groups,decisions=merge_regions(labels,v1["regions"],v1["adjacency"])
    contacts=adjacency(merged,cv2.cvtColor(image,cv2.COLOR_BGR2LAB))
    segments,edge=classify_segments(image,foreground,merged,contacts)
    curves=ellipse_candidates(edge,foreground)
    # V1 silhouette/hole proposals remain; panel lines are recomputed on merged IDs.
    lines=[r for r in v1["lines"] if r["kind"] in ("silhouette_candidate","hole_candidate")]+segments
    for curve in curves:
        for j,run in enumerate(curve["supported_polylines"]):
            lines.append({"id":curve["id"]+"_"+str(j),"kind":curve["kind"],"pixels":run,
                          "edge_support":curve["edge_support"],"status":"candidate","geometry_approved":False})
    out.mkdir(parents=True,exist_ok=False)
    save(out/"labels.png",merged)
    rng=np.random.default_rng(42)
    palette=np.vstack((np.zeros((1,3),np.uint8),rng.integers(55,255,(len(groups),3),dtype=np.uint8)))
    overlay=image.copy()
    assigned=merged>0
    overlay[assigned]=(.45*image[assigned]+.55*palette[merged[assigned]]).astype(np.uint8)
    save(out/"regions.png",overlay)
    overlay=image.copy()
    colors={"silhouette_candidate":(255,220,50),"hole_candidate":(255,130,80),
            "circular_candidate":(100,230,70),"ellipse_candidate":(100,230,70),
            "arc_candidate":(190,220,50),"panel_boundary_candidate":(20,180,255),"unknown":(130,130,130)}
    for line in lines:
        cv2.polylines(overlay,[np.array(line["pixels"],np.int32)],False,colors[line["kind"]],1,cv2.LINE_AA)
    save(out/"structures.png",overlay)
    report={"format":"SERA_STRUCTURE_ANALYSIS_V2","size":v1["size"],"groups":groups,"adjacency":contacts,
        "merge_decisions":decisions,"lines":lines,"curves":curves,"before_regions":len(v1["regions"]),
        "after_regions":len(groups),"foreground_px":int(foreground.sum()),"assigned_px":int(assigned.sum()),
        "unassigned_px":int((foreground&~assigned).sum()),
        "limits":"Candidate groups only; merge thresholds are heuristic. Ellipses/arcs use edge evidence, not true mechanical semantics. Unassigned pixels are preserved. No geometry approval."}
    (out/"structure.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    return report

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("image","mask","v1_dir","out"):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    analyze_v2(a.image,a.mask,a.v1_dir,a.out)

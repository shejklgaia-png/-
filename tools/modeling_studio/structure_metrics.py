"""Independent label-map evaluation for region proposals, plus a deterministic test fixture."""
import argparse
import json
from pathlib import Path
import cv2
import numpy as np
from structure_analysis import analyze, save
from structure_analysis_v2 import analyze_v2

def pairs(counts):
    counts=np.asarray(counts,dtype=np.int64)
    return int(np.sum(counts*(counts-1)//2))

def evaluate(truth,prediction):
    if truth.shape!=prediction.shape or truth.ndim!=2:
        raise ValueError("label map shapes must match")
    foreground=truth>0
    if not foreground.any():
        raise ValueError("empty truth")
    # Unassigned predicted pixels are treated as singleton labels for pair recall.
    # Predicted labels outside truth are counted separately and included in IoU.
    t=truth[foreground].astype(np.int64)
    p=prediction[foreground].astype(np.int64)
    truth_ids,truth_counts=np.unique(t,return_counts=True)
    pos=p>0
    pred_ids,pred_counts=np.unique(p[pos],return_counts=True)
    both=np.column_stack((t[pos],p[pos]))
    combinations,counts=np.unique(both,axis=0,return_counts=True)
    correct_pairs=pairs(counts)
    predicted_pairs=pairs(pred_counts)
    true_pairs=pairs(truth_counts)
    precision=correct_pairs/predicted_pairs if predicted_pairs else None
    recall=correct_pairs/true_pairs if true_pairs else None
    f1=2*precision*recall/(precision+recall) if precision is not None and recall is not None and precision+recall else (0. if precision is not None and recall is not None else None)
    total_ids,total_counts=np.unique(prediction[prediction>0],return_counts=True)
    total=dict(zip(map(int,total_ids),map(int,total_counts)))
    overlaps={int(k):[] for k in truth_ids}
    for (a,b),n in zip(combinations,counts):
        overlaps[int(a)].append((int(b),int(n)))
    parts=[]
    for a,n in zip(truth_ids,truth_counts):
        scores=[(b,k/(int(n)+total[b]-k)) for b,k in overlaps[int(a)]]
        best=max(scores,key=lambda q:q[1]) if scores else (None,0.)
        parts.append({"truth_id":int(a),"best_predicted_id":best[0],"best_iou":best[1],
                      "overlapping_regions":len(scores)})
    return {"truth_parts":len(truth_ids),"predicted_regions":len(total_ids),
            "foreground_coverage":float(pos.mean()),"false_foreground_px":int(np.sum((prediction>0)&~foreground)),
            "pair_precision":precision,"pair_recall":recall,"pair_f1":f1,
            "mean_best_part_iou":sum(x["best_iou"] for x in parts)/len(parts),"parts":parts,
            "limits":"Pair precision penalizes merges, recall penalizes splits and unassigned pixels. Best IoU is not one-to-one matching; independent truth required."}

def fixture(out):
    out.mkdir(parents=True,exist_ok=False)
    # Authored pixel labels, independent of the clustering implementation.
    truth=np.zeros((256,320),np.uint16)
    cv2.rectangle(truth,(24,44),(177,184),1,-1)
    cv2.rectangle(truth,(178,44),(258,184),2,-1)
    cv2.ellipse(truth,(103,112),(32,25),-20,0,360,3,-1)
    image=np.full((256,320,3),235,np.uint8)
    xx=np.indices(truth.shape)[1]
    colors={1:(132,145,154),2:(74,78,88),3:(36,119,202)}
    for label,color in colors.items():
        region=truth==label
        # Smooth lighting gradient, not separate labeled parts.
        gradient=((xx-140)*.26)[region,None]
        image[region]=np.clip(np.asarray(color)[None,:]+gradient,0,255).astype(np.uint8)
    mask=(truth>0).astype(np.uint8)*255
    save(out/"image.png",image);save(out/"mask.png",mask);save(out/"truth.png",truth)
    analyze(out/"image.png",out/"mask.png",out/"v1")
    analyze_v2(out/"image.png",out/"mask.png",out/"v1",out/"v2")
    results={}
    for version in ("v1","v2"):
        pred=cv2.imread(str(out/version/"labels.png"),cv2.IMREAD_UNCHANGED)
        results[version]=evaluate(truth,pred)
    (out/"evaluation.json").write_text(json.dumps({"fixture":"authored 3-part flat shapes with smooth shading; not concept art","results":results},indent=2))

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("out",type=Path)
    p.add_argument("--truth",type=Path)
    p.add_argument("--prediction",type=Path)
    a=p.parse_args()
    if a.truth is None and a.prediction is None:
        fixture(a.out)
    elif a.truth is not None and a.prediction is not None:
        truth=cv2.imread(str(a.truth),cv2.IMREAD_UNCHANGED)
        prediction=cv2.imread(str(a.prediction),cv2.IMREAD_UNCHANGED)
        if truth is None or prediction is None:
            raise ValueError("cannot read label maps")
        with a.out.open("x",encoding="utf-8") as f:
            json.dump(evaluate(truth,prediction),f,indent=2)
    else:
        p.error("provide both truth and prediction")

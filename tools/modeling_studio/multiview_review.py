"""Dedicated production review of V5 proposals; model IDs are scoring-only."""
import json
import sys
from pathlib import Path
import cv2
import numpy as np
from curved_repeats import curved_proposals
from repeat_recognition import group_candidate
from repeat_review import guard
from structure_calibration import colorize
from structure_analysis import save
from structure_metrics import evaluate
from multiview_parts import camera, regions, associate

VIEWS=("front","right","back","front_3q")

def dominant(label_map,truth,rid):
    vals,counts=np.unique(truth[label_map==rid],return_counts=True)
    if not len(vals): return None
    k=int(np.argmax(counts))
    if vals[k]==0 or counts[k]/counts.sum()<.7: return None
    return int(vals[k])

def fixture():
    labels=np.zeros((180,180),np.uint16)
    image=np.full((180,180,3),230,np.uint8)
    for i in range(12):
        t=i*2*np.pi/12
        p=(round(90+48*np.cos(t)),round(90+48*np.sin(t)))
        cv2.circle(labels,p,5,i+1,-1)
        cv2.circle(image,p,5,(55,61,65),-1)
    rows,status=curved_proposals(labels,image)
    return {"status":status,"proposals":rows,"complete_ring_found":any(r["closed_candidate"] and len(r["members"])==12 for r in rows)}

def main(root):
    base=root/"structure_analysis"
    out=base/"multiview"
    out.mkdir(exist_ok=False)
    projections=json.loads((root/"projections.json").read_text())
    v4=json.loads((base/"repetition"/"evaluation.json").read_text())
    input_name="repetition" if v4["recommendation"]=="candidate_for_review" else "calibration"
    maps={};images={};views={};curve_results={}
    for name in VIEWS:
        labels=cv2.imread(str(base/input_name/name/"labels.png"),cv2.IMREAD_UNCHANGED)
        image=cv2.imread(str(root/(name+".png")),cv2.IMREAD_COLOR)
        if labels is None or image is None or labels.shape!=image.shape[:2]:
            raise ValueError("invalid input: "+name)
        rows,status=curved_proposals(labels,image)
        grouped,used=group_candidate(labels,rows)
        truth=np.load(base/"truth"/(name+".npy"),allow_pickle=False)
        before=evaluate(truth,labels); after=evaluate(truth,grouped)
        ok,regressions=guard(before,after)
        dest=out/name;dest.mkdir()
        save(dest/"curved_labels.png",grouped)
        save(dest/"curved_regions.png",colorize(grouped,image))
        (dest/"curved_proposals.json").write_text(json.dumps({"status":status,"proposals":rows,"evaluated_groups":used},indent=2))
        curve_results[name]={"before":before,"after":after,"guard_pass":ok,"part_regressions":regressions,"proposals":len(rows),"evaluated_groups":len(used)}
        # Use the frozen input for association; do not select region maps by truth per view.
        maps[name]=labels;images[name]=image
        cam=camera(projections[name]);views[name]=(cam,regions(labels,image,cam))
    association=associate(views)
    # Evaluate only after all hypotheses have been generated.
    truth={n:np.load(base/"truth"/(n+".npy"),allow_pickle=False) for n in VIEWS}
    correct=wrong=uncertain=0
    for g in association["groups"]:
        if len(g["members"])<2: continue
        d=[dominant(maps[n],truth[n],i) for n,i in g["members"]]
        g["evaluation_dominant_ids"]=d
        if None in d: uncertain+=1
        elif len(set(d))==1: correct+=1
        else: wrong+=1
    (out/"association.json").write_text(json.dumps(association,indent=2))
    for name in VIEWS:
        display=images[name].copy()
        for i,g in enumerate(association["groups"],1):
            if len(g["members"])<2: continue
            for n,rid in g["members"]:
                if n!=name: continue
                y,x=np.where(maps[n]==rid)
                color=(int((i*83)%200+55),int((i*131)%200+55),int((i*47)%200+55))
                display[y,x]=(.4*display[y,x]+.6*np.array(color)).astype(np.uint8)
                cv2.putText(display,str(i),(int(x.mean()),int(y.mean())),cv2.FONT_HERSHEY_SIMPLEX,.35,(255,255,255),1,cv2.LINE_AA)
        save(out/name/"association.png",display)
    improved=any(v["after"]["mean_best_part_iou"]>v["before"]["mean_best_part_iou"]+1e-6 for v in curve_results.values())
    result={"format":"SERA_MULTIVIEW_REVIEW_V1","input_map":input_name,"curved":curve_results,
            "curve_recommendation":"candidate_for_review" if improved and all(v["guard_pass"] for v in curve_results.values()) else "retain_input",
            "fixture":fixture(),"association":{"correct_groups":correct,"incorrect_groups":wrong,"uncertain_groups":uncertain,
             "unmatched_regions":sum(len(g["members"])==1 for g in association["groups"]),"groups_total":len(association["groups"])},
            "limits":"Same synthetic assembly, visible mesh ID purity threshold 70%; group correctness does not measure recall. No semantic identification or hidden geometry approval."}
    (out/"evaluation.json").write_text(json.dumps(result,indent=2))

if __name__=="__main__":
    main(Path(sys.argv[1]).resolve())

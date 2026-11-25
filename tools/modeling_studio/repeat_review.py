"""Evaluate repetition proposals against actual model IDs without using IDs to generate proposals."""
import json
import sys
from pathlib import Path
import cv2
import numpy as np
from repeat_recognition import proposals, group_candidate
from structure_calibration import colorize
from structure_analysis import save
from structure_metrics import evaluate

VIEWS=("front","right","back","front_3q")

def guard(before,after):
    old={p["truth_id"]:p["best_iou"] for p in before["parts"]}
    new={p["truth_id"]:p["best_iou"] for p in after["parts"]}
    regressions=[{"truth_id":k,"before":v,"after":new[k]} for k,v in old.items() if new[k]<v-.01]
    ok=(not regressions and (after["pair_precision"] or 0)>=(before["pair_precision"] or 0)-.01
        and (after["pair_f1"] or 0)>=(before["pair_f1"] or 0)-.005)
    return ok,regressions

def main(root):
    base=root/"structure_analysis"
    out=base/"repetition"
    out.mkdir(exist_ok=False)
    views={}
    for name in VIEWS:
        labels=cv2.imread(str(base/"calibration"/name/"labels.png"),cv2.IMREAD_UNCHANGED)
        image=cv2.imread(str(root/(name+".png")),cv2.IMREAD_COLOR)
        if labels is None or image is None or labels.shape!=image.shape[:2]:
            raise ValueError("invalid input: "+name)
        rows,status=proposals(labels,image)
        grouped,used=group_candidate(labels,rows)
        truth=np.load(base/"truth"/(name+".npy"),allow_pickle=False)
        before=evaluate(truth,labels)
        after=evaluate(truth,grouped)
        ok,regressions=guard(before,after)
        dest=out/name
        dest.mkdir()
        save(dest/"labels.png",grouped)
        save(dest/"regions.png",colorize(grouped,image))
        (dest/"proposals.json").write_text(json.dumps({"status":status,"proposals":rows,
            "evaluated_groups":used,"geometry_approved":False},indent=2))
        views[name]={"before":before,"after":after,"guard_pass":ok,"part_regressions":regressions,
                     "proposals":len(rows),"evaluated_groups":len(used)}
    improved=any(v["after"]["mean_best_part_iou"]>v["before"]["mean_best_part_iou"]+1e-6 for v in views.values())
    approved=all(v["guard_pass"] for v in views.values()) and improved
    (out/"evaluation.json").write_text(json.dumps({"format":"SERA_REPEAT_REVIEW_V1","views":views,
        "recommendation":"candidate_for_review" if approved else "retain_v3_candidate",
        "limits":"Repeated near-collinear groups only; curved or irregular paths and occluded parts not solved. Model IDs used for evaluation only. Same assembly, no generalization claim. No geometry changes or semantic approval."},indent=2))

if __name__=="__main__":
    main(Path(sys.argv[1]).resolve())

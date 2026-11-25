"""Calibrate region merge candidates on separate views; compare on held-out views.
Truth is used only for scoring and training selection, never for producing a prediction.
"""
import json
import sys
from pathlib import Path
import cv2
import numpy as np
from structure_analysis import save
from structure_analysis_v2 import merge_regions
from structure_metrics import evaluate

TRAIN=("front","right")
HOLDOUT=("back","front_3q")
BASE=(9.,12.,48.)
# Small bounded search including the V2 default. No per-view oracle selection.
GRID=[BASE]+[(j,c,l) for j in (6.,12.,18.,24.) for c in (12.,24.) for l in (48.,80.)]

def rank(m):
    return (m["pair_f1"] or 0.,m["mean_best_part_iou"])

def acceptable(metrics,baseline):
    return all((m["pair_precision"] or 0.) >= (b["pair_precision"] or 0.)-.01
               and m["mean_best_part_iou"]>=b["mean_best_part_iou"]-.01
               and (m["pair_f1"] or 0.) >= (b["pair_f1"] or 0.)-.005
               for m,b in zip(metrics,baseline))

def load_view(root,name):
    base=root/"structure_analysis"
    v1=base/name
    v2=base/(name+"_v2")
    truth=np.load(base/"truth"/(name+".npy"),allow_pickle=False)
    a=cv2.imread(str(v1/"labels.png"),cv2.IMREAD_UNCHANGED)
    b=cv2.imread(str(v2/"labels.png"),cv2.IMREAD_UNCHANGED)
    image=cv2.imread(str(root/(name+".png")),cv2.IMREAD_COLOR)
    alpha=cv2.imread(str(base/(name+"_mask.png")),cv2.IMREAD_GRAYSCALE)
    if any(x is None for x in (a,b,image,alpha)) or a.shape!=truth.shape or b.shape!=truth.shape or alpha.shape!=truth.shape:
        raise ValueError("view shape mismatch")
    fg=alpha>=128
    union=np.count_nonzero(fg|(truth>0))
    iou=np.count_nonzero(fg&(truth>0))/max(1,union)
    if iou<.97:
        raise ValueError("raycast/beauty silhouette alignment below .97: "+name)
    return {"truth":truth,"v1":a,"v2":b,"image":image,"alignment_iou":iou,
            "report":json.loads((v1/"structure.json").read_text()),
            "report_v2":json.loads((v2/"structure.json").read_text())}

def predict(data,params):
    r=data["report"]
    return merge_regions(data["v1"],r["regions"],r["adjacency"],*params)

def colorize(labels,image):
    rng=np.random.default_rng(42)
    palette=np.vstack((np.zeros((1,3),np.uint8),rng.integers(55,255,(int(labels.max()),3),dtype=np.uint8)))
    overlay=image.copy()
    mask=labels>0
    overlay[mask]=(.45*image[mask]+.55*palette[labels[mask]]).astype(np.uint8)
    return overlay

def main(root):
    out=root/"structure_analysis"/"calibration"
    out.mkdir(exist_ok=False)
    # Do not load holdout views until after the global training selection is frozen.
    data={name:load_view(root,name) for name in TRAIN}
    baseline=[evaluate(data[n]["truth"],data[n]["v2"]) for n in TRAIN]
    trials=[]
    for params in GRID:
        scores=[evaluate(data[n]["truth"],predict(data[n],params)[0]) for n in TRAIN]
        row={"parameters":list(params),"training":dict(zip(TRAIN,scores)),
             "eligible":acceptable(scores,baseline),
             "mean_f1":sum(rank(m)[0] for m in scores)/len(scores),
             "mean_best_iou":sum(rank(m)[1] for m in scores)/len(scores)}
        trials.append(row)
    eligible=[t for t in trials if t["eligible"]]
    if not eligible:
        raise ValueError("V2 baseline failed reproducibility gate")
    chosen=max(eligible,key=lambda t:(t["mean_f1"],t["mean_best_iou"]))
    params=tuple(chosen["parameters"])
    data.update({name:load_view(root,name) for name in HOLDOUT})
    views={}
    for name,d in data.items():
        pred,groups,decisions=predict(d,params)
        truth=d["truth"]
        dest=out/name
        dest.mkdir()
        save(dest/"truth.png",truth)
        save(dest/"truth_overlay.png",colorize(truth,d["image"]))
        save(dest/"labels.png",pred)
        save(dest/"regions.png",colorize(pred,d["image"]))
        # Preserve V1 region-derived circle evidence alongside V2 edge-fit proposals.
        # Do not claim a verified mechanical circle or close an unsupported arc.
        lines=list(d["report_v2"]["lines"])
        ids={x["id"] for x in lines}
        circles=[x for x in d["report"]["lines"] if x["kind"]=="circular_candidate" and x["id"] not in ids]
        lines.extend(circles)
        curves=d["image"].copy()
        for line in lines:
            if line["kind"] in ("circular_candidate","ellipse_candidate","arc_candidate"):
                cv2.polylines(curves,[np.asarray(line["pixels"],np.int32)],False,(90,230,70),1,cv2.LINE_AA)
        save(dest/"curves.png",curves)
        (dest/"candidates.json").write_text(json.dumps({"groups":groups,"merge_decisions":decisions,
            "curve_lines":[l for l in lines if l["kind"] in ("circular_candidate","ellipse_candidate","arc_candidate")],
            "restored_v1_circles":len(circles),"limits":"Unapproved candidates; line region IDs from prior passes are not current group IDs."},indent=2))
        views[name]={"alignment_iou":d["alignment_iou"],"v1":evaluate(truth,d["v1"]),
                     "v2":evaluate(truth,d["v2"]),"candidate":evaluate(truth,pred),
                     "restored_v1_circles":len(circles)}
    hold=[views[n]["candidate"] for n in HOLDOUT]
    base=[views[n]["v2"] for n in HOLDOUT]
    heldout_ok=acceptable(hold,base)
    strict_improvement=sum(rank(m)[0] for m in hold)>sum(rank(m)[0] for m in base)+1e-6
    report={"format":"SERA_STRUCTURE_CALIBRATION_V1","training_views":TRAIN,"held_out_views":HOLDOUT,
            "baseline_parameters":BASE,"selected_parameters":params,"trials":trials,"views":views,
            "heldout_guard_pass":heldout_ok,"heldout_f1_improved":strict_improvement,
            "recommendation":"candidate_for_review" if heldout_ok and strict_improvement else "keep_v2_default",
            "limits":"Same synthetic assembly in all views; no independent object or concept-art validation. Selection uses training views only. Default thresholds not changed; candidate is not semantic approval. No repeated-structure detector yet."}
    (out/"evaluation.json").write_text(json.dumps(report,indent=2))

if __name__=="__main__":
    main(Path(sys.argv[1]).resolve())

"""Measure real post-finish part bounds in the exact render cameras."""
import json
import math

def bounds(p):
    if len(p)!=4 or not all(math.isfinite(float(v)) for v in p):
        raise ValueError("invalid target bounds")
    p=list(map(float,p))
    if p[2]<=p[0] or p[3]<=p[1]:
        raise ValueError("empty target bounds")
    return p

def review(root):
    plan=root/"hard_surface_plan.json"
    if not plan.is_file():
        return []
    cfg=json.loads(plan.read_text())
    projected=json.loads((root/"projections.json").read_text())
    rows={}
    for part,views in cfg["part_targets"].items():
        rows[part]={}
        for view,target in views.items():
            actual=projected[view]
            if int(target["resolution"])!=actual["resolution"]:
                raise ValueError("target resolution mismatch")
            a=bounds(actual["part_bounds_px"][part])
            b=bounds(target["bounds_px"])
            inter=max(0,min(a[2],b[2])-max(a[0],b[0]))*max(0,min(a[3],b[3])-max(a[1],b[1]))
            area=lambda q:(q[2]-q[0])*(q[3]-q[1])
            iou=inter/(area(a)+area(b)-inter)
            residual=[x-y for x,y in zip(a,b)]
            row={"actual_bounds_px":a,"target_bounds_px":b,"bbox_iou":iou,
                 "edge_residual_px":residual,"mean_abs_edge_error_px":sum(map(abs,residual))/4}
            if "min_iou" in target:
                limit=float(target["min_iou"])
                if not math.isfinite(limit) or not 0<=limit<=1:
                    raise ValueError("invalid bbox target")
                row["meets_target"]=iou>=limit
            rows[part][view]=row
    ranking=sorted(({"part":k,"mean_bbox_iou":sum(v["bbox_iou"] for v in d.values())/len(d)} for k,d in rows.items() if d),key=lambda d:d["mean_bbox_iou"])
    report={"format":"SERA_HARD_SURFACE_REVIEW_V1","level":cfg["level"],"parts":rows,
            "priority_lowest_first":ranking,
            "limits":"Full projected vertex bounds of individual finished meshes, including hidden vertices. Not silhouette IoU, visible-only segmentation, line fidelity or material fidelity. Targets must be independently authored for the same camera and pose; no automatic approval."}
    (root/"hard_surface_review.json").write_text(json.dumps(report,indent=2))
    return ["hard_surface_plan.json","compiled_design.json","hard_surface_review.json"]

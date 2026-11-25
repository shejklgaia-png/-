"""Evidence validation without image-processing dependencies."""
import math
import quality_gates as q
ORTHO=("front","right","back","left","top","bottom")
DIRECTIONS={"front":[0,-1,0],"right":[1,0,0],"back":[0,1,0],"left":[-1,0,0],"top":[0,0,1],"bottom":[0,0,-1]}

def finite(x):
    return type(x) in (int,float) and math.isfinite(x)

def vec(x,n):
    return isinstance(x,list) and len(x)==n and all(finite(v) for v in x)

def check_analysis(src,blueprint):
    a=q.load(src/"analysis.json")
    q.need(a.get("format")=="SERA_PF_REFERENCE_ANALYSIS_V3","wrong reference analysis")
    q.need(a["blueprint_review_sha256"]==blueprint["files"]["blueprint_review.json"],"analysis blueprint revision mismatch")
    q.need(type(a["resolution"]) is int and 256<=a["resolution"]<=1024 and finite(a["scale_m"]) and a["scale_m"]>0 and vec(a["target_m"],3),"invalid analysis frame")
    q.need(set(a["views"])==set(q.BLUEPRINT_VIEWS),"missing analysis view")
    # The blueprint record holds all source images, not just the sheet.
    for name,v in a["views"].items():
        q.need(v["source_sha256"] in blueprint["files"].values(),"unbound source image")
        q.need(q.png(q.evidence(src,v["mask"]))==v["mask_sha256"],"reference mask changed")
        q.need(q.sha(q.evidence(src,v["structure"]))==v["structure_sha256"],"structure changed")
    q.need(q.sha(src/"correspondence.json")==a["correspondence_sha256"],"correspondence changed")
    q.need(len(a["landmarks"])>=3,"insufficient landmarks")
    for name,l in a["landmarks"].items():
        q.need(vec(l["world_m"],3) and finite(l["rms_m"]) and l["rms_m"]>=0 and len(set(l["views"]))>=2,"invalid landmark "+name)
    q.need(bool(a["section_envelopes"]),"no shared section envelopes")

def check_plan(src,analysis):
    p=q.load(src/"structure_plan.json");d=q.load(src/"design.json")
    a=q.load(src/"analysis_snapshot.json")
    q.need(q.sha(src/"analysis_snapshot.json")==analysis["files"]["analysis.json"] and p.get("reference_sha256")==analysis["files"]["analysis.json"],"plan reference mismatch")
    q.need(d.get("review_resolution")==a["resolution"],"render resolution must match reference")
    q.need(not set(d.get("camera_fits",{}))&set(ORTHO),"reference cameras must not fit the model")
    for name in ORTHO:
        c=d.get("review_cameras",{}).get(name,{})
        q.need(c.get("target")==a["target_m"] and c.get("ortho_scale")==a["scale_m"] and c.get("direction")==DIRECTIONS[name] and not c.get("roll_degrees") and "quaternion" not in c,"fixed reference camera required: "+name)
    q.need(set(a["landmarks"])<=set(d.get("landmarks",{})),"map all reference landmarks to model nodes")
    for c in p["components"]:
        evidence=c.get("analysis_evidence",[])
        q.need(isinstance(evidence,list) and evidence,"component analysis evidence required")
        for item in evidence:
            view=item["view"]; q.need(view in a["views"],"unknown analysis view")
            q.text(item.get("interpretation"),"interpretation")
            q.need(item.get("kind") in ("region","line","landmark","section","inferred"),"invalid evidence kind")
            q.text(item.get("reference"),"reference ID / section / inference")
    q.text(p.get("ambiguity_resolution"),"ambiguity resolution")
    q.text(p.get("section_strategy"),"section strategy")

def check_comparison(src,analysis,model,review):
    r=q.load(src/"comparison.json")
    q.need(r.get("format")=="SERA_PF_REFERENCE_COMPARISON_V3" and r.get("reference_sha256")==analysis["files"]["analysis.json"] and r.get("model_glb_sha256")==model["files"]["model.glb"],"comparison revision mismatch")
    q.need(set(r["views"])==set(ORTHO),"six measured views required")
    limits=review.get("reference_limits",{})
    q.need(set(limits)==set(ORTHO),"per-view acceptance rationale required")
    for name,row in r["views"].items():
        q.need(row["render_sha256"]==model["files"][name+".png"],"comparison render mismatch")
        q.need(row["overlay_sha256"]==q.png(q.evidence(src,row["overlay"])),"comparison overlay mismatch")
        q.need(review["overlays"][name]==row["overlay"],"review must use measured overlay")
        lim=limits[name]
        q.need(finite(row["iou"]) and 0<=row["iou"]<=1 and finite(lim["min_iou"]) and .5<=lim["min_iou"]<=1 and row["iou"]>=lim["min_iou"],"reference silhouette below threshold: "+name)
        q.text(lim.get("reason"),"threshold rationale")
    q.need(bool(r["landmarks"]),"missing landmark comparison")
    for name,row in r["landmarks"].items():
        q.need(set(row["projection_error_m"])==set(ORTHO) and all(finite(v) and v>=0 for v in row["projection_error_m"].values()),"invalid landmark measurement")
    q.text(review.get("landmark_disposition"),"landmark residual explanation")
    q.text(review.get("correction_priority"),"revision priorities")

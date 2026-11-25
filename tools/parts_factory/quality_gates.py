"""Parts Factory V2 evidence gates. Review judgments remain human/AI-authored."""
import hashlib
import json
import re
from pathlib import Path

HORIZONTAL = ("front","front_right","right","back_right","back","back_left","left","front_left")
BLUEPRINT_VIEWS = HORIZONTAL + ("top","bottom")
RENDER_VIEWS = ("front","front_3q","right","back_3q","back","left","top","bottom")
ART = ("appeal","identity","silhouette","mechanism","cohesion","readability")
GEOMETRY = ("appeal","silhouette","proportions","armor_language","mechanism","rig_clearance","detail_balance")
FINAL = ("appeal","identity","cohesion","silhouette","mechanism","uv_seams","texture","rig","performance")

def need(ok,msg):
    if not ok:
        raise ValueError(msg)

def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):
            h.update(b)
    return h.hexdigest()

def canonical(obj):
    return hashlib.sha256(json.dumps(obj,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode()).hexdigest()

def load(p):
    return json.loads(p.read_text(encoding="utf-8"))

def png(p):
    with p.open("rb") as f:
        b=f.read(24)
    need(b[:8]==b"\x89PNG\r\n\x1a\n" and b[12:16]==b"IHDR" and len(b)==24,"invalid PNG: "+str(p))
    need(all(int.from_bytes(b[i:i+4],"big")>=128 for i in (16,20)),"image too small: "+str(p))
    return sha(p)

def evidence(src, relative):
    need(isinstance(relative,str) and relative and not Path(relative).is_absolute(),"invalid evidence path")
    p=(src/relative).resolve()
    need(p.is_relative_to(src.resolve()) and p.is_file(),"missing evidence: "+relative)
    return p

def text(value,label):
    need(isinstance(value,str) and len(value.strip())>=12,"specific explanation required: "+label)

def rubric(record, keys, label, minimum=4):
    need(isinstance(record,dict),"missing rubric: "+label)
    need(set(record)==set(keys),"rubric criteria mismatch: "+label)
    for k in keys:
        row=record[k]
        need(type(row.get("score")) is int and minimum<=row["score"]<=5,"quality gate not met: "+label+"/"+k)
        text(row.get("reason"),label+"/"+k)

def bound_images(src, mapping, views):
    need(isinstance(mapping,dict) and set(mapping)==set(views),"view coverage incomplete")
    hashes=[]
    for v in views:
        row=mapping[v]
        actual=png(evidence(src,row["file"]))
        need(row.get("sha256")==actual,"view hash mismatch: "+v)
        hashes.append(actual)
        text(row.get("notes"),"view "+v)
    need(len(set(hashes))==len(hashes),"duplicate image bytes across views")

def art(src):
    r=load(src/"art_review.json")
    rows=r.get("candidates",[])
    need(isinstance(rows,list) and len(rows)>=3,"at least three distinct concept images required")
    names=set(); hashes=set(); winner=None
    for row in rows:
        key=row["id"]
        need(key not in names,"duplicate concept ID");names.add(key)
        actual=png(evidence(src,row["file"]))
        need(actual==row.get("sha256") and actual not in hashes,"duplicate or wrong concept image")
        hashes.add(actual)
        rubric(row["rubric"],ART,key,minimum=1)
        text(row.get("design_direction"),key)
        if key==r.get("selected"):
            winner=row
    need(winner is not None,"no selected concept")
    rubric(winner["rubric"],ART,"selected")
    text(r.get("selection_reason"),"selection reason")
    need(bool(r.get("reviewer")) and bool(r.get("image_task_id")),"reviewer and separate image task required")
    need(png(src/"selected.png")==winner["sha256"],"selected image mismatch")
    return winner["sha256"]

def blueprint(src, art_hash):
    r=load(src/"blueprint_review.json")
    need(r.get("selected_art_sha256")==art_hash,"blueprint concept mismatch")
    png(src/"blueprint.png")
    bound_images(src,r.get("views"),BLUEPRINT_VIEWS)
    rubric(r.get("rubric"),("projection_consistency","proportions","palette","mechanism","assembly_interface"),"blueprint")
    text(r.get("scale_and_axes"),"scale and axes")
    text(r.get("resolved_inconsistencies"),"resolved inconsistencies")
    need(bool(r.get("reviewer")) and bool(r.get("image_task_id")),"blueprint provenance required")

def plan(src, blueprint_key):
    p=load(src/"structure_plan.json")
    need(p.get("blueprint_key")==blueprint_key,"plan blueprint revision mismatch")
    d=load(src/"design.json")
    need(d.get("format")=="SERA_MODELING_STUDIO_V1","wrong model format")
    need("parts_factory" not in d,"reserved design field")
    groups=p.get("components",[])
    need(isinstance(groups,list) and len(groups)>=2,"decomposed structure required")
    nodes={x.get("name") for x in d.get("parts",[]) if x.get("shape")!="pivot"}
    need(nodes,"explicit geometry nodes required")
    covered=set(); features=set()
    for c in groups:
        text(c.get("feature"),"feature")
        need(c["feature"] not in features,"duplicate feature");features.add(c["feature"])
        text(c.get("method_reason"),"method choice")
        text(c.get("mechanical_role"),"mechanical role")
        text(c.get("reference_coordinates"),"reference coordinates / landmarks")
        need(set(c.get("views",[]))<=set(BLUEPRINT_VIEWS) and len(set(c.get("views",[])))>=2,"component needs two views")
        n=set(c.get("nodes",[]))
        need(n and n<=nodes and not n&covered,"unknown or duplicate mesh mapping")
        covered|=n
    need(covered==nodes,"unmapped geometry")
    text(p.get("rig_interface"),"rig interface")
    text(p.get("silhouette_targets"),"silhouette targets")
    text(p.get("detail_budget"),"detail budget")
    need(bool(p.get("reviewer")),"plan reviewer required")
    return d

def permit(d,job_id,slot,blueprint_key,plan_key):
    need(re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}",job_id) and slot in ("head","body","arms","legs","weapons"),"invalid identity")
    return dict(d,parts_factory={"format":"SERA_PF_MODEL_PERMIT_V2","id":job_id,"slot":slot,
                "blueprint_key":blueprint_key,"plan_key":plan_key,"design_hash":canonical(d)})

def validate_permit(d, source):
    p=d.get("parts_factory")
    if p is None:
        need(not source.name.lower().startswith("pf_"),"Parts Factory input requires V2 permit")
        return
    need(p.get("format")=="SERA_PF_MODEL_PERMIT_V2","invalid model permit")
    need(re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}",p.get("id","")) and p.get("slot") in ("head","body","arms","legs","weapons"),"invalid permit identity")
    for k in ("blueprint_key","plan_key","design_hash"):
        need(re.fullmatch(r"[0-9a-f]{64}",p.get(k,"")),"missing permit "+k)
    need(canonical({k:v for k,v in d.items() if k!="parts_factory"})==p["design_hash"],"design changed after authorization")
    if source.name.lower().startswith("pf_"):
        need(source.stem=="pf_"+p["id"].lower(),"permit filename mismatch")

def visual_review(src, model_hash, blueprint_key, final=False):
    r=load(src/("review.json" if final else "geometry_review.json"))
    need(r.get("painted_glb_sha256" if final else "model_glb_sha256")==model_hash,"visual review GLB mismatch")
    need(r.get("blueprint_key")==blueprint_key,"visual review blueprint mismatch")
    bound_images(src,r.get("views"),RENDER_VIEWS)
    for v in RENDER_VIEWS:
        need(r["views"][v]["file"]==v+".png","render file must match canonical view")
    rubric(r.get("rubric"),FINAL if final else GEOMETRY,"final" if final else "geometry")
    need(r.get("blocking_issues")==[],"blocking issues not empty")
    text(r.get("comparison_notes"),"blueprint comparison")
    text(r.get("iteration_notes"),"iteration decision")
    need(bool(r.get("reviewer")),"reviewer required")
